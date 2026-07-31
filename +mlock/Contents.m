% MLOCK  Resolve a MATLAB project's dependencies into a lockfile.
%
% Workflow functions:
%   lock    - Resolve dependencies, pin files by SHA-256, write the lockfile.
%   verify  - Re-hash pinned files and report content drift against a lockfile.
%   status  - Re-resolve and report dependency-SET drift (added/removed deps).
%   check   - Verify the MATLAB release and locked products are available here.
%   resolve - Low-level: discover required files and products from entry points.
%
% Typical use:
%   mlock.lock("main.m")                 % create mlock.lock.json
%   mlock.verify("mlock.lock.json") % have files drifted?
%   mlock.check("mlock.lock.json")  % can this machine run it?
%
% See the README for options and the lockfile format.
