function tf = isFilesystemRoot(p)
% isFilesystemRoot - True if a path is a drive/filesystem root (no project below).
%
% Guards against inferring a dangerously broad ProjectRoot: adding genpath of a
% drive root to the path would scan the entire volume and misclassify toolbox
% files as project files.
%
% Recognizes (posix or native separators):
%   Windows drive root  -> "C:", "C:/", "C:\"
%   Windows UNC root    -> "//server", "\\server", "//server/share"
%   POSIX root          -> "/", ""
%
% Syntax:
%  tf = mlock.internal.isFilesystemRoot(p) Classify path P.
%
% Input Arguments:
%  - p (string) - A path.
%
% Output Arguments:
%  - tf (logical) - True when P is a filesystem/drive root.

s = mlock.internal.toPosix(p);          % normalize separators to '/'
s = regexprep(s, '/+$', '');                 % drop trailing slashes ("C:/" -> "C:")

if strlength(s) == 0
    tf = true;                               % POSIX root reduced to empty
    return;
end

% Bare Windows drive ("C:") or POSIX root ("/", now empty and handled above).
isDrive = ~isempty(regexp(char(s), '^[A-Za-z]:$', 'once'));

% UNC prefix with at most a server (and optional single share) but no deeper path:
%   //server  or  //server/share  -> root-ish; //server/share/dir -> not a root.
isUnc = ~isempty(regexp(char(s), '^//[^/]+(/[^/]+)?$', 'once'));

tf = isDrive || isUnc;
end
