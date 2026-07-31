function p = expandMatlabRoot(storedPath)
% expandMatlabRoot - Resolve a "$MATLABROOT/..." path against this matlabroot.
%
% Inverse of matlabRelative: turns a portable lockfile path back into an
% absolute path on the current machine. Paths without the token are returned
% unchanged.
%
% Syntax:
%  p = mlock.internal.expandMatlabRoot(storedPath) Expand STOREDPATH.
%
% Input Arguments:
%  - storedPath (string) - A path possibly beginning with "$MATLABROOT/".
%
% Output Arguments:
%  - p (string) - The resolved absolute path (posix '/').

s = string(storedPath);
token = "$MATLABROOT/";
if startsWith(s, token)
    rel = extractAfter(s, strlength(token));
    p = mlock.internal.toPosix(fullfile(matlabroot, char(rel)));
else
    p = s;
end
end
