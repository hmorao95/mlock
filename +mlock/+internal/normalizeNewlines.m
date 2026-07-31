function out = normalizeNewlines(bytes)
% normalizeNewlines - Convert CRLF and lone CR to LF in a byte vector.
%
% Makes text-file hashes independent of the line-ending convention (Windows
% CRLF vs Unix LF vs old-Mac CR), so a lockfile verifies across platforms and
% survives git's autocrlf / .gitattributes normalization.
%
% Syntax:
%  out = mlock.internal.normalizeNewlines(bytes) Normalize BYTES.
%
% Input Arguments:
%  - bytes (uint8) - Raw file contents.
%
% Output Arguments:
%  - out (uint8) - Contents with all newlines reduced to LF (0x0A).

b = uint8(bytes(:));   % force a column so the shifted mask below lines up
CR = uint8(13);        % '\r'
LF = uint8(10);        % '\n'

% Pass 1 (CRLF -> LF): remove every CR that is immediately followed by an LF.
% nextIsLF is the "is the NEXT byte an LF?" mask, built by shifting the LF mask
% up one position and padding the last element with false.
isCR = (b == CR);
nextIsLF = [b(2:end) == LF; false];
b(isCR & nextIsLF) = [];      % delete just those CRs, leaving the LF in place

% Pass 2 (lone CR -> LF): any CR still left was a classic-Mac line ending;
% convert it to LF so all three conventions collapse to the same bytes.
b(b == CR) = LF;
out = b;
end
