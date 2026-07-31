function [ok, report] = verify(lockPath, opts)
% VERIFY - Check current project files against a lockfile's hashes.
%
% Re-hashes every file recorded in the lock and compares it to the pinned
% SHA-256, reporting files that are OK, CHANGED, or MISSING. Detects drift
% without re-running dependency analysis (like verifying package-lock
% integrity). Returns true only if every pinned file matches.
%
% Syntax:
%  ok = mlock.verify(lockPath) Verify the project against the lockfile at
%    LOCKPATH.
%
%  [ok, report] = mlock.verify(lockPath, Name, Value) Also return a detail
%    struct and control behavior with name-value options.
%
% Input Arguments:
%  - lockPath (string) -
%    Path to the lockfile written by mlock.lock.
%
%  - Name-Value Arguments -
%    - ProjectRoot (string) -
%      Root the lock's relative paths are resolved against. Default: the folder
%      containing the lockfile.
%    - Verbose (logical) -
%      Print a per-file report. Default: ``true``.
%
% Output Arguments:
%  - ok (logical) - True if all pinned files match the lock.
%  - report (struct) -
%    Detail with fields ok, nOk, nChanged, nMissing, changed (paths),
%    missing (paths).
%
% Usage:
%  Example 1 - Gate a run on integrity::
%
%    assert(mlock.verify("mlock.lock.json"), "project has drifted");
%
%  Example 2 - Inspect what changed::
%
%    [ok, report] = mlock.verify("mlock.lock.json");
%    disp(report.changed);
%
% See also:
%   mlock.lock, mlock.check

arguments
    lockPath (1,1) string
    opts.ProjectRoot (1,1) string = ""
    opts.Verbose (1,1) logical = true
end

% Canonicalize the lock path so error messages and the default root are stable.
lockPath = mlock.internal.absPath(lockPath);
if ~isfile(lockPath)
    error('mlock:verify:noLock', 'Lock file not found: %s', lockPath);
end
% jsondecode turns the JSON back into a struct; array-of-objects fields become
% struct arrays (or a single struct for a 1-element array) - see asObjectList.
lk = jsondecode(fileread(lockPath));

% Relative paths in the lock are resolved against this root. By default the lock
% sits at the project root (see lock.m), so the lock's own folder is correct;
% ProjectRoot lets the caller override when the lock has been relocated.
if strlength(opts.ProjectRoot) > 0
    root = mlock.internal.absPath(opts.ProjectRoot);
else
    root = string(fileparts(lockPath));
end

% Re-hash with the SAME newline policy the lock was written under - otherwise a
% normalized lock would mismatch on every text file. Default false keeps
% backward compatibility with older locks that predate the hash policy block.
normalize = false;
if isfield(lk, 'hash') && isfield(lk.hash, 'normalize_newlines')
    normalize = logical(lk.hash.normalize_newlines);
end

% Normalize the (possibly single-struct) files field to a cell list of records.
files = asObjectList(lk.files);

% Tally counters: OK stays silent to keep the report short on large projects;
% CHANGED/MISSING paths are collected for both the printout and the report struct.
nOk = 0; changed = strings(0); missing = strings(0);
if opts.Verbose
    fprintf('\n===== mlock.verify =====\nLock: %s\nRoot: %s\n', lockPath, root);
    fprintf('MATLAB release  locked=%s  current=%s\n', lk.matlab.release, version('-release'));
end

% --- Pass 1: every pinned project file ---
for i = 1:numel(files)
    f = files{i};
    % Rebuild the on-disk path: posix '/' in the lock -> native filesep here.
    abs = fullfile(char(root), char(replace(string(f.path), "/", filesep)));
    if ~isfile(abs)
        missing(end+1) = string(f.path); %#ok<AGROW>
        if opts.Verbose; fprintf('  [MISSING] %s\n', f.path); end
        continue;
    end
    % Normalize newlines only for text files, and only if the lock did so too.
    normThis = normalize && mlock.internal.isTextFile(f.path);
    cur = mlock.internal.sha256File(abs, normThis);
    if strcmp(cur, string(f.sha256))
        nOk = nOk + 1;
    else
        changed(end+1) = string(f.path); %#ok<AGROW>
        if opts.Verbose
            fprintf('  [CHANGED] %s\n    locked  %s\n    current %s\n', f.path, f.sha256, cur);
        end
    end
end

% --- Pass 2: external files that carry a hash (i.e. HashExternal locks) ---
% Path-only external listings have nothing to compare, so they are skipped.
% External hashes are byte-exact (never normalized), matching how lock.m wrote them.
nExt = 0;
if isfield(lk, 'external_files')
    ext = asObjectList(lk.external_files);
    for i = 1:numel(ext)
        e = ext{i};
        if ~isstruct(e) || ~isfield(e, 'sha256')
            continue;   % path-only listing, nothing to verify
        end
        nExt = nExt + 1;
        % "$MATLABROOT/..." -> absolute path on THIS machine's MATLAB install.
        abs = mlock.internal.expandMatlabRoot(e.path);
        if ~isfile(abs)
            % Prefix keeps external entries distinguishable in the report lists.
            missing(end+1) = "[external] " + string(e.path); %#ok<AGROW>
            if opts.Verbose; fprintf('  [MISSING] (external) %s\n', e.path); end
            continue;
        end
        cur = mlock.internal.sha256File(abs);
        if strcmp(cur, string(e.sha256))
            nOk = nOk + 1;
        else
            changed(end+1) = "[external] " + string(e.path); %#ok<AGROW>
            if opts.Verbose
                fprintf('  [CHANGED] (external) %s\n', e.path);
            end
        end
    end
end

% --- Build the report struct and the boolean verdict ---
report = struct();
report.nOk      = nOk;
report.nChanged = numel(changed);
report.nMissing = numel(missing);
report.changed  = changed;         % includes "[external] ..." entries, if any
report.missing  = missing;
% Clean iff nothing changed AND nothing is missing (OK count is not required to
% equal the total, since path-only externals are intentionally not counted).
ok = report.nChanged == 0 && report.nMissing == 0;
report.ok = ok;

if opts.Verbose
    fprintf('Files: %d OK, %d changed, %d missing (of %d project + %d external).\n', ...
        nOk, report.nChanged, report.nMissing, numel(files), nExt);
    if ok
        fprintf('Result: OK - project matches the lock.\n\n');
    else
        % Stream 2 (stderr) so CI and pipelines can spot drift distinctly.
        fprintf(2, 'Result: DRIFT - project does not match the lock.\n\n');
    end
end
end

% ------------------------------------------------------------------------
function items = asObjectList(v)
% Normalize a jsondecode'd JSON array-of-objects into a cell array of structs.
% jsondecode is annoyingly shape-dependent:
%   * many uniform objects -> struct ARRAY   -> num2cell to iterate
%   * exactly one object    -> single STRUCT  -> num2cell gives a 1x1 cell
%   * empty "[]" or absent   -> []            -> treat as no items
% Returning a cell list lets callers iterate uniformly regardless of which case.
if isstruct(v)
    items = num2cell(v);
elseif iscell(v)
    items = v;   % non-uniform objects can decode to a cell of structs already
else
    items = {};
end
end
