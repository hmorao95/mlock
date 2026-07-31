function run_analysis()
%RUN_ANALYSIS  Tiny example entry point that mlock can resolve and lock.
%   Reads a data file, computes summary statistics via a helper in lib/, and
%   prints them. Run `mlock.lock("run_analysis.m")` from this folder to pin it.
here = fileparts(mfilename('fullpath'));
T = readtable(fullfile(here, 'data', 'input.csv'));
s = column_stats(T.value);
fprintf('n=%d  mean=%.2f  std=%.2f\n', s.n, s.mean, s.std);
end
