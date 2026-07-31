function lk = lock(entryPoints, opts)
% LOCK - Resolve a project's dependencies into a lockfile.
%
% Discovers dependencies from your code (via
% matlab.codetools.requiredFilesAndProducts), pins each project file by
% SHA-256, records the MATLAB release and product versions, and writes a JSON
% lockfile. This is the MATLAB analogue of ``npm install`` -> package-lock.json,
% ``uv lock`` -> uv.lock, or Cargo -> Cargo.lock: dependencies are discovered,
% not hand-listed, so the lock stays in sync with the project.
%
% Syntax:
%  lk = matlabdeps.lock(entryPoints) Resolve ENTRYPOINTS, write
%    ``<root>/matlabdeps.lock.json``, and return the lock struct.
%
%  lk = matlabdeps.lock(entryPoints, Name, Value) Control resolution and output
%    with name-value options.
%
% Input Arguments:
%  - entryPoints (string) -
%    One or more scripts or functions to analyze. May be char, string, string
%    array or cellstr; paths may be absolute, relative to the current folder,
%    or relative to ProjectRoot.
%
%  - Name-Value Arguments -
%    - ProjectRoot (string) -
%      Folder that defines the project; files under it are pinned by hash, files
%      outside (toolboxes, shared libs) are recorded as external. Default:
%      folder of the first entry point.
%    - Output (string) -
%      Lockfile path to write. Default: ``<ProjectRoot>/matlabdeps.lock.json``.
%    - Extra (string) -
%      Globs relative to ProjectRoot for files code analysis cannot find, such
%      as data or configs, e.g. ``["data/*.xlsx" "config/params.json"]``.
%    - HashExternal (logical) -
%      Also hash out-of-project (toolbox) files. Default: ``false`` (external
%      files are listed by path only).
%    - NormalizeNewlines (logical) -
%      Hash text files with newlines reduced to LF so the lock verifies across
%      Windows/Unix regardless of CRLF/LF. Binary files are always byte-exact.
%      Default: ``true``. The policy is recorded in the lock so verify matches.
%    - Timestamp (logical) -
%      Embed a ``generated`` timestamp. Set ``false`` for byte-reproducible
%      lockfiles (no churn when dependencies are unchanged). Default: ``true``.
%    - Meta (struct) -
%      Free-form metadata embedded under ``"run"``. Default: ``struct()``.
%    - Write (logical) -
%      Write the lockfile. Default: ``true``.
%    - Verbose (logical) -
%      Print progress. Default: ``true``.
%
% Output Arguments:
%  - lk (struct) -
%    The lock contents (fields schema, matlab, entry_points, run, products,
%    files, external_files).
%
% Usage:
%  Example 1 - Lock a single entry point::
%
%    matlabdeps.lock("main.m")
%
%  Example 2 - Multiple entry points, custom root, and pinned data files::
%
%    matlabdeps.lock(["run_all.m" "make_figures.m"], ...
%        ProjectRoot = "C:\proj", ...
%        Extra       = ["data/*.xlsx" "config/params.json"], ...
%        Meta        = struct('seed', 'rng default', 'note', 'baseline'));
%
%  Example 3 - Compute the lock without writing it::
%
%    lk = matlabdeps.lock("main.m", Write=false);
%
% See also:
%   matlabdeps.resolve, matlabdeps.verify, matlabdeps.check

arguments
    entryPoints  (1,:) string
    opts.ProjectRoot      (1,1) string = ""
    opts.Output           (1,1) string = ""
    opts.Extra            (1,:) string = string.empty
    opts.HashExternal     (1,1) logical = false
    opts.NormalizeNewlines (1,1) logical = true
    opts.Timestamp        (1,1) logical = true
    opts.Meta             (1,1) struct  = struct()
    opts.Write            (1,1) logical = true
    opts.Verbose          (1,1) logical = true
end

