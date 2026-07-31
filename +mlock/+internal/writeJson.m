function writeJson(s, outPath)
% writeJson - Write a struct to a pretty-printed JSON file.
%
% Creates the destination folder if it does not exist.
%
% Syntax:
%  mlock.internal.writeJson(s, outPath) Encode S and write it to OUTPATH.
%
% Input Arguments:
%  - s (struct) - The value to encode as JSON.
%  - outPath (string) - Destination file path.
outPath = char(outPath);
% Create the destination folder if the caller pointed at a not-yet-existing dir.
folder = fileparts(outPath);
if ~isempty(folder) && ~isfolder(folder)
    mkdir(folder);
end
% PrettyPrint keeps the lock human-readable and diff-friendly under version control.
txt = jsonencode(s, 'PrettyPrint', true);
fid = fopen(outPath, 'w');
if fid < 0
    error('mlock:writeJson:open', 'Cannot write file: %s', outPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>   % close even if fwrite errors
% Write as raw chars (not fprintf) so no format-specifier or newline surprises.
fwrite(fid, txt, 'char');
end
