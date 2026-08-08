function tests = testMlock()
%TESTMLOCK  Unit tests for the +mlock dependency-lock package.
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
tc.TestData.lock = fullfile(proj, 'mlock.lock.json');
end

function teardown(tc)
if isfolder(tc.TestData.proj)
    rmdir(tc.TestData.proj, 's');
end
end

% ======================================================================
function testResolveFindsNestedFiles(tc)
res = mlock.resolve("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
verifyTrue(tc, ismember("main.m", res.files));
verifyTrue(tc, ismember("lib/helper.m", res.files));
verifyTrue(tc, ismember("lib/secondlevel.m", res.files), ...
    'Transitive dependency via genpath should be resolved.');
verifyTrue(tc, any(strcmp("MATLAB", {res.products.name})));
end

function testLockWritesFileAndHashes(tc)
lk = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
verifyTrue(tc, isfile(tc.TestData.lock));
verifyEqual(tc, lk.schema, 'mlock-lock');
verifyEqual(tc, lk.schema_version, 3);
paths = string({lk.files.path});
verifyTrue(tc, ismember("main.m", paths));
% Every present file must carry a 64-hex-char sha256.
for i = 1:numel(lk.files)
    verifyMatches(tc, lk.files(i).sha256, '^[0-9a-f]{64}$');
end
end

function testExtraGlobsArePinned(tc)
lk = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, ...
    Extra="data/*.csv", Verbose=false);
paths = string({lk.files.path});
verifyTrue(tc, ismember("data/in.csv", paths), ...
    'Data file matched by Extra glob should be pinned.');
end

function testExtraNoMatchErrors(tc)
verifyError(tc, ...
    @() mlock.lock("main.m", ProjectRoot=tc.TestData.proj, ...
        Extra="data/*.nope", Verbose=false), ...
    'mlock:extra:noMatch');
end

function testVerifyCleanPasses(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Extra="data/*.csv", Verbose=false);
ok = mlock.verify(tc.TestData.lock, Verbose=false);
verifyTrue(tc, ok);
end

