function v = version()
% VERSION - The mlock package version (single source of truth in code).
%
% Returns the semantic version of this mlock install. mlock.lock records it in
% each lockfile under "generator", so a lock states which tool version produced
% it. Keep this in step with CITATION.cff and the git tag on every release (the
% test suite cross-checks it against CITATION.cff).
%
% Note: this is the mlock tool version, distinct from the MATLAB version the lock
% also records under "matlab".
%
% Syntax:
%  v = mlock.version() Return the version string, e.g. "0.4.0".
%
% Output Arguments:
%  - v (char) - Semantic version string.
%
% See also:
%   mlock.lock

v = '0.5.0';
end
