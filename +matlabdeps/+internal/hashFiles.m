function entries = hashFiles(relPaths, root, normalizeText)
% hashFiles - Build a path/bytes/sha256 record per file.
%
% Missing files get bytes = -1 and sha256 = "(missing)". When NORMALIZETEXT is
% true, files with a recognized text extension are hashed with newlines reduced
% to LF (see isTextFile / normalizeNewlines); binary files are always hashed
% byte-exact.
%
% Syntax:
%  entries = matlabdeps.internal.hashFiles(relPaths, root) Hash each file.
%
%  entries = matlabdeps.internal.hashFiles(relPaths, root, normalizeText)
%    Optionally normalize newlines of text files before hashing.
%
% Input Arguments:
%  - relPaths (string) - Project-relative posix paths.
%  - root (string) - The absolute project root.
%  - normalizeText (logical) - Normalize newlines of text files. Default: false.
%
% Output Arguments:
%  - entries (struct) -
%    Struct array (sorted by path) with fields path, bytes, sha256.
if nargin < 3 || isempty(normalizeText)
    normalizeText = false;
end
entries = struct('path', {}, 'bytes', {}, 'sha256', {});
relPaths = sort(relPaths);   % deterministic order -> stable lockfile
for i = 1:numel(relPaths)
    rel = relPaths(i);
    % Lock stores posix '/'; rebuild the on-disk path with the native separator.
    abs = fullfile(char(root), char(replace(rel, "/", filesep)));
    entries(i).path = char(rel);   % keep the posix form in the record
    if isfile(abs)
        d = dir(abs);
        % Normalize newlines only for recognized text files (never binaries),
        % and only when the caller asked for it.
        normalize = normalizeText && matlabdeps.internal.isTextFile(rel);
        entries(i).bytes  = d.bytes;   % raw on-disk size (pre-normalization)
        entries(i).sha256 = char(matlabdeps.internal.sha256File(abs, normalize));
    else
        % File named but not present: sentinel values instead of a hard error,
        % so a lock can still be produced and verify/compare can flag it.
        entries(i).bytes  = -1;
        entries(i).sha256 = '(missing)';
    end
end
end
