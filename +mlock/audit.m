function [report, ok] = audit(lockPath, opts)
% AUDIT - One-call reproducibility gate: verify + status + check.
%
% Runs all three checks against a lock and returns a single pass/fail:
%   verify - have the pinned file CONTENTS changed?
%   status - has the dependency SET changed (added/removed deps)?
%   check  - can this ENVIRONMENT (release + products) satisfy the lock?
% Drop it in CI or at the top of a replication script to assert, in one line,
% that the project and machine still match the lock.
%
% Syntax:
%  ok = mlock.audit(lockPath) Run the full audit; true only if all pass.
%
%  [report, ok] = mlock.audit(lockPath, Name, Value) Also return the combined
%    report and control the environment checks.
%
% Input Arguments:
%  - lockPath (string) - Path to a lockfile written by mlock.lock.
%
%  - Name-Value Arguments -
%    - ProjectRoot (string) -
%      Root used by the verify/status stages. Default: the lockfile's folder.
%    - RequireSameRelease (logical) -
%      Passed to mlock.check. Default: ``false``.
%    - RequireSameProductVersions (logical) -
%      Passed to mlock.check. Default: ``false``.
%    - Verbose (logical) -
%      Print each section plus a summary. Default: ``true``.
%
% Output Arguments:
%  - report (struct) - Fields verify, status, check (the sub-reports), and ok.
%  - ok (logical) - True only if verify, status, and check all pass.
%
% Usage:
%  Example 1 - Gate a replication run::
%
%    assert(mlock.audit("mlock.lock.json"), "environment/project drift");
%
% See also:
%   mlock.verify, mlock.status, mlock.check, mlock.lock

arguments
    lockPath (1,1) string
    opts.ProjectRoot (1,1) string = ""
    opts.RequireSameRelease (1,1) logical = false
    opts.RequireSameProductVersions (1,1) logical = false
    opts.Verbose (1,1) logical = true
end

[vok, vrep] = mlock.verify(lockPath, ProjectRoot=opts.ProjectRoot, Verbose=opts.Verbose);
[srep, sok] = mlock.status(lockPath, ProjectRoot=opts.ProjectRoot, Verbose=opts.Verbose);
[cok, crep] = mlock.check(lockPath, ...
    RequireSameRelease=opts.RequireSameRelease, ...
    RequireSameProductVersions=opts.RequireSameProductVersions, ...
    Verbose=opts.Verbose);

ok = vok && sok && cok;
report = struct('verify', vrep, 'status', srep, 'check', crep, 'ok', ok);

if opts.Verbose
    fprintf('\n===== mlock.audit =====\n');
    fprintf('  files   (verify): %s\n', passFail(vok));
    fprintf('  deps    (status): %s\n', passFail(sok));
    fprintf('  env     (check):  %s\n', passFail(cok));
    if ok
        fprintf('Result: PASS - project and environment match the lock.\n\n');
    else
        fprintf(2, 'Result: FAIL - see the sections above.\n\n');
    end
end
end

% ------------------------------------------------------------------------
function s = passFail(b)
if b
    s = 'PASS';
else
    s = 'FAIL';
end
end
