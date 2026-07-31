function [ok, report] = check(lockPath, opts)
% CHECK - Verify the current environment can satisfy a lockfile.
%
% Checks that the MATLAB release and the MathWorks products recorded in the lock
% are available in the running environment, and prints a pass/fail report.
% Answers "can this machine run the locked project?" (products and release),
% whereas matlabdeps.verify answers "have the project files drifted?".
%
% Syntax:
%  ok = matlabdeps.check(lockPath) Check the current environment against the
%    lockfile at LOCKPATH.
%
%  [ok, report] = matlabdeps.check(lockPath, Name, Value) Also return a detail
%    struct and control behavior with name-value options.
%
% Input Arguments:
%  - lockPath (string) -
%    Path to the lockfile written by matlabdeps.lock.
%
%  - Name-Value Arguments -
%    - RequireSameRelease (logical) -
%      Fail unless the running release exactly matches the locked release.
%      Default: ``false`` (any release passes, with a note if it differs).
%    - RequireSameProductVersions (logical) -
%      Fail unless each installed product version exactly matches the locked
%      version. Default: ``false`` (presence is enough; mismatches are noted).
%    - Verbose (logical) -
%      Print the report. Default: ``true``.
%
% Output Arguments:
%  - ok (logical) -
%    True if the release requirement is met and all locked products are
%    available.
%  - report (struct) -
%    Detail with fields releaseOk, sameRelease, products (per-product installed
%    vs. locked versions), ok.
%
% Usage:
%  Example 1 - Check the current machine::
%
%    matlabdeps.check("matlabdeps.lock.json")
%
%  Example 2 - Require the exact locked release::
%
%    ok = matlabdeps.check("matlabdeps.lock.json", RequireSameRelease=true);
%
% See also:
%   matlabdeps.lock, matlabdeps.verify

arguments
    lockPath (1,1) string
    opts.RequireSameRelease (1,1) logical = false
    opts.RequireSameProductVersions (1,1) logical = false
    opts.Verbose (1,1) logical = true
end

lockPath = matlabdeps.internal.absPath(lockPath);
if ~isfile(lockPath)
    error('matlabdeps:check:noLock', 'Lock file not found: %s', lockPath);
end
lk = jsondecode(fileread(lockPath));

% Accumulates to false as soon as any required check fails (logical AND below).
ok = true;
if opts.Verbose
    fprintf('\n===== matlabdeps.check =====\nLock: %s\n', lockPath);
end

% --- MATLAB release ---
lockedRel  = string(lk.matlab.release);        % e.g. "2024b" from the lock
currentRel = string(version('-release'));      % e.g. "2026b" right now
sameRel = strcmp(lockedRel, currentRel);
% By default any release passes (a different one is only noted, not failed);
% RequireSameRelease makes an exact-release match mandatory.
if opts.RequireSameRelease
    relOk = sameRel;
else
    relOk = true;
end
ok = ok && relOk;
if opts.Verbose
    if sameRel
        line = sprintf('MATLAB release %s', currentRel);
    else
        % Show both so the reader sees exactly what differs.
        line = sprintf('MATLAB release current=%s locked=%s', currentRel, lockedRel);
    end
    localReport(relOk, line);
end

% --- Products ---
% ver() lists every installed product; we match locked products by exact Name.
installed = ver();
instNames = string({installed.Name});
% Normalize the locked product list to a cell of records (see verify/asObjectList
% for why jsondecode's shape varies with element count).
prods = lk.products;
if isstruct(prods)
    prods = num2cell(prods);
elseif ~iscell(prods)
    prods = {};   % [] (no products) -> nothing to check
end

% Per-product audit trail returned in report.products.
prodReport = struct('name', {}, 'locked', {}, 'installed', {}, 'present', {});
for i = 1:numel(prods)
    p = prods{i};
    name = string(p.name);
    idx = find(instNames == name, 1);          % first (and only) name match
    present = ~isempty(idx);
    if present
        instVer = string(installed(idx).Version);
    else
        instVer = "(not installed)";
    end
    % A version "match" requires the product to be present in the first place.
    versionMatch = present && strcmp(instVer, string(p.version));
    % Default gate: presence is enough. Strict gate: version must match too.
    if opts.RequireSameProductVersions
        prodOk = present && versionMatch;
    else
        prodOk = present;
    end
    ok = ok && prodOk;
    prodReport(i).name      = char(name);
    prodReport(i).locked    = char(string(p.version));
    prodReport(i).installed = char(instVer);
    prodReport(i).present   = present;
    if opts.Verbose
        % Show the locked-vs-installed versions whenever they differ, even if
        % the difference is only a note (not enforced) under the default gate.
        if present && ~versionMatch
            localReport(prodOk, sprintf('%s  (locked %s, installed %s)', name, p.version, instVer));
        else
            localReport(prodOk, sprintf('%s  %s', name, p.version));
        end
    end
end

% --- Structured result for programmatic callers ---
report = struct();
report.releaseOk = relOk;
report.sameRelease = sameRel;      % informational: did the release match exactly?
report.products = prodReport;
report.ok = ok;

if opts.Verbose
    if ok
        fprintf('All locked requirements satisfied.\n\n');
    else
        % stderr so a failing environment check stands out in logs/CI.
        fprintf(2, 'One or more requirements are missing (see [X] above).\n\n');
    end
end
end

% ------------------------------------------------------------------------
function localReport(pass, label)
% One line of the pass/fail report. '[OK]' / '[X ]' are kept the same width so
% the labels line up in the console.
if pass, mark = '[OK]'; else, mark = '[X ]'; end
fprintf('  %s %s\n', mark, label);
end
