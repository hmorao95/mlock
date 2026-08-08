function lk = update(lockPath, opts)
% UPDATE - Re-resolve and rewrite a lock in place from its own metadata.
%
% Regenerates a lockfile using the entry points, Extra patterns, hashing policy,
% and metadata already recorded in it - the natural fix when mlock.status reports
% that the dependency set has drifted. Equivalent to re-running mlock.lock with
% the original arguments, without having to remember them.
%
% Syntax:
%  mlock.update(lockPath) Re-resolve and overwrite the lock at LOCKPATH.
%
%  lk = mlock.update(lockPath, Name, Value) Also return the new lock struct.
%
% Input Arguments:
%  - lockPath (string) -
%    Path to a lockfile written by mlock.lock (schema_version >= 3, which stores
%    entry points relative to the project and records the Extra patterns).
%
%  - Name-Value Arguments -
%    - ProjectRoot (string) -
%      Root the lock's relative entry points are resolved against. Default: the
%      folder containing the lockfile.
%    - Verbose (logical) -
%      Print progress. Default: ``true``.
%
% Output Arguments:
%  - lk (struct) - The newly written lock contents.
%
% Usage:
%  Example 1 - Refresh a lock after adding a dependency::
%
%    [~, ok] = mlock.status("mlock.lock.json");
%    if ~ok; mlock.update("mlock.lock.json"); end
%
% See also:
%   mlock.lock, mlock.status, mlock.verify

arguments
    lockPath (1,1) string
    opts.ProjectRoot (1,1) string = ""
    opts.CleanPath (1,1) logical = false
    opts.Verbose (1,1) logical = true
end

lockPath = mlock.internal.absPath(lockPath);
if ~isfile(lockPath)
    error('mlock:update:noLock', 'Lock file not found: %s', lockPath);
end
old = jsondecode(fileread(lockPath));

if strlength(opts.ProjectRoot) > 0
    root = mlock.internal.absPath(opts.ProjectRoot);
else
    root = string(fileparts(lockPath));
end

% --- Entry points (stored relative) -> absolute on this machine ---
eps = asStrList(getFieldDef(old, 'entry_points', {}));
if isempty(eps)
    error('mlock:update:noEntries', ...
        ['Lock has no entry_points to re-resolve (older schema?). Re-create it ' ...
         'with a current mlock.lock.']);
end
epAbs = strings(1, numel(eps));
for i = 1:numel(eps)
    cand = fullfile(char(root), char(replace(eps(i), "/", filesep)));
    if ~isfile(cand)
        error('mlock:update:missingEntry', ...
            'Entry point from the lock not found under root: %s', eps(i));
    end
    epAbs(i) = mlock.internal.absPath(cand);
end

% --- Reconstruct the options the lock was originally written with ---
extra = asStrList(getFieldDef(old, 'extra', {}));

normalize = true;
if isfield(old, 'hash') && isfield(old.hash, 'normalize_newlines')
    normalize = logical(old.hash.normalize_newlines);
end

timestamp = isfield(old, 'generated');   % keep timestamps only if they were used

hashExternal = false;                     % were external files hashed before?
ext = getFieldDef(old, 'external_files', []);
if isstruct(ext) && ~isempty(ext) && isfield(ext, 'sha256')
    hashExternal = true;
end

if isfield(old, 'run') && isstruct(old.run)
    meta = old.run;
else
    meta = struct();
end

git = isfield(old, 'git');   % preserve whether provenance was recorded

% --- Rewrite the lock in place ---
lk = mlock.lock(epAbs, ProjectRoot=root, Output=lockPath, Extra=extra, ...
    NormalizeNewlines=normalize, Timestamp=timestamp, HashExternal=hashExternal, ...
    CleanPath=opts.CleanPath, Git=git, Meta=meta, Verbose=opts.Verbose);

if opts.Verbose
    fprintf('mlock: lock updated in place: %s\n', lockPath);
end
end

% ------------------------------------------------------------------------
function v = getFieldDef(s, f, default)
if isfield(s, f)
    v = s.(f);
else
    v = default;
end
end

function s = asStrList(v)
if isempty(v)
    s = strings(1, 0);
else
    s = reshape(string(v), 1, []);
end
end
