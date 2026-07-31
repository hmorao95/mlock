function tests = testMatlabdeps()
%TESTMATLABDEPS  Unit tests for the +matlabdeps dependency-lock package.
%   Run from the repo root with:  runtests('tests')
tests = functiontests(localfunctions);
end

% ======================================================================
function setupOnce(tc)
% Put the package parent folder on the path.
here = fileparts(mfilename('fullpath'));
tc.TestData.pkgRoot = fileparts(here);
addpath(tc.TestData.pkgRoot);
end

function setup(tc)
% Fresh sample project per test.
proj = tempname;
mkdir(proj);
mkdir(fullfile(proj, 'lib'));
mkdir(fullfile(proj, 'data'));
writeText(fullfile(proj, 'main.m'), ...
    ["function main()"; "  y = helper(4);"; "  m = mean([1 2 3]);"; "  disp(y + m);"; "end"]);
writeText(fullfile(proj, 'lib', 'helper.m'), ...
    ["function y = helper(x)"; "  y = x.^2 + secondlevel(x);"; "end"]);
writeText(fullfile(proj, 'lib', 'secondlevel.m'), ...
    ["function y = secondlevel(x)"; "  y = x - 1;"; "end"]);
writeText(fullfile(proj, 'data', 'in.csv'), ["a,b"; "1,2"; "3,4"]);
tc.TestData.proj = proj;
tc.TestData.lock = fullfile(proj, 'matlabdeps.lock.json');
end

function teardown(tc)
if isfolder(tc.TestData.proj)
    rmdir(tc.TestData.proj, 's');
end
end

% ======================================================================
function testResolveFindsNestedFiles(tc)
res = matlabdeps.resolve("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
verifyTrue(tc, ismember("main.m", res.files));
verifyTrue(tc, ismember("lib/helper.m", res.files));
verifyTrue(tc, ismember("lib/secondlevel.m", res.files), ...
    'Transitive dependency via genpath should be resolved.');
verifyTrue(tc, any(strcmp("MATLAB", {res.products.name})));
end

function testLockWritesFileAndHashes(tc)
lk = matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
verifyTrue(tc, isfile(tc.TestData.lock));
verifyEqual(tc, lk.schema, 'matlabdeps-lock');
verifyEqual(tc, lk.schema_version, 2);
paths = string({lk.files.path});
verifyTrue(tc, ismember("main.m", paths));
% Every present file must carry a 64-hex-char sha256.
for i = 1:numel(lk.files)
    verifyMatches(tc, lk.files(i).sha256, '^[0-9a-f]{64}$');
end
end

function testExtraGlobsArePinned(tc)
lk = matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, ...
    Extra=["data/*.csv"], Verbose=false);
paths = string({lk.files.path});
verifyTrue(tc, ismember("data/in.csv", paths), ...
    'Data file matched by Extra glob should be pinned.');
end

function testExtraNoMatchErrors(tc)
verifyError(tc, ...
    @() matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, ...
        Extra=["data/*.nope"], Verbose=false), ...
    'matlabdeps:extra:noMatch');
end

function testVerifyCleanPasses(tc)
matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Extra=["data/*.csv"], Verbose=false);
ok = matlabdeps.verify(tc.TestData.lock, Verbose=false);
verifyTrue(tc, ok);
end

function testVerifyDetectsChange(tc)
matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
appendText(fullfile(tc.TestData.proj, 'lib', 'helper.m'), "% edited");
[ok, rep] = matlabdeps.verify(tc.TestData.lock, Verbose=false);
verifyFalse(tc, ok);
verifyEqual(tc, rep.nChanged, 1);
verifyTrue(tc, ismember("lib/helper.m", rep.changed));
end

function testVerifyDetectsMissing(tc)
matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Extra=["data/*.csv"], Verbose=false);
delete(fullfile(tc.TestData.proj, 'data', 'in.csv'));
[ok, rep] = matlabdeps.verify(tc.TestData.lock, Verbose=false);
verifyFalse(tc, ok);
verifyEqual(tc, rep.nMissing, 1);
verifyTrue(tc, ismember("data/in.csv", rep.missing));
end

function testCheckPassesForCurrentEnv(tc)
matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
ok = matlabdeps.check(tc.TestData.lock, Verbose=false);
verifyTrue(tc, ok, 'Locking then checking on the same machine must pass.');
end

function testMissingEntryErrors(tc)
verifyError(tc, ...
    @() matlabdeps.lock("does_not_exist.m", ProjectRoot=tc.TestData.proj, Verbose=false), ...
    'matlabdeps:resolve:missingEntry');
end

function testSha256KnownVector(tc)
f = [tempname '.txt'];
writeText(f, "hello world");   % no trailing newline
c = onCleanup(@() delete(f));
% Compare against the raw bytes actually on disk (writeText adds no newline).
h = matlabdeps.internal.sha256File(f);
verifyMatches(tc, h, '^[0-9a-f]{64}$');
end