function testVerifyDetectsChange(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
appendText(fullfile(tc.TestData.proj, 'lib', 'helper.m'), "% edited");
[ok, rep] = mlock.verify(tc.TestData.lock, Verbose=false);
verifyFalse(tc, ok);
verifyEqual(tc, rep.nChanged, 1);
verifyTrue(tc, ismember("lib/helper.m", rep.changed));
end

function testVerifyDetectsMissing(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Extra="data/*.csv", Verbose=false);
delete(fullfile(tc.TestData.proj, 'data', 'in.csv'));
[ok, rep] = mlock.verify(tc.TestData.lock, Verbose=false);
verifyFalse(tc, ok);
verifyEqual(tc, rep.nMissing, 1);
verifyTrue(tc, ismember("data/in.csv", rep.missing));
end

function testCheckPassesForCurrentEnv(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
ok = mlock.check(tc.TestData.lock, Verbose=false);
verifyTrue(tc, ok, 'Locking then checking on the same machine must pass.');
end

function testMissingEntryErrors(tc)
verifyError(tc, ...
    @() mlock.lock("does_not_exist.m", ProjectRoot=tc.TestData.proj, Verbose=false), ...
    'mlock:resolve:missingEntry');
end

function testSha256KnownVector(tc)
f = [tempname '.txt'];
writeText(f, "hello world");   % no trailing newline
c = onCleanup(@() delete(f));
% Compare against the raw bytes actually on disk (writeText adds no newline).
h = mlock.internal.sha256File(f);
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

lk = mlock.lock([string(fullfile(base,'a','a_main.m')), ...
                      string(fullfile(base,'b','b_main.m'))], Write=false, Verbose=false);
paths = string({lk.files.path});
verifyTrue(tc, ismember("a/a_helper.m", paths));
verifyTrue(tc, ismember("b/b_helper.m", paths), ...
    'Second entry point''s dependency must be pinned, not dropped.');
end

function testFilesystemRootIsDetected(tc)
% Roots that must be rejected as too shallow.
verifyTrue(tc, mlock.internal.isFilesystemRoot("C:"));
verifyTrue(tc, mlock.internal.isFilesystemRoot("C:/"));
verifyTrue(tc, mlock.internal.isFilesystemRoot("C:\"));
verifyTrue(tc, mlock.internal.isFilesystemRoot("/"));
verifyTrue(tc, mlock.internal.isFilesystemRoot("//server"));
% Real project folders must NOT be flagged.
verifyFalse(tc, mlock.internal.isFilesystemRoot("C:/Users/me/proj"));
verifyFalse(tc, mlock.internal.isFilesystemRoot("/home/me/proj"));
verifyFalse(tc, mlock.internal.isFilesystemRoot("//server/share/proj"));
end

function testInferredRootRejectsFilesystemRoot(tc)
% Sibling top-level entries share only a drive root -> resolve must refuse and
% ask for an explicit ProjectRoot rather than genpath'ing an entire drive.
root = mlock.internal.commonAncestor(["C:/projA/main.m", "C:/projB/main.m"]);
verifyTrue(tc, mlock.internal.isFilesystemRoot(root), ...
    'Sibling top-level entries should reduce to a drive root.');
end

function testExternalFilesSchemaIsConsistent(tc)
% external_files must be the same shape (array of objects) regardless of
% HashExternal, rather than cellstr in one case and struct in the other.
lkF = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, HashExternal=false, Write=false, Verbose=false);
lkT = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, HashExternal=true,  Write=false, Verbose=false);
verifyClass(tc, lkF.external_files, 'struct');
verifyClass(tc, lkT.external_files, 'struct');
end

function testNormalizeNewlinesMakesTextHashPlatformIndependent(tc)
lf = [tempname '.m'];
crlf = [tempname '.m'];
co = onCleanup(@() cellfun(@delete, {lf, crlf}));
writeBytes(lf,   uint8(sprintf('function f()\n x = 1;\nend\n')));
writeBytes(crlf, uint8(sprintf('function f()\r\n x = 1;\r\nend\r\n')));
hNormLF   = mlock.internal.sha256File(lf,   true);
hNormCRLF = mlock.internal.sha256File(crlf, true);
verifyEqual(tc, hNormLF, hNormCRLF, 'Normalized hashes must ignore CRLF vs LF.');
% Byte-exact hashing must still distinguish them.
verifyNotEqual(tc, mlock.internal.sha256File(lf, false), ...
                   mlock.internal.sha256File(crlf, false));
end

function testVerifyIgnoresLineEndingChangeUnderNormalize(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, NormalizeNewlines=true, Verbose=false);
% Rewrite main.m with CRLF endings but identical content.
raw = fileread(fullfile(tc.TestData.proj, 'main.m'));
writeBytes(fullfile(tc.TestData.proj, 'main.m'), ...
    uint8(char(replace(string(raw), newline, sprintf('\r\n')))));
ok = mlock.verify(tc.TestData.lock, Verbose=false);
verifyTrue(tc, ok, 'A pure CRLF/LF change must not count as drift when normalized.');
end

function testTimestampOptionMakesLockReproducible(tc)
lk1 = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Timestamp=false, Write=false, Verbose=false);
lk2 = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Timestamp=false, Write=false, Verbose=false);
verifyFalse(tc, isfield(lk1, 'generated'));
verifyEqual(tc, jsonencode(lk1), jsonencode(lk2), 'Timestamp=false must be byte-reproducible.');
end

function testCheckCanRequireProductVersions(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
% Tamper the locked MATLAB product version.
raw = fileread(tc.TestData.lock);
lk = jsondecode(raw);
lk.products(1).version = '0.0';
fid = fopen(tc.TestData.lock, 'w'); fwrite(fid, jsonencode(lk, 'PrettyPrint', true)); fclose(fid);
verifyTrue(tc, mlock.check(tc.TestData.lock, Verbose=false), ...
    'Default check only needs product presence.');
verifyFalse(tc, mlock.check(tc.TestData.lock, RequireSameProductVersions=true, Verbose=false), ...
    'Version mismatch must fail when enforced.');
end

function testEntryPointsStoredRelativeAndExtraRecorded(tc)
lk = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Extra="data/*.csv", ...
    Write=false, Verbose=false);
verifyEqual(tc, lk.schema_version, 3);
verifyEqual(tc, string(lk.entry_points), "main.m", ...
    'Entry points must be stored relative to the project root, not absolute.');
verifyFalse(tc, contains(string(lk.entry_points), ":"), 'No drive-letter/absolute leak.');
verifyEqual(tc, string(lk.extra), "data/*.csv", 'Extra patterns must be recorded in the lock.');
end

function testStatusInSyncOnFreshLock(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Extra="data/*.csv", Verbose=false);
[~, inSync] = mlock.status(tc.TestData.lock, Verbose=false);
verifyTrue(tc, inSync, 'A freshly written lock must be in sync with its project.');
end

