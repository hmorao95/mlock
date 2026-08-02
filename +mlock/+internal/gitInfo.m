function info = gitInfo(root)
% gitInfo - Best-effort git provenance for a project folder.
%
% Returns the current commit, branch, and working-tree dirty flag for the git
% repository containing ROOT, so a lock can record exactly which source revision
% it was produced from. Degrades gracefully to an empty struct when git is not
% installed or ROOT is not inside a git work tree.
%
% Syntax:
%  info = mlock.internal.gitInfo(root) Query the repo containing ROOT.
%
% Input Arguments:
%  - root (string) - A folder inside (or at the top of) a git work tree.
%
% Output Arguments:
%  - info (struct) - Empty struct if unavailable; otherwise fields:
%      commit (char)  full HEAD SHA-1
%      branch (char)  current branch, or "HEAD" when detached
%      dirty  (logical) true if the work tree has uncommitted changes

info = struct();
root = char(root);

% Bail out quietly unless git is present AND root is inside a work tree.
[st, out] = runGit(root, 'rev-parse --is-inside-work-tree');
if st ~= 0 || ~strcmp(strtrim(out), 'true')
    return;
end

[sc, commit] = runGit(root, 'rev-parse HEAD');
if sc ~= 0
    return;   % e.g. a repo with no commits yet
end
info.commit = strtrim(commit);

[sb, branch] = runGit(root, 'rev-parse --abbrev-ref HEAD');
if sb == 0
    info.branch = strtrim(branch);
else
    info.branch = '';
end

[sd, porcelain] = runGit(root, 'status --porcelain');
info.dirty = (sd == 0) && ~isempty(strtrim(porcelain));
end

% ------------------------------------------------------------------------
function [st, out] = runGit(root, args)
% Run "git -C <root> <args>" and capture status + stdout. -C makes git operate
% on the target repo regardless of the current folder.
cmd = sprintf('git -C "%s" %s', root, args);
[st, out] = system(cmd);
end
