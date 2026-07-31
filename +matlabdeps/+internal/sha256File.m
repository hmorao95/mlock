function h = sha256File(fname, normalize)
% sha256File - Lowercase hex SHA-256 of a file's bytes.
%
% Uses MATLAB's built-in crypto when available (no Java required), then falls
% back to .NET and finally Java, so it works across MATLAB installs whether or
% not a JVM/JRE is bundled. With NORMALIZE true the file's newlines are reduced
% to LF before hashing, so text files verify across platforms regardless of
% CRLF/LF differences.
%
% Syntax:
%  h = matlabdeps.internal.sha256File(fname) Hash the file bytes exactly.
%
%  h = matlabdeps.internal.sha256File(fname, normalize) Optionally normalize
%    newlines (LF) before hashing.
%
% Input Arguments:
%  - fname (string) - Path to an existing file.
%  - normalize (logical) - Reduce CRLF/CR to LF before hashing. Default: false.
%
% Output Arguments:
%  - h (string) - The 64-character lowercase hex SHA-256 digest.
if nargin < 2 || isempty(normalize)
    normalize = false;   % default: hash the file's bytes exactly
end
fname = char(fname);
if ~isfile(fname)
    error('matlabdeps:sha256:missing', 'File not found: %s', fname);
end

if normalize
    % Read the whole file, fold CRLF/CR to LF, then hash the transformed bytes.
    % (Cannot use the whole-file digest here - the bytes must be rewritten first.)
    bytes = matlabdeps.internal.normalizeNewlines(readAllBytes(fname));
    h = sha256Bytes(bytes);
    return;
end

% --- Byte-exact path ---
% Prefer BasicDigester's whole-file digest: it streams internally, so large
% files never have to be read fully into MATLAB memory. If that class is
% unavailable (older/stripped installs), fall back to hashing the read bytes.
try
    d = matlab.internal.crypto.BasicDigester('SHA256');
    h = hex(uint8(d.computeFileDigest(fname)));
    return;
catch
end
h = sha256Bytes(readAllBytes(fname));
end

% ------------------------------------------------------------------------
function h = sha256Bytes(bytes)
% SHA-256 of an in-memory byte vector. Tries three backends in order so the
% package works whether the install ships MATLAB crypto, .NET, or a JVM:
%   1) matlab.internal.crypto - pure MATLAB, no Java/.NET needed (preferred)
%   2) System.Security.Cryptography - .NET, present on Windows
%   3) java.security.MessageDigest - needs a JVM
try
    d = matlab.internal.crypto.BasicDigester('SHA256');
    h = hex(uint8(d.computeDigest(uint8(bytes))));
    return;
catch
end
try
    % MATLAB auto-marshals a uint8 vector to a .NET System.Byte[] here.
    sha = System.Security.Cryptography.SHA256.Create();
    h = hex(uint8(sha.ComputeHash(uint8(bytes))));
    return;
catch
end
% Last resort: the Java Message Digest. typecast reinterprets the signed Java
% byte[] as uint8 without changing the bit pattern.
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(uint8(bytes));
h = hex(typecast(md.digest(), 'uint8'));
end

function b = readAllBytes(fname)
% Read an entire file as raw bytes. 'r' (not 'rt') keeps binary mode so no
% newline translation happens - the hash must see the file exactly as stored.
fid = fopen(fname, 'r');
if fid < 0
    error('matlabdeps:sha256:open', 'Cannot open file: %s', fname);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>   % always close, even on error
b = fread(fid, Inf, '*uint8');                       % '*uint8' -> uint8 column
end

function s = hex(bytes)
s = string(lower(sprintf('%02x', bytes(:)')));
end
