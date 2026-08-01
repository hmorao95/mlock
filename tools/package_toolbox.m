function outFile = package_toolbox(outDir)
%PACKAGE_TOOLBOX  Build a distributable mlock Toolbox (.mltbx).
%   outFile = PACKAGE_TOOLBOX() builds mlock-<version>.mltbx in the repo root,
%   where <version> comes from mlock.version(). The resulting .mltbx installs as
%   a MATLAB Add-On (double-click, or matlab.addons.install) and can be uploaded
%   to a GitHub Release or File Exchange.
%
%   outFile = PACKAGE_TOOLBOX(outDir) writes the .mltbx into outDir instead.
%
%   Only the +mlock package (plus README/LICENSE/CHANGELOG/CITATION) is bundled;
%   tests, examples, CI, and tooling are excluded from the installed toolbox.

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);                 % tools/ sits directly under the repo root
if nargin < 1 || isempty(outDir)
    outDir = repo;
end
addpath(repo);
ver = char(mlock.version());

% Stable identifier for this toolbox. MUST NOT change across releases - MATLAB
% uses it to recognize updates to an already-installed mlock.
identifier = 'e2f4c7a0-9b1d-4a3e-8c6f-1a2b3c4d5e6f';

% --- Stage exactly what an end user needs on their path, plus docs ---
stage = tempname;
mkdir(stage);
cleaner = onCleanup(@() rmdir(stage, 's')); %#ok<NASGU>
copyfile(fullfile(repo, '+mlock'), fullfile(stage, '+mlock'));
for f = ["README.md", "LICENSE", "CHANGELOG.md", "CITATION.cff"]
    src = fullfile(repo, f);
    if isfile(src)
        copyfile(src, fullfile(stage, f));
    end
end

% --- Toolbox metadata ---
opts = matlab.addons.toolbox.ToolboxOptions(stage, identifier);
opts.ToolboxName    = 'mlock';
opts.ToolboxVersion = ver;
opts.AuthorName     = 'Hugo Morão';
opts.Summary        = ['Resolve a MATLAB project''s dependencies into a ' ...
                       'verifiable SHA-256 lockfile.'];
opts.Description    = ['mlock discovers a project''s required files and ' ...
    'MathWorks products from its entry points, pins each project file by ' ...
    'SHA-256, and records the MATLAB release and product versions in a ' ...
    'lockfile. Later, verify file integrity, check that an environment can ' ...
    'satisfy the lock, and see how the dependency set has drifted. ' ...
    'Project: https://github.com/hmorao95/mlock'];

% Best-effort minimum release (property/name varies by MATLAB version).
try
    opts.MinimumMatlabRelease = 'R2021a';
catch
end

if ~isfolder(outDir)
    mkdir(outDir);
end
opts.OutputFile = fullfile(outDir, sprintf('mlock-%s.mltbx', ver));

matlab.addons.toolbox.packageToolbox(opts);
outFile = opts.OutputFile;
fprintf('Built %s\n', outFile);
end
