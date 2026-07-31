function s = column_stats(x)
%COLUMN_STATS  Summary statistics for a numeric column (example helper).
%   Lives in lib/ so mlock's transitive resolution (via genpath) has something
%   to discover beyond the entry point.
x = x(~isnan(x));
s.n    = numel(x);
s.mean = mean(x);
s.std  = std(x);
end
