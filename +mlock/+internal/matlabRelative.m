function p = matlabRelative(absFile)
% matlabRelative - Rewrite a path under matlabroot as "$MATLABROOT/...".
%
% Keeps external (toolbox) paths portable and free of machine-specific,
% user-identifying absolute prefixes in the lockfile. Paths not under matlabroot
% are returned unchanged (posix-separated).
%
% Syntax:
%  p = mlock.internal.matlabRelative(absFile) Relativize ABSFILE.
%
% Input Arguments:
%  - absFile (string) - An absolute file path.
%
% Output Arguments:
%  - p (string) - "$MATLABROOT/<rel>" when under matlabroot, else the input.

rel = mlock.internal.toRel(absFile, string(matlabroot));
if strlength(rel) > 0
    p = "$MATLABROOT/" + rel;
else
    p = mlock.internal.toPosix(absFile);
end
end