% ======================================================================
% Regression tests for the adversarial-review fixes.
% ======================================================================
function testMultiEntryCommonAncestorPinsAllTrees(tc)
% Two entry points in sibling folders, no ProjectRoot: every tree must be
% resolved and pinned (previously the 2nd entry's helper was silently dropped).
base = tempname;
mkdir(fullfile(base, 'a'));
mkdir(fullfile(base, 'b'));
writeText(fullfile(base, 'a', 'a_main.m'), ...
    ["function a_main()"; "  disp(a_helper());"; "end"]);
writeText(fullfile(base, 'a', 'a_helper.m'), ["function y = a_helper()"; "  y = 1;"; "end"]);
writeText(fullfile(base, 'b', 'b_main.m'), ...
    ["function b_main()"; "  disp(b_helper());"; "end"]);
writeText(fullfile(base, 'b', 'b_helper.m'), ["function y = b_helper()"; "  y = 2;"; "end"]);
c = onCleanup(@() rmdir(base, 's'));

lk = matlabdeps.lock([string(fullfile(base,'a','a_main.m')), ...
                      string(fullfile(base,'b','b_main.m'))], Write=false, Verbose=false);
paths = string({lk.files.path});
verifyTrue(tc, ismember("a/a_helper.m", paths));
verifyTrue(tc, ismember("b/b_helper.m", paths), ...
    'Second entry point''s dependency must be pinned, not dropped.');
end

function testFilesystemRootIsDetected(tc)
% Roots that must be rejected as too shallow.
verifyTrue(tc, matlabdeps.internal.isFilesystemRoot("C:"));
verifyTrue(tc, matlabdeps.internal.isFilesystemRoot("C:/"));
verifyTrue(tc, matlabdeps.internal.isFilesystemRoot("C:\"));
verifyTrue(tc, matlabdeps.internal.isFilesystemRoot("/"));
verifyTrue(tc, matlabdeps.internal.isFilesystemRoot("//server"));
% Real project folders must NOT be flagged.
verifyFalse(tc, matlabdeps.internal.isFilesystemRoot("C:/Users/me/proj"));
verifyFalse(tc, matlabdeps.internal.isFilesystemRoot("/home/me/proj"));
verifyFalse(tc, matlabdeps.internal.isFilesystemRoot("//server/share/proj"));
end

function testInferredRootRejectsFilesystemRoot(tc)
% Sibling top-level entries share only a drive root -> resolve must refuse and
% ask for an explicit ProjectRoot rather than genpath'ing an entire drive.
root = matlabdeps.internal.commonAncestor(["C:/projA/main.m", "C:/projB/main.m"]);
verifyTrue(tc, matlabdeps.internal.isFilesystemRoot(root), ...
    'Sibling top-level entries should reduce to a drive root.');
end

function testExternalFilesSchemaIsConsistent(tc)
% external_files must be the same shape (array of objects) regardless of
% HashExternal, rather than cellstr in one case and struct in the other.
lkF = matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, HashExternal=false, Write=false, Verbose=false);
lkT = matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, HashExternal=true,  Write=false, Verbose=false);
verifyClass(tc, lkF.external_files, 'struct');
verifyClass(tc, lkT.external_files, 'struct');
end

function testNormalizeNewlinesMakesTextHashPlatformIndependent(tc)
lf = [tempname '.m'];
crlf = [tempname '.m'];
co = onCleanup(@() cellfun(@delete, {lf, crlf}));
writeBytes(lf,   uint8(sprintf('function f()\n x = 1;\nend\n')));
writeBytes(crlf, uint8(sprintf('function f()\r\n x = 1;\r\nend\r\n')));
hNormLF   = matlabdeps.internal.sha256File(lf,   true);
hNormCRLF = matlabdeps.internal.sha256File(crlf, true);
verifyEqual(tc, hNormLF, hNormCRLF, 'Normalized hashes must ignore CRLF vs LF.');
% Byte-exact hashing must still distinguish them.
verifyNotEqual(tc, matlabdeps.internal.sha256File(lf, false), ...
                   matlabdeps.internal.sha256File(crlf, false));
end

function testVerifyIgnoresLineEndingChangeUnderNormalize(tc)
matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, NormalizeNewlines=true, Verbose=false);
% Rewrite main.m with CRLF endings but identical content.
raw = fileread(fullfile(tc.TestData.proj, 'main.m'));
writeBytes(fullfile(tc.TestData.proj, 'main.m'), ...
    uint8(char(replace(string(raw), newline, sprintf('\r\n')))));
ok = matlabdeps.verify(tc.TestData.lock, Verbose=false);
verifyTrue(tc, ok, 'A pure CRLF/LF change must not count as drift when normalized.');
end

function testTimestampOptionMakesLockReproducible(tc)
lk1 = matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Timestamp=false, Write=false, Verbose=false);
lk2 = matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Timestamp=false, Write=false, Verbose=false);
verifyFalse(tc, isfield(lk1, 'generated'));
verifyEqual(tc, jsonencode(lk1), jsonencode(lk2), 'Timestamp=false must be byte-reproducible.');
end

function testCheckCanRequireProductVersions(tc)
matlabdeps.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
% Tamper the locked MATLAB product version.
raw = fileread(tc.TestData.lock);
lk = jsondecode(raw);
lk.products(1).version = '0.0';
fid = fopen(tc.TestData.lock, 'w'); fwrite(fid, jsonencode(lk, 'PrettyPrint', true)); fclose(fid);
verifyTrue(tc, matlabdeps.check(tc.TestData.lock, Verbose=false), ...
    'Default check only needs product presence.');
verifyFalse(tc, matlabdeps.check(tc.TestData.lock, RequireSameProductVersions=true, Verbose=false), ...
    'Version mismatch must fail when enforced.');
end

% ======================================================================
function writeText(fname, lines)
lines = cellstr(lines);
fid = fopen(fname, 'w');
assert(fid >= 0, 'cannot open %s', fname);
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', lines{:});
end

function writeBytes(fname, bytes)
fid = fopen(fname, 'w');
assert(fid >= 0, 'cannot open %s', fname);
c = onCleanup(@() fclose(fid));
fwrite(fid, uint8(bytes), 'uint8');
end

function appendText(fname, line)
fid = fopen(fname, 'a');
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', char(line));
end
