function res = resolve(entryPoints, opts)
% RESOLVE - Discover the files and products an entry point depends on.
%
% A thin, project-agnostic wrapper around
% matlab.codetools.requiredFilesAndProducts that splits the required files into
% those inside the project (to be pinned by hash) and those outside it
% (toolboxes, shared libraries). To resolve dependencies fully, the project's
% folders are temporarily added to the MATLAB path (via genpath) for the
% analysis and then restored, mirroring how the project would actually be run.
%
% Syntax:
%  res = mlock.resolve(entryPoints) Resolve the dependencies of
%    ENTRYPOINTS and return them as a struct.
%
%  res = mlock.resolve(entryPoints, Name, Value) Control resolution with
%    name-value options.
%
% Input Arguments:
%  - entryPoints (string) -
%    One or more scripts or functions to analyze. May be char, string, string
%    array or cellstr; paths may be absolute, relative to the current folder,
%    or - when ProjectRoot is given - relative to the project root.
%
%  - Name-Value Arguments -
%    - ProjectRoot (string) -
%      Folder that defines "inside the project". Files under it are returned as
%      project-relative paths; everything else is external. Default: folder of
%      the first entry point.
%    - CleanPath (logical) -
%      Resolve on a factory-default path (MathWorks toolboxes only) plus the
%      project, so unrelated projects on your MATLAB path cannot leak into the
%      result. Default: ``false``. The original path is always restored.
%    - Verbose (logical) -
%      Print a short progress line. Default: ``true``.
%
% Output Arguments:
%  - res (struct) -
%    Resolution result with fields:
%    entryPoints (string) resolved absolute entry-point paths;
%    root (string) absolute project root;
%    files (string) project-relative file paths (posix '/');
%    externalFiles (string) absolute paths outside the project;
%    foreignFiles (string) externals outside matlabroot too (posix) - suspect
%      unbundled deps / path pollution; a warning is also raised for these;
%    products (struct) with fields name, version, product_number, certain.
%
% Usage:
%  Example 1 - Inspect resolved dependencies::
%
%    res = mlock.resolve("main.m");
%    disp(res.files);
%    disp({res.products.name});
%
% See also:
%   mlock.lock, mlock.verify, mlock.check

arguments
    % (1,:) string accepts char, string, string array or cellstr and coerces
    % them all to a string row, so callers need not remember one exact type.
    entryPoints (1,:) string
    % Empty "" is the "not supplied" sentinel; strlength()>0 tests for it below.
    opts.ProjectRoot (1,1) string = ""
    % Resolve against a factory-default path (MathWorks toolboxes only) + the
    % project, so a stray project on the current path cannot leak into the lock.
    opts.CleanPath (1,1) logical = false
    opts.Verbose (1,1) logical = true
end

% Guard: an empty string row (e.g. mlock.resolve(string.empty)) has nothing
% to analyze, so fail loudly rather than returning an empty, misleading result.
if isempty(entryPoints)
    error('mlock:resolve:noEntry', 'At least one entry point is required.');
end

% --- Determine project root (if given) up front, to resolve relative entries ---
% We need the root BEFORE resolving entries, because a relative entry like
% "main.m" may be meant relative to ProjectRoot rather than the current folder.
haveRoot = strlength(opts.ProjectRoot) > 0;
if haveRoot
    % Canonicalize now so every later prefix comparison uses the same form.
    root = mlock.internal.absPath(opts.ProjectRoot);
    if ~isfolder(root)
        error('mlock:resolve:badRoot', 'Project root is not a folder: %s', root);
    end
end

% --- Resolve entry points to absolute, existing files ---
% requiredFilesAndProducts needs real, locatable files; we normalize each entry
% to an absolute path here so the rest of the function deals only with abs paths.
eps = strings(1, numel(entryPoints));
for i = 1:numel(entryPoints)
    ep = entryPoints(i);
    ap = "";
    % Preference 1: if a root is given and the entry is relative, try it there
    % first (the intuitive "paths are relative to my project" behavior).
    if haveRoot && ~isAbsoluteEntry(ep)
        cand = fullfile(char(root), char(ep));
        if isfile(cand)
            ap = mlock.internal.absPath(cand);
        end
    end
    % Preference 2 / fallback: resolve against the current folder (or take the
    % path as-is if it is already absolute). absPath handles both.
    if strlength(ap) == 0
        ap = mlock.internal.absPath(ep);
    end
    % Fail early with the ORIGINAL spelling so the message is recognizable.
    if ~isfile(ap)
        error('mlock:resolve:missingEntry', 'Entry point not found: %s', ep);
    end
    eps(i) = ap;
end

% --- Default root: the common ancestor of ALL entry points ---
% Using only the first entry's folder would leave other entries' dependency
% trees off the path, silently dropping them from the resolution. The common
% ancestor is the smallest folder guaranteed to contain every entry point.
if ~haveRoot
    root = mlock.internal.commonAncestor(eps);
    % Guard: entries placed high in the tree (sibling top-level or project dirs)
    % can share only a drive/filesystem root. genpath'ing that would scan the
    % whole volume and hash toolbox files as project files - refuse and make the
    % caller name the project explicitly.
    if mlock.internal.isFilesystemRoot(root)
        error('mlock:resolve:rootTooShallow', ...
            ['Entry points only share a filesystem root (%s); this would scan an ' ...
             'entire drive. Pass ProjectRoot to name the project folder.'], root);
    end
end

