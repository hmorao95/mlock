function [report, inSync] = status(lockPath, opts)
% STATUS - Report how the project's dependency SET has drifted from a lock.
%
% Re-resolves the project from the entry points recorded in the lock and
% compares the current dependency set to what the lock pinned: files and
% products that were added or removed, and products whose version changed.
% This answers "did my dependencies change since I locked?" - complementing
% mlock.verify, which answers "did the CONTENT of pinned files change?".
%
% Syntax:
%  report = mlock.status(lockPath) Diff the current project against LOCKPATH.
%
%  [report, inSync] = mlock.status(lockPath, Name, Value) Also return whether
%    the set is unchanged, and control behavior with name-value options.
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
%      Print the report. Default: ``true``.
%
% Output Arguments:
%  - report (struct) -
%    Fields addedFiles, removedFiles, addedProducts, removedProducts,
%    changedProducts (each a string array), and inSync (logical).
%  - inSync (logical) - True if the dependency set is unchanged.
%
% Usage:
%  Example 1 - Detect a newly introduced dependency::
%
%    [~, ok] = mlock.status("mlock.lock.json");
%    if ~ok; disp("dependencies changed - re-run mlock.lock"); end
%
% See also:
%   mlock.lock, mlock.verify, mlock.check

arguments
    lockPath (1,1) string
    opts.ProjectRoot (1,1) string = ""
    opts.Verbose (1,1) logical = true
end

lockPath = mlock.internal.absPath(lockPath);
if ~isfile(lockPath)
    error('mlock:status:noLock', 'Lock file not found: %s', lockPath);
end
lk = jsondecode(fileread(lockPath));

if strlength(opts.ProjectRoot) > 0
    root = mlock.internal.absPath(opts.ProjectRoot);
else
    root = string(fileparts(lockPath));
end

% --- Resolve entry points (stored relative) to absolute paths on this machine ---
eps = asStrList(getFieldDef(lk, 'entry_points', {}));
if isempty(eps)
    error('mlock:status:noEntries', ...
        ['Lock has no entry_points to re-resolve (older schema?). Re-create it ' ...
         'with a current mlock.lock.']);
end
epAbs = strings(1, numel(eps));
for i = 1:numel(eps)
    cand = fullfile(char(root), char(replace(eps(i), "/", filesep)));
    if ~isfile(cand)
        error('mlock:status:missingEntry', ...
            'Entry point from the lock not found under root: %s', eps(i));
    end
    epAbs(i) = mlock.internal.absPath(cand);
end

% --- Re-resolve the current dependency set (resolved files + Extra globs) ---
res = mlock.resolve(epAbs, ProjectRoot=root, Verbose=false);
curFiles = res.files;
extra = asStrList(getFieldDef(lk, 'extra', {}));
if ~isempty(extra)
    curFiles = unique([curFiles, mlock.internal.expandGlobs(extra, root)]);
end

% --- Diff files ---
lockedFiles = objField(getFieldDef(lk, 'files', []), 'path');
addedFiles   = reshape(setdiff(curFiles, lockedFiles), 1, []);
removedFiles = reshape(setdiff(lockedFiles, curFiles), 1, []);

% --- Diff products (added / removed / version-changed) ---
curNames  = string({res.products.name});
curVers   = string({res.products.version});
lockProds = asObjectList(getFieldDef(lk, 'products', []));
lockNames = strings(1, numel(lockProds));
lockVers  = strings(1, numel(lockProds));
for i = 1:numel(lockProds)
    lockNames(i) = string(lockProds{i}.name);
    lockVers(i)  = string(lockProds{i}.version);
end
addedProducts   = reshape(setdiff(curNames, lockNames), 1, []);
removedProducts = reshape(setdiff(lockNames, curNames), 1, []);

changedProducts = strings(1, 0);
for name = intersect(curNames, lockNames)
    cv = curVers(curNames == name);
    lv = lockVers(lockNames == name);
    if ~strcmp(cv(1), lv(1))
        changedProducts(end+1) = sprintf('%s (%s -> %s)', name, lv(1), cv(1)); %#ok<AGROW>
    end
end

inSync = isempty(addedFiles) && isempty(removedFiles) && ...
         isempty(addedProducts) && isempty(removedProducts) && isempty(changedProducts);

report = struct();
report.addedFiles      = addedFiles;
report.removedFiles    = removedFiles;
report.addedProducts   = addedProducts;
report.removedProducts = removedProducts;
report.changedProducts = changedProducts;
report.inSync          = inSync;

if opts.Verbose
    fprintf('\n===== mlock.status =====\nLock: %s\nRoot: %s\n', lockPath, root);
    printList('added file',      addedFiles,      '+');
    printList('removed file',    removedFiles,    '-');
    printList('added product',   addedProducts,   '+');
    printList('removed product', removedProducts, '-');
    printList('product change',  changedProducts, '~');
    if inSync
        fprintf('Result: IN SYNC - dependency set matches the lock.\n');
        fprintf('(Run mlock.verify to check file contents.)\n\n');
    else
        fprintf(2, 'Result: DRIFT - dependency set differs; re-run mlock.lock to update.\n\n');
    end
end
end

% ------------------------------------------------------------------------
function printList(label, items, mark)
for i = 1:numel(items)
    fprintf('  [%s] %s: %s\n', mark, label, items(i));
end
end

function v = getFieldDef(s, f, default)
if isfield(s, f)
    v = s.(f);
else
    v = default;
end
end

function s = asStrList(v)
% Normalize a jsondecode'd JSON string array (char / cellstr / string / []) to
% a string row vector.
if isempty(v)
    s = strings(1, 0);
elseif ischar(v)
    s = string(v);
elseif iscell(v)
    s = reshape(string(v), 1, []);
else
    s = reshape(string(v), 1, []);
end
end

function items = asObjectList(v)
% Normalize a jsondecode'd JSON array-of-objects to a cell array of structs.
if isstruct(v)
    items = num2cell(v);
elseif iscell(v)
    items = v;
else
    items = {};
end
end

function vals = objField(v, f)
items = asObjectList(v);
vals = strings(1, numel(items));
for i = 1:numel(items)
    vals(i) = string(items{i}.(f));
end
end
