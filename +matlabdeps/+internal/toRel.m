function rel = toRel(absFile, root)
% toRel - Path of ABSFILE relative to ROOT, posix-separated.
%
% Comparison is case-insensitive on Windows and case-sensitive elsewhere.
%
% Syntax:
%  rel = matlabdeps.internal.toRel(absFile, root) Return ABSFILE relative to
%    ROOT, or "" if ABSFILE is not located under ROOT.
%
% Input Arguments:
%  - absFile (string) - An absolute file path.
%  - root (string) - An absolute folder path.
%
% Output Arguments:
%  - rel (string) - The project-relative posix path, or "" if not under ROOT.
% Compare in posix form so '\' vs '/' never causes a false mismatch.
a = matlabdeps.internal.toPosix(absFile);
r = matlabdeps.internal.toPosix(root);
% Force a trailing '/' on the root so "C:/proj" does not spuriously match a
% sibling like "C:/project" (prefix test would otherwise pass).
if ~endsWith(r, "/")
    r = r + "/";
end
% Windows paths are case-insensitive; compare lowercased. (We only lowercase for
% the TEST - the returned slice keeps the original case, see extractAfter below.)
if ispc
    under = startsWith(lower(a), lower(r));
else
    under = startsWith(a, r);
end
if under
    rel = extractAfter(a, strlength(r));   % strip the root prefix -> relative
else
    rel = "";                              % not under root -> caller treats as external
end
end