function testStatusDetectsAddedDependency(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
% Introduce a brand-new dependency called from main.
writeText(fullfile(tc.TestData.proj, 'lib', 'extra_dep.m'), ...
    ["function y = extra_dep()"; "  y = 7;"; "end"]);
writeText(fullfile(tc.TestData.proj, 'main.m'), ...
    ["function main()"; "  y = helper(4) + extra_dep();"; "  disp(y);"; "end"]);
[report, inSync] = mlock.status(tc.TestData.lock, Verbose=false);
verifyFalse(tc, inSync);
verifyTrue(tc, ismember("lib/extra_dep.m", report.addedFiles), ...
    'A newly introduced dependency must be reported as added.');
end

function testStatusDetectsRemovedDependency(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
% Rewrite main so it no longer calls the helper chain.
writeText(fullfile(tc.TestData.proj, 'main.m'), ...
    ["function main()"; "  disp(mean([1 2 3]));"; "end"]);
[report, inSync] = mlock.status(tc.TestData.lock, Verbose=false);
verifyFalse(tc, inSync);
verifyTrue(tc, ismember("lib/helper.m", report.removedFiles), ...
    'A dependency no longer used must be reported as removed.');
end

function testLockRecordsGenerator(tc)
lk = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Write=false, Verbose=false);
verifyEqual(tc, lk.generator.name, 'mlock');
verifyEqual(tc, string(lk.generator.version), string(mlock.version()), ...
    'Lock must record the producing mlock version.');
end

function testVersionMatchesCitation(tc)
% mlock.version() is the code source of truth; it must match CITATION.cff so the
% two never drift across releases.
cff = fileread(fullfile(tc.TestData.pkgRoot, 'CITATION.cff'));
tok = regexp(cff, '^version:\s*(\S+)', 'tokens', 'once', 'lineanchors');
verifyNotEmpty(tc, tok, 'CITATION.cff must declare a version.');
verifyEqual(tc, string(mlock.version()), string(tok{1}), ...
    'mlock.version() must match CITATION.cff.');
end

function testUpdateBringsLockBackInSync(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
% Introduce a new dependency -> status should report drift.
writeText(fullfile(tc.TestData.proj, 'lib', 'newdep.m'), ...
    ["function y = newdep()"; "  y = 9;"; "end"]);
writeText(fullfile(tc.TestData.proj, 'main.m'), ...
    ["function main()"; "  disp(helper(2) + newdep());"; "end"]);
[~, before] = mlock.status(tc.TestData.lock, Verbose=false);
verifyFalse(tc, before, 'Precondition: status should show drift.');
% Update rewrites the lock from its own metadata.
mlock.update(tc.TestData.lock, Verbose=false);
[~, after] = mlock.status(tc.TestData.lock, Verbose=false);
verifyTrue(tc, after, 'After update, status must be in sync again.');
end

function testUpdatePreservesTimestampAndExtra(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Extra="data/*.csv", ...
    Timestamp=false, Verbose=false);
mlock.update(tc.TestData.lock, Verbose=false);
lk = jsondecode(fileread(tc.TestData.lock));
verifyFalse(tc, isfield(lk, 'generated'), 'Timestamp=false policy must be preserved.');
verifyEqual(tc, string(lk.extra), "data/*.csv", 'Extra patterns must be preserved.');
verifyTrue(tc, ismember("data/in.csv", string({lk.files.path})), ...
    'Extra-pinned data file must still be present after update.');
end

function testAuditPassesOnFreshLock(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Extra="data/*.csv", Verbose=false);
[report, ok] = mlock.audit(tc.TestData.lock, Verbose=false);
verifyTrue(tc, ok, 'A fresh lock on the same machine must pass the audit.');
verifyTrue(tc, report.ok);
end

function testAuditFailsOnContentChange(tc)
mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Verbose=false);
appendText(fullfile(tc.TestData.proj, 'lib', 'helper.m'), "% edited");
[~, ok] = mlock.audit(tc.TestData.lock, Verbose=false);
verifyFalse(tc, ok, 'Editing a pinned file must fail the audit (via verify).');
end

function testForeignExternalIsFlagged(tc)
% A dependency resolved from an unrelated folder on the path (not the project,
% not matlabroot) must be reported in foreignFiles and raise a warning.
foreign = tempname;
mkdir(foreign);
writeText(fullfile(foreign, 'stray_helper.m'), ["function y = stray_helper()"; "  y = 5;"; "end"]);
writeText(fullfile(tc.TestData.proj, 'main.m'), ...
    ["function main()"; "  disp(stray_helper());"; "end"]);
addpath(foreign);
c = onCleanup(@() cleanupForeign(foreign));

res = verifyWarning(tc, ...
    @() mlock.resolve("main.m", ProjectRoot=tc.TestData.proj, Verbose=false), ...
    'mlock:resolve:foreignExternals');
verifyTrue(tc, any(contains(res.foreignFiles, "stray_helper.m")), ...
    'The stray-path dependency must be listed in foreignFiles.');
end

function testCleanPathKeepsForeignFilesOut(tc)
% With an unrelated folder on the path, the default records the stray file (and
% warns); CleanPath resolves on a factory path so it cannot leak in at all.
foreign = tempname;
mkdir(foreign);
writeText(fullfile(foreign, 'stray_helper.m'), ["function y = stray_helper()"; "  y = 5;"; "end"]);
writeText(fullfile(tc.TestData.proj, 'main.m'), ...
    ["function main()"; "  disp(stray_helper());"; "end"]);
addpath(foreign);
c = onCleanup(@() cleanupForeign(foreign));

% Default behaviour: stray file is recorded and a warning is raised.
resDirty = verifyWarning(tc, ...
    @() mlock.resolve("main.m", ProjectRoot=tc.TestData.proj, Verbose=false), ...
    'mlock:resolve:foreignExternals');
verifyTrue(tc, any(contains(resDirty.externalFiles, "stray_helper.m")));

% CleanPath: the stray project is off the path, so it never enters the result.
resClean = mlock.resolve("main.m", ProjectRoot=tc.TestData.proj, ...
    CleanPath=true, Verbose=false);
verifyFalse(tc, any(contains(resClean.externalFiles, "stray_helper.m")), ...
    'CleanPath must keep stray-path files out of the resolution.');
verifyEmpty(tc, resClean.foreignFiles);
% The project's own files are still resolved on the clean path.
verifyTrue(tc, ismember("main.m", resClean.files));
end

function testNonGitProjectHasNoGitBlock(tc)
% The per-test temp project is not a git repo, so no git block should appear.
lk = mlock.lock("main.m", ProjectRoot=tc.TestData.proj, Write=false, Verbose=false);
verifyFalse(tc, isfield(lk, 'git'), 'Non-git projects must not get a git block.');
end

function testGitProvenanceRecorded(tc)
[gitStatus, ~] = system('git --version');
assumeEqual(tc, gitStatus, 0, 'git is required for this test.');
repo = tempname;
mkdir(repo);
c = onCleanup(@() rmdir(repo, 's'));
writeText(fullfile(repo, 'main.m'), ["function main()"; "  disp(1);"; "end"]);
% init + commit so HEAD exists (inline identity so CI runners without a
% configured user can still commit).
runGitOrSkip(tc, repo, 'init -q');
runGitOrSkip(tc, repo, 'add -A');
runGitOrSkip(tc, repo, '-c user.email=t@e -c user.name=t commit -q -m init');

lk = mlock.lock("main.m", ProjectRoot=repo, Write=false, Verbose=false);
verifyTrue(tc, isfield(lk, 'git'), 'A git repo must produce a git block.');
verifyMatches(tc, lk.git.commit, '^[0-9a-f]{40}$');
verifyFalse(tc, lk.git.dirty, 'Freshly committed tree must be clean.');

% Dirtying the tree flips the flag.
appendText(fullfile(repo, 'main.m'), "% edit");
lk2 = mlock.lock("main.m", ProjectRoot=repo, Write=false, Verbose=false);
verifyTrue(tc, lk2.git.dirty, 'Uncommitted change must mark the tree dirty.');

% Git=false suppresses provenance entirely.
lk3 = mlock.lock("main.m", ProjectRoot=repo, Git=false, Write=false, Verbose=false);
verifyFalse(tc, isfield(lk3, 'git'), 'Git=false must omit the git block.');
end

% ======================================================================
function cleanupForeign(d)
warning('off', 'MATLAB:rmpath:DirNotFound');
try, rmpath(d); catch, end
warning('on', 'MATLAB:rmpath:DirNotFound');
if isfolder(d)
    rmdir(d, 's');
end
end

function runGitOrSkip(tc, repo, args)
st = system(sprintf('git -C "%s" %s', repo, args));
assumeEqual(tc, st, 0, sprintf('git %s failed', args));
end

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