% --- Warn about entries that fall outside an explicitly given root ---
% Only reachable when the caller passed ProjectRoot themselves (the computed
% common ancestor always contains every entry). Such entries get classified as
% "external" below and their sibling project files may not be discovered, so we
% surface it loudly instead of failing silently.
outside = strings(0);
for i = 1:numel(eps)
    % toRel returns "" when eps(i) is not under root -> it is outside.
    if strlength(mlock.internal.toRel(eps(i), root)) == 0
        outside(end+1) = eps(i); %#ok<AGROW>
    end
end
if ~isempty(outside)
    warning('mlock:resolve:entryOutsideRoot', ...
        ['%d entry point(s) lie outside ProjectRoot (%s) and will be treated ' ...
         'as external; their in-project files may be missed:\n  %s'], ...
        numel(outside), root, strjoin(outside, sprintf('\n  ')));
end

if opts.Verbose
    fprintf('mlock: resolving %d entry point(s) under %s ...\n', numel(eps), root);
end

% --- Core dependency analysis (project tree + every entry folder on the path) ---
% requiredFilesAndProducts only follows calls it can resolve, so a function is
% found only if its folder is on the path. We temporarily add the whole project
% tree (genpath) plus each entry's own folder, run the analysis, then restore.
oldPath = path();                                   % snapshot to restore later
% onCleanup restores the path even if the analysis errors out (exception-safe);
% we still clear it explicitly right after the call to restore ASAP on success.
restorePath = onCleanup(@() path(oldPath)); %#ok<NASGU>
if opts.CleanPath
    % Reset to the factory path (MathWorks toolboxes only) so nothing the user
    % has on their path - notably unrelated projects - can be resolved and leak
    % into the lock. IMPORTANT: this removes +mlock from the path too, so no
    % mlock.internal.* call may run until the path is restored below; only core
    % builtins (addpath/genpath/fileparts/requiredFilesAndProducts) run here.
    restoredefaultpath();
end
addpath(genpath(char(root)));                       % all project subfolders
for i = 1:numel(eps)                                % cover entries outside root too
    addpath(fileparts(char(eps(i))));
end
% flist: cellstr of absolute paths of every required user file (incl. entries).
% plist: struct array of required products (Name/Version/ProductNumber/Certain).
[flist, plist] = matlab.codetools.requiredFilesAndProducts(cellstr(eps));
clear restorePath;   % triggers the onCleanup now -> full path restored on success
flist = string(flist(:)');                          % -> string row for slicing

% --- Split required files into internal (project) and external ---
% Files under root are pinned by hash (relative paths); everything else (toolbox
% code, shared libraries) is recorded separately and covered by product versions.
files = strings(0);
external = strings(0);
for i = 1:numel(flist)
    rel = mlock.internal.toRel(flist(i), root);
    if strlength(rel) > 0
        files(end+1) = rel; %#ok<AGROW>          % inside project -> relative path
    else
        external(end+1) = flist(i); %#ok<AGROW>  % outside -> keep absolute for now
    end
end
files = unique(files);          % also sorts -> deterministic ordering
external = unique(external);

% --- Flag "foreign" externals: required files outside BOTH the project and
% matlabroot. Toolbox code lives under matlabroot; anything else almost always
% means an unbundled dependency or a stray project polluting the MATLAB path
% (which would otherwise leak into the lockfile silently). Surface it loudly.
foreign = strings(0);
for i = 1:numel(external)
    if strlength(mlock.internal.toRel(external(i), string(matlabroot))) == 0
        foreign(end+1) = mlock.internal.toPosix(external(i)); %#ok<AGROW>
    end
end
if ~isempty(foreign)
    warning('mlock:resolve:foreignExternals', ...
        ['%d required file(s) resolved outside both the project and matlabroot ' ...
         '- likely an unbundled dependency or a polluted MATLAB path. Bundle ' ...
         'them into the project (or clean your path) and re-lock:\n  %s'], ...
        numel(foreign), strjoin(foreign, sprintf('\n  ')));
end

% --- Normalize product list (sorted by name for stable lockfile diffs) ---
% requiredFilesAndProducts does not guarantee a stable product order; sorting by
% name means re-locking an unchanged project produces an identical list.
[~, order] = sort(lower(string({plist.Name})));
plist = plist(order);
% Re-key to lowercase snake_case field names for a clean, JSON-friendly lock.
products = struct('name', {}, 'version', {}, 'product_number', {}, 'certain', {});
for i = 1:numel(plist)
    products(i).name           = plist(i).Name;
    products(i).version        = plist(i).Version;
    products(i).product_number = plist(i).ProductNumber;
    products(i).certain        = logical(plist(i).Certain);   % force true/false
end

% --- Assemble the result (lock.m consumes exactly these fields) ---
res = struct();
res.entryPoints   = eps;        % absolute entry paths (strings)
res.root          = root;       % absolute project root
res.files         = files;      % project-relative, posix, sorted
res.externalFiles = external;   % absolute out-of-project paths
res.foreignFiles  = foreign;    % externals outside matlabroot (posix); suspect
res.products      = products;   % sorted struct array

if opts.Verbose
    fprintf('mlock: %d project file(s), %d external file(s), %d product(s).\n', ...
        numel(files), numel(external), numel(products));
end
end

% ------------------------------------------------------------------------
function tf = isAbsoluteEntry(p)
% True if P looks absolute. Kept local (and separate from the more general
% internal.absPath) because here we only need a cheap syntactic test to decide
% whether to try resolving relative to ProjectRoot first.
p = char(p);
if ispc
    % Windows absolute forms: drive ("C:\" or "C:/"), UNC ("\\srv"), or "//srv".
    tf = ~isempty(regexp(p, '^([A-Za-z]:[\\/]|\\\\|//)', 'once'));
else
    % POSIX: absolute paths start at the filesystem root.
    tf = startsWith(p, '/');
end
end
