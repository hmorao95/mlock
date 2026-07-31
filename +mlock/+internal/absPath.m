function ap = absPath(p)
% absPath - Canonical absolute path (string), no Java needed.
%
% Relative inputs are resolved against the current folder (PWD). Existing paths
% are canonicalized via fileattrib; non-existent paths get '.'/'..' segments
% collapsed manually so the result is still a clean absolute path.
%
% Syntax:
%  ap = mlock.internal.absPath(p) Return the canonical absolute form of P.
%
% Input Arguments:
%  - p (string) - A path, absolute or relative to the current folder.
%
% Output Arguments:
%  - ap (string) - The canonical absolute path.
p = char(p);

% Make relative inputs absolute against the current folder first, so the result
% never depends on Java's user.dir or on where MATLAB happens to have started.
if ~isAbsolute(p)
    p = fullfile(pwd, p);
end

% Fast, authoritative path for things that exist: fileattrib returns the OS's
% own canonical spelling (resolves case, '.'/'..', short 8.3 names, symlinks).
if isfile(p) || isfolder(p)
    [ok, info] = fileattrib(p);
    if ok
        ap = string(info.Name);
        return;
    end
end

% Non-existent path (e.g. an output file we are about to create): fileattrib
% would fail, so fall back to a purely lexical normalization.
ap = string(collapseDots(p));
end

% ------------------------------------------------------------------------
function tf = isAbsolute(p)
% Cheap syntactic test - does NOT touch the filesystem.
if ispc
    % Drive-absolute ("C:\"/"C:/"), UNC ("\\server") or "//server".
    tf = ~isempty(regexp(p, '^([A-Za-z]:[\\/]|\\\\|//)', 'once'));
else
    tf = startsWith(p, '/');
end
end

function out = collapseDots(p)
% Normalize separators and resolve '.'/'..' without touching the filesystem.
% Used only for paths that do not exist yet, so we cannot ask the OS.
if ispc
    sep = '\';
    p = strrep(p, '/', '\');   % unify on backslash on Windows
else
    sep = '/';
end

% Split off a leading drive ("C:") or the leading root separator so they are not
% mistaken for path segments and cannot be popped away by a stray '..'.
prefix = '';
rest = p;
if ispc
    m = regexp(p, '^[A-Za-z]:', 'match', 'once');
    if ~isempty(m)
        prefix = m;                  % e.g. "C:"
        rest = p(numel(m)+1:end);    % remainder after the drive
    end
end
leadingSep = startsWith(rest, sep); % absolute path -> keep the leading separator

% Walk the segments, using a stack: '.' is a no-op, '..' pops the last real
% segment, anything else is pushed. This collapses "a/b/../c" to "a/c".
parts = strsplit(rest, sep);
stack = {};
for i = 1:numel(parts)
    seg = parts{i};
    if isempty(seg) || strcmp(seg, '.')
        continue;                    % empty (from doubled seps) or "." -> skip
    elseif strcmp(seg, '..')
        if ~isempty(stack)
            stack(end) = [];         % pop one level; ignore if already at top
        end
    else
        stack{end+1} = seg; %#ok<AGROW>
    end
end

% Reassemble prefix + (optional root sep) + normalized body.
body = strjoin(stack, sep);
if leadingSep
    out = [prefix sep body];
else
    out = [prefix body];
end
end
