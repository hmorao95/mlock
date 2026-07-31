% MATLABDEPS  Resolve a MATLAB project's dependencies into a lockfile.
%
% Workflow functions:
%   lock    - Resolve dependencies, pin files by SHA-256, write the lockfile.
%   verify  - Re-hash pinned files and report drift against a lockfile.
%   check   - Verify the MATLAB release and locked products are available here.
%   resolve - Low-level: discover required files and products from entry points.
%
% Typical use:
%   matlabdeps.lock("main.m")                 % create matlabdeps.lock.json
%   matlabdeps.verify("matlabdeps.lock.json") % have files drifted?
%   matlabdeps.check("matlabdeps.lock.json")  % can this machine run it?
%
% See the README for options and the lockfile format.
