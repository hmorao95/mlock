function verify_lock(lockPath)
%VERIFY_LOCK  Compare current package state to a lock written by write_environment_lock.
here = fileparts(mfilename('fullpath')); if isempty(here); here = pwd; end
if nargin < 1 || isempty(lockPath); lockPath = fullfile(here,'environment.lock.json'); end
if ~isfile(lockPath); error('No lock file: %s (generate one first).', lockPath); end
locked  = jsondecode(fileread(lockPath));
current = write_environment_lock('', here, struct());   % regenerate, don't write
fprintf('\n===== verify_lock =====\nLock: %s\n', lockPath);
fprintf('MATLAB release  locked=%s current=%s\n', locked.matlab.release, current.matlab.release);
nOk=0; nDiff=0; nMiss=0; lf = locked.files;
for i = 1:numel(lf)
    cur = []; for j=1:numel(current.files)
        if strcmp(current.files(j).path, lf(i).path); cur=current.files(j); break; end
    end
    if isempty(cur) || strcmp(cur.sha256,'(missing)')
        fprintf('  [MISSING] %s\n', lf(i).path); nMiss=nMiss+1;
    elseif strcmp(cur.sha256, lf(i).sha256)
        nOk=nOk+1;   % silent on OK to keep the report short (~94 files)
    else
        fprintf('  [DIFF]    %s\n    locked  %s\n    current %s\n', ...
                lf(i).path, lf(i).sha256, cur.sha256); nDiff=nDiff+1;
    end
end
fprintf('Files: %d OK, %d changed, %d missing (of %d).\n\n', nOk,nDiff,nMiss,numel(lf));
end
