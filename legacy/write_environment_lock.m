function lock = write_environment_lock(outPath, projectRoot, meta)
%WRITE_ENVIRONMENT_LOCK  Snapshot MATLAB env + SHA-256 of key files to JSON.
%  Not a true lock file (MATLAB has no installer to restore from it), but it
%  records the exact environment and pins file hashes so drift is detectable.
%  Called automatically by main_replication.m; can also be run on its own.
if nargin < 2 || isempty(projectRoot); projectRoot = fileparts(mfilename('fullpath')); end
if nargin < 3; meta = struct(); end

% ===== EDIT PER PROJECT: files whose integrity you want pinned =============
% Key singletons + raw inputs are listed explicitly; the 31 settings, 31
% cached results, and 32 output figures are auto-appended below so the list
% tracks the package without hand-maintenance.
FILES = { ...
    'main_replication.m'; ...
    'check_requirements.m'; ...
    'REQUIREMENTS.txt'; ...
    'figure_map.csv'; ...
    'data/data_mshipping.xlsx'; ...
    'data/data_mshipping_carb_proxy.xlsx'; ...
    'data/lp_dataset.xlsx'; ...
    'data/price_surcharges_index.xlsx'; ...
};
FILES = [FILES; list_rel(projectRoot, 'settings', '*.m'  )];   % 31 specification files
FILES = [FILES; list_rel(projectRoot, 'results',  '*.mat')];   % 31 cached posterior draws
FILES = [FILES; list_rel(projectRoot, 'figures',  '*.png')];   % 32 output figures

% ===== EDIT PER PROJECT: bundled dependencies =============================
DEPS = { ...  % {name, relative_path, version}
    'BEAR Toolbox',            'toolboxes/BEAR-toolbox', '5.2.2';   ...
    'Empirical Macro (BVAR_)', 'toolboxes/BVAR_',        'snapshot (untagged upstream)'; ...
    'export_fig',              'toolboxes/export_fig',   'snapshot (~2016 build, unversioned)'; ...
};
% ==========================================================================

lock.schema         = 'matlab-env-lock';
lock.schema_version = 1;
lock.generated      = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
lock.matlab.version = version;
lock.matlab.release = version('-release');
lock.matlab.arch    = computer('arch');
if isfield(meta,'seed'); lock.run.seed = meta.seed; end
if isfield(meta,'mode'); lock.run.mode = meta.mode; end
if isfield(meta,'note'); lock.run.note = meta.note; end

v = ver;  % full product list, for the record
prod = struct('name',{},'version',{},'release',{});
for i = 1:numel(v)
    prod(i).name=v(i).Name; prod(i).version=v(i).Version; prod(i).release=v(i).Release;
end
lock.products = prod;

for i = 1:size(DEPS,1)
    lock.dependencies(i).name    = DEPS{i,1};
    lock.dependencies(i).path    = DEPS{i,2};
    lock.dependencies(i).version = DEPS{i,3};
end

files = struct('path',{},'bytes',{},'sha256',{});
for i = 1:numel(FILES)
    fp = fullfile(projectRoot, strrep(FILES{i},'/',filesep));
    files(i).path = FILES{i};
    if isfile(fp)
        d = dir(fp); files(i).bytes = d.bytes; files(i).sha256 = sha256_file(fp);
    else
        files(i).bytes = -1; files(i).sha256 = '(missing)';
    end
end
lock.files = files;

if nargin >= 1 && ~isempty(outPath)
    fid = fopen(outPath,'w');
    fwrite(fid, jsonencode(lock,'PrettyPrint',true), 'char');
    fclose(fid);
    fprintf('Environment lock written to %s\n', outPath);
end
end

% ------------------------------------------------------------------------
function c = list_rel(root, subdir, pattern)
% Return {'subdir/file', ...} for every match, forward-slashed, sorted.
d = dir(fullfile(root, subdir, pattern));
d = d(~[d.isdir]);
names = sort({d.name});
c = cell(numel(names),1);
for k = 1:numel(names); c{k} = [subdir '/' names{k}]; end
end

function h = sha256_file(fname)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(fname,'r'); raw = fread(fid,Inf,'*uint8'); fclose(fid);
md.update(raw);
h = lower(sprintf('%02x', typecast(md.digest(),'uint8')));
end
