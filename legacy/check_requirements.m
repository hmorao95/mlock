function ok = check_requirements()
%CHECK_REQUIREMENTS  Verify the environment can run this replication package.
%   ok = CHECK_REQUIREMENTS() prints a report and returns true if MATLAB, the
%   required MathWorks toolboxes, and the bundled toolboxes are all available.
%   This is the MATLAB equivalent of a dependency-manifest check (there is no
%   Project.toml/Manifest.toml in MATLAB). It is called automatically by
%   main_replication.m; you can also run it on its own.

ok = true;
fprintf('\n=== Replication package requirements check ===\n');

% --- MATLAB version (R2021b = 9.11) ---
v = ver('MATLAB');
relOK = ~verLessThan('matlab','9.11');
report(relOK, sprintf('MATLAB %s (need >= R2021b / 9.11)', v.Version));
ok = ok && relOK;

% --- Required MathWorks toolboxes ---
needTbx = { ...
    'Statistics and Machine Learning Toolbox'; ...
    'Optimization Toolbox' };
installed = {ver().Name};
for i = 1:numel(needTbx)
    has = any(strcmp(needTbx{i}, installed));
    report(has, needTbx{i});
    ok = ok && has;
end

% --- Bundled toolboxes reachable on the path (run after main_replication.m sets paths) ---
needFcn = { ...
    'BEARmain',      'BEAR Toolbox 5.2.2'; ...
    'BEARsettings',  'BEAR Toolbox 5.2.2'; ...
    'directmethods', 'Empirical Macro Toolbox (BVAR_)'; ...
    'export_fig',    'export_fig' };
for i = 1:size(needFcn,1)
    has = ~isempty(which(needFcn{i,1}));
    report(has, sprintf('%s  (%s)', needFcn{i,2}, needFcn{i,1}));
    ok = ok && has;
end

if ok
    fprintf('All requirements satisfied.\n\n');
else
    fprintf(2, ['\nOne or more requirements are missing (see [X] above).\n' ...
                'If a bundled toolbox shows [X], run this from main_replication.m\n' ...
                '(which puts toolboxes/ on the path) rather than on its own.\n\n']);
end
end

function report(pass, label)
if pass, mark = '[OK]'; else, mark = '[X ]'; end
fprintf('  %s %s\n', mark, label);
end
