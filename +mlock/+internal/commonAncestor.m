function root = commonAncestor(absPaths)
% commonAncestor - Deepest folder containing every given absolute path.
%
% Used to pick a project root that covers all entry points, so no entry's
% dependency tree is left off the MATLAB path during resolution.
%
% Syntax:
%  root = mlock.internal.commonAncestor(absPaths) Return the common
%    parent folder of the paths in ABSPATHS.
%
% Input Arguments:
%  - absPaths (string) - Absolute file or folder paths.
%
% Output Arguments:
%  - root (string) - The deepest shared ancestor folder (absolute, posix '/').

absPaths = string(absPaths);
if isempty(absPaths)
    error('mlock:commonAncestor:empty', 'No paths given.');
end

% Reduce each path to its containing FOLDER, posix-separated. We want the common
% ancestor of the files' directories, not of the files themselves.
folders = strings(1, numel(absPaths));
for i = 1:numel(absPaths)
    folders(i) = mlock.internal.toPosix(fileparts(char(absPaths(i))));
end

% Single input: its own folder is trivially the common ancestor.
if isscalar(folders)
    root = folders(1);
    return;
end

% Split every folder into path segments; the answer is the longest shared prefix
% of those segment lists (e.g. {C:,proj,a} & {C:,proj,b} -> {C:,proj}).
parts = cellfun(@(f) strsplit(f, "/"), cellstr(folders), 'UniformOutput', false);
n = min(cellfun(@numel, parts));   % can't share more segments than the shortest
common = {};
for k = 1:n
    seg = parts{1}{k};                        % candidate segment from path #1
    segs = cellfun(@(p) string(p{k}), parts); % k-th segment of every path
    % Case-insensitive comparison on Windows, exact elsewhere.
    if ispc
        match = all(strcmpi(segs, seg));
    else
        match = all(segs == string(seg));
    end
    if match
        common{end+1} = seg; %#ok<AGROW>     % still shared -> keep it
    else
        break;                                % first divergence ends the prefix
    end
end

root = string(strjoin(common, "/"));
% No shared prefix at all means the entries live on different roots/drives; there
% is no sensible project root to infer, so ask the caller to specify one.
if strlength(root) == 0
    error('mlock:commonAncestor:none', ...
        'Entry points share no common folder; pass ProjectRoot explicitly.');
end
end
