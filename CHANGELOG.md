# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Known issues

- Inferring `ProjectRoot` from multiple entry points placed high in the tree can
  yield a too-shallow common ancestor (e.g. a drive root). Pass `ProjectRoot`
  explicitly for such layouts until a shallow-root guard lands.

## [0.2.0] - 2026-07-31

### Added

- `NormalizeNewlines` option on `matlabdeps.lock` (default `true`): text files
  are hashed with newlines folded to LF, so locks verify across Windows/Unix.
- `Timestamp` option on `matlabdeps.lock` (default `true`): set `false` for
  byte-reproducible lockfiles with no diff churn.
- `RequireSameProductVersions` option on `matlabdeps.check` to fail on product
  version mismatches, not just missing products.
- `hash` policy block in the lockfile (`algorithm`, `normalize_newlines`) so
  `verify` re-hashes exactly as the lock was written.
- Internal helpers: `commonAncestor`, `isTextFile`, `normalizeNewlines`,
  `matlabRelative`, `expandMatlabRoot`.
- `.gitattributes` pinning LF for text sources and marking binary assets.

### Changed

- `ProjectRoot` now defaults to the **common ancestor of all entry points**, and
  every entry's folder is added to the path during resolution.
- `external_files` is now always an array of objects (was a string array when
  `HashExternal=false`).
- External toolbox paths are stored as `$MATLABROOT/...` instead of absolute
  machine-specific paths.
- Products are sorted by name for stable lockfile diffs.
- `verify` re-hashes using the lock's recorded newline policy and now also
  verifies hashed external files.

### Fixed

- Multi-entry-point projects spanning folders no longer silently drop the
  dependencies of entry points other than the first.
- Text-file hashes are line-ending independent, eliminating false "drift" when a
  repo crosses between Windows (CRLF) and Unix (LF).
- Lockfiles no longer embed machine-specific absolute paths (username leak).

## [0.1.0] - 2026-07-31

### Added

- Initial `+matlabdeps` package: `lock`, `verify`, `check`, `resolve`.
- Automatic dependency resolution via
  `matlab.codetools.requiredFilesAndProducts`, with SHA-256 file pinning and a
  MATLAB release / product-version snapshot written to `matlabdeps.lock.json`.
- `Extra` glob option to pin data/config files code analysis cannot discover.
- Unit test suite (`tests/testMatlabdeps.m`).
- GitHub Actions CI (`matlab-actions/setup-matlab` + `run-tests`) on Linux and
  Windows.
- pre-commit hooks: file hygiene, plus MATLAB tests (pre-push) and an advisory
  Code Analyzer report.
- MatNWB-style docstrings on all functions.
- README with usage, lockfile format, and layout.