% Step 1: discover dependencies. resolve() does the code analysis and returns
% project files (relative), external files (absolute), products, and the root.
res  = matlabdeps.resolve(entryPoints, ProjectRoot=opts.ProjectRoot, Verbose=opts.Verbose);
root = res.root;

% --- Collect the project-relative files to pin (resolved + extras) ---
% Code analysis cannot see data/config files referenced only by string (e.g.
% readtable("in.csv")), so Extra globs let the caller pin those explicitly.
relFiles = res.files;
if ~isempty(opts.Extra)
    % expandGlobs errors on a pattern that matches nothing (catches typos);
    % unique() merges + sorts so a file named in both places is pinned once.
    relFiles = unique([relFiles, matlabdeps.internal.expandGlobs(opts.Extra, root)]);
end

% --- Assemble the lock struct (field insertion order == JSON key order) ---
lk = struct();
lk.schema         = 'matlabdeps-lock';   % magic string identifying the format
lk.schema_version = 2;                   % bump on any breaking schema change
% The timestamp is the only non-deterministic field; make it opt-out so callers
% who commit the lock can get byte-identical output when nothing has changed.
if opts.Timestamp
    lk.generated  = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end

% Record the environment the lock was produced in (informational + used by check).
lk.matlab = struct( ...
    'version', version, ...            % full version string, e.g. "24.2.0..."
    'release', version('-release'), ... % e.g. "2024b"
    'arch',    computer('arch'));       % e.g. "win64"

% Hashing policy - recorded so verify re-hashes identically. Without this,
% verify could not know whether the stored hashes were newline-normalized.
lk.hash = struct('algorithm', 'sha256', ...
                 'normalize_newlines', opts.NormalizeNewlines);

% Store entry points posix-style so the lock reads the same on every OS.
lk.entry_points = cellstr(matlabdeps.internal.toPosix(res.entryPoints));

% Preserve any caller metadata verbatim under "run" (seed, mode, note, ...).
lk.run = opts.Meta;

lk.products = res.products;   % already sorted by name in resolve()

% Step 2: hash every pinned project file. hashFiles applies newline
% normalization per-file (text files only) according to the policy above.
lk.files = matlabdeps.internal.hashFiles(relFiles, root, opts.NormalizeNewlines);

% --- External files: ALWAYS an array of objects (consistent schema) ---
% Prior versions emitted a cellstr when not hashing and a struct array when
% hashing; consumers had to branch on type. We always emit objects. Paths under
% matlabroot are rewritten to "$MATLABROOT/..." to stay portable and to avoid
% leaking machine-specific, user-identifying absolute paths into a committed
% lock. External hashes are byte-exact (toolbox files are not ours to normalize).
extSorted = sort(res.externalFiles);
if opts.HashExternal
    % Pre-declare all three fields so every element has the same shape.
    ext = struct('path', {}, 'bytes', {}, 'sha256', {});
else
    ext = struct('path', {});
end
for i = 1:numel(extSorted)
    p = char(extSorted(i));
    ext(i).path = char(matlabdeps.internal.matlabRelative(p));   % portable form
    if opts.HashExternal
        if isfile(p)
            d = dir(p);
            ext(i).bytes  = d.bytes;
            ext(i).sha256 = char(matlabdeps.internal.sha256File(p));
        else
            % Recorded but absent right now: sentinel values, not a hard error.
            ext(i).bytes  = -1;
            ext(i).sha256 = '(missing)';
        end
    end
end
lk.external_files = ext;

% --- Step 3: write (optional; Write=false is "compute and return only") ---
if opts.Write
    outPath = opts.Output;
    if strlength(outPath) == 0
        % Default: drop the lock at the project root next to the code it pins.
        outPath = fullfile(char(root), 'matlabdeps.lock.json');
    end
    matlabdeps.internal.writeJson(lk, outPath);
    if opts.Verbose
        fprintf('matlabdeps: lockfile written to %s\n', outPath);
    end
end
end
