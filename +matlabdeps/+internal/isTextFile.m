function tf = isTextFile(p)
% isTextFile - True if a path has a known text (line-oriented) extension.
%
% Used to decide whether newline normalization may be applied before hashing.
% Binary formats (.mat, .xlsx, .png, .dta, ...) are never treated as text so
% their bytes are hashed exactly.
%
% Syntax:
%  tf = matlabdeps.internal.isTextFile(p) Classify the file at path P.
%
% Input Arguments:
%  - p (string) - A file path or name.
%
% Output Arguments:
%  - tf (logical) - True for recognized text extensions.

% Allowlist of extensions safe to newline-normalize. Deliberately an allowlist,
% not a blocklist: an unknown extension is treated as binary so we never corrupt
% a format we did not anticipate. persistent so the array is built only once.
persistent textExt
if isempty(textExt)
    textExt = ["m" "txt" "csv" "tsv" "json" "xml" "yaml" "yml" "md" "do" ...
               "r" "py" "html" "htm" "css" "js" "ini" "cfg" "toml" "tex" ...
               "bib" "sql" "sh" "bat" "gitattributes" "gitignore"];
end
% Extract the extension, strip the leading dot, lowercase it, then membership-test.
[~, ~, ext] = fileparts(char(p));
ext = lower(erase(string(ext), "."));
tf = any(ext == textExt);
end
