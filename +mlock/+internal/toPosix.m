function s = toPosix(p)
% toPosix - Convert a path to forward-slash form (string).
%
% Syntax:
%  s = mlock.internal.toPosix(p) Replace backslashes with '/'.
%
% Input Arguments:
%  - p (string) - A path using either separator.
%
% Output Arguments:
%  - s (string) - The path with '/' separators.
s = replace(string(p), "\", "/");
end
