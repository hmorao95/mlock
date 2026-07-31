# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-07-31

### Added

- `mlock.status` — re-resolves the project from the lock and reports
  dependency-**set** drift (added/removed files and products, product version
  changes), complementing `mlock.verify` (content drift).
- `CONTRIBUTING.md`, a pull-request template, and issue forms (bug / feature).
- `examples/sample_project/` — a runnable project demonstrating lock/verify/check.
- Code coverage: CI uploads a Cobertura report to Codecov (scoped to the
  `+mlock` package), plus a `codecov.yml` and a coverage badge in the README.

### Changed

- **Lockfile schema_version 3.** `entry_points` are now stored **relative to the
  project root** (previously absolute — this removes a machine-specific path /
  username leak and lets `mlock.status` re-resolve on any checkout), and the
  `Extra` glob patterns are recorded under a new `extra` field.

## [0.3.0] - 2026-07-31

### Changed

- **BREAKING: renamed the project and package `matlabdeps` → `mlock`.** Call
  sites move from `matlabdeps.lock/verify/check/resolve` to `mlock.*`; error
  identifiers are now `mlock:*`; the lock schema id is `mlock-lock` and the
  default lockfile is `mlock.lock.json`.

### Fixed

- Code Analyzer: removed redundant brackets on single-element `Extra` arguments
  in the test suite (`NBRAK1`).

## [0.2.2] - 2026-07-31

### Changed

- Docs: mention `uv lock` -> `uv.lock` alongside npm and Cargo as a lockfile
  analogue (README and `lock` docstring).

## [0.2.1] - 2026-07-31

### Fixed

- `resolve` now refuses to infer a `ProjectRoot` that is only a filesystem/drive
  root (e.g. sibling top-level entry points reducing to `C:`), which would have
  scanned an entire drive and misclassified toolbox files as project files. It
  raises `mlock:resolve:rootTooShallow` asking for an explicit
  `ProjectRoot`. ([#2](https://github.com/hmorao95/mlock/issues/2))

## [0.2.0] - 2026-07-31

### Added

- `NormalizeNewlines` option on `mlock.lock` (default `true`): text files
  are hashed with newlines folded to LF, so locks verify across Windows/Unix.
- `Timestamp` option on `mlock.lock` (default `true`): set `false` for
  byte-reproducible lockfiles with no diff churn.
- `RequireSameProductVersions` option on `mlock.check` to fail on product
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

- Initial `+mlock` package: `lock`, `verify`, `check`, `resolve`.
- Automatic dependency resolution via
  `matlab.codetools.requiredFilesAndProducts`, with SHA-256 file pinning and a
  MATLAB release / product-version snapshot written to `mlock.lock.json`.
- `Extra` glob option to pin data/config files code analysis cannot discover.
- Unit test suite (`tests/testMlock.m`).
- GitHub Actions CI (`matlab-actions/setup-matlab` + `run-tests`) on Linux and
  Windows.
- pre-commit hooks: file hygiene, plus MATLAB tests (pre-push) and an advisory
  Code Analyzer report.
- MatNWB-style docstrings on all functions.
- README with usage, lockfile format, and layout.
