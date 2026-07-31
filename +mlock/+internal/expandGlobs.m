function rels = expandGlobs(patterns, root)
% expandGlobs - Expand relative globs under ROOT to project-relative paths.
%
% A pattern that matches nothing raises an error, so a typo in a pinned file is
% caught early.
%
% Syntax:
%  rels = mlock.internal.expandGlobs(patterns, root) Expand PATTERNS
%    against ROOT.
%
% Input Arguments:
%  - patterns (string) -
%    Paths or globs relative to ROOT, e.g. "data/*.xlsx", "config/params.m".
%  - root (string) - The absolute project root the patterns are relative to.
%
% Output Arguments:
%  - rels (string) -
%    Unique, sorted project-relative posix paths for every matching file.
rels = strings(0);
root = mlock.internal.absPath(root);   % canonical, so toRel prefixes match
for i = 1:numel(patterns)
    pat = char(patterns(i));
    % dir() expands the wildcard (including '**' for recursive matches) and,
    % since R2016b, populates .folder so we can rebuild each absolute path.
    listing = dir(fullfile(char(root), pat));
    listing = listing(~[listing.isdir]);    % keep files only, drop folder hits
    % A pattern that matches nothing is almost always a typo in a pinned path;
    % fail loudly rather than silently omitting a file the caller expected.
    if isempty(listing)
        error('mlock:extra:noMatch', 'Extra pattern matched no files: %s', patterns(i));
    end
    for k = 1:numel(listing)
        abs = fullfile(listing(k).folder, listing(k).name);
        rel = mlock.internal.toRel(abs, root);
        % Guard against a pattern escaping the root (e.g. "../x"): only pin
        % files that actually live under the project.
        if strlength(rel) > 0
            rels(end+1) = rel; %#ok<AGROW>
        end
    end
end
rels = unique(rels);   % de-duplicate overlaps between patterns; also sorts
end
