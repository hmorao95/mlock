# mlock

[![Test mlock](https://github.com/hmorao95/mlock/actions/workflows/test.yml/badge.svg)](https://github.com/hmorao95/mlock/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/hmorao95/mlock/branch/main/graph/badge.svg)](https://codecov.io/gh/hmorao95/mlock)
[![Release](https://img.shields.io/github/v/release/hmorao95/mlock)](https://github.com/hmorao95/mlock/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![MATLAB R2021a+](https://img.shields.io/badge/MATLAB-R2021a%2B-orange)

Resolve a MATLAB project's dependencies into a **lockfile** — the MATLAB analogue
of `npm install → package-lock.json`, `uv lock → uv.lock`, or Cargo's `Cargo.lock`.

Unlike a hand-maintained manifest, `mlock` **discovers** dependencies from
your code using `matlab.codetools.requiredFilesAndProducts`: it walks the call
graph from your entry points, finds every project file and MathWorks product they
require, pins each project file by SHA-256, and records the MATLAB release and
product versions. Later you can *verify* the project hasn't drifted and *check*
that another machine can satisfy the lock.

## About

MATLAB has no built-in lockfile: there's no `Project.toml`/`Manifest.toml`, and
nothing records *exactly* which files and toolboxes a piece of analysis needs.
That makes replication packages fragile — a missing toolbox, an edited helper,
or a different MATLAB release can silently change results. `mlock` closes
that gap by turning an entry point into a committed, verifiable manifest.

**Who it's for**

- Researchers shipping replication packages who need "run this and get the same
  numbers" to actually hold.
- Teams pinning a shared analysis so a teammate's environment either matches or
  fails loudly, not quietly.
- Anyone who wants CI to fail when a tracked source file or required toolbox
  changes out from under them.

**What it gives you**

- **Automatic resolution** — dependencies are discovered from the code, not
  hand-listed, so the lock can't drift out of sync with the project.
- **Integrity pinning** — every project file is fixed by SHA-256; text files are
  hashed newline-insensitively so a lock verifies across Windows and Unix.
- **Environment capture** — MATLAB release and product versions are recorded and
  checkable on any machine.
- **Portable, reproducible lockfiles** — toolbox paths stored as `$MATLABROOT/…`,
  optional timestamp-free output, sorted entries for clean diffs.
- **Zero heavy dependencies** — pure MATLAB (no Java required); one namespaced
  `+mlock` package you drop on the path.

## Requirements

- MATLAB R2021a or newer (uses `arguments` blocks and `jsonencode(...,'PrettyPrint',true)`).
- No Java required — hashing uses MATLAB's built-in crypto, with .NET/Java fallbacks.

## Install

**As a Toolbox (Add-On).** Download `mlock-<version>.mltbx` from the
[latest release](https://github.com/hmorao95/mlock/releases/latest) and
double-click it (or run `matlab.addons.install("mlock-<version>.mltbx")`). It
installs to your Add-Ons and is on the path automatically — nothing to `addpath`.

**From source.** Put the folder that **contains** `+mlock` on your path:

```matlab
addpath('C:\path\to\mlock');   % the parent of +mlock
```

To build the `.mltbx` yourself: `addpath('tools'); package_toolbox('dist')`.

## Usage

### 1. Lock

```matlab
% Discover deps from one or more entry points and write mlock.lock.json
mlock.lock("main.m")

% Multiple entry points, custom root, and pin data files code analysis can't see
mlock.lock(["run_all.m" "make_figures.m"], ...
    ProjectRoot = "C:\proj", ...
    Extra       = ["data/*.xlsx" "config/params.json"], ...
    Meta        = struct('seed','rng default','note','baseline'));

% Compute without writing, to inspect first
lk = mlock.lock("main.m", Write=false);
```

Key options (name-value):

| Option | Meaning | Default |
|---|---|---|
| `ProjectRoot` | Folder defining the project; files under it are pinned by hash | common ancestor of all entry points |
| `Output` | Lockfile path to write | `<root>/mlock.lock.json` |
| `Extra` | Globs (relative to root) for files the code analyzer can't find | none |
| `HashExternal` | Also hash out-of-project files (toolboxes) | `false` |
| `NormalizeNewlines` | Hash text files newline-insensitively (LF) so locks verify across Windows/Unix | `true` |
| `Timestamp` | Embed a `generated` timestamp; set `false` for byte-reproducible locks | `true` |
| `Meta` | Free-form struct embedded under `"run"` | `struct()` |
| `Write` | Write the file | `true` |

When multiple entry points live in different folders, `ProjectRoot` defaults to
their **common ancestor** and every entry folder is put on the path during
resolution, so no entry's dependency tree is silently dropped.

### 2. Verify (has the *content* drifted?)

Re-hashes every pinned file and compares to the lock. Returns `true` only if all match.

```matlab
ok = mlock.verify("mlock.lock.json");
[ok, report] = mlock.verify("mlock.lock.json");   % report.changed / .missing
```

### 3. Status (has the *dependency set* changed?)

Re-resolves the project from the lock's entry points and reports **added/removed**
files and products (and product version changes) — e.g. a new dependency you
introduced that isn't pinned yet. Complements `verify` (content) with set drift.

```matlab
[report, inSync] = mlock.status("mlock.lock.json");
% report.addedFiles / .removedFiles / .addedProducts / .removedProducts / .changedProducts
```

### 4. Update (re-lock in place)

When `status` shows drift, refresh the lock **using its own stored entry points,
Extra patterns, and hashing policy** — no need to retype the original `lock` call.

```matlab
mlock.update("mlock.lock.json");   % re-resolve and overwrite the lock
```

### 5. Check (can this machine run it?)

Confirms the MATLAB release and locked products are available here.

```matlab
ok = mlock.check("mlock.lock.json");
ok = mlock.check("mlock.lock.json", RequireSameRelease=true);
ok = mlock.check("mlock.lock.json", RequireSameProductVersions=true);
```

### 6. Audit (one-call gate)

Runs **verify + status + check** and returns a single pass/fail — the one line to
drop in CI or at the top of a replication script.

```matlab
assert(mlock.audit("mlock.lock.json"), "environment or project drift");
[report, ok] = mlock.audit("mlock.lock.json");   % report.verify / .status / .check
```

### Low-level: resolve only

```matlab
res = mlock.resolve("main.m");   % .files .externalFiles .products .root
```

## Lockfile format (`schema_version: 3`)

```jsonc
{
  "schema": "mlock-lock",
  "schema_version": 3,
  "generator": { "name": "mlock", "version": "0.6.0" },   // which tool wrote it
  "generated": "2026-07-31 12:00:00",           // omitted when Timestamp=false
  "matlab": { "version": "...", "release": "2026b", "arch": "win64" },
  "git": { "commit": "a5b61ff…", "branch": "main", "dirty": false },  // if a git repo
  "hash": { "algorithm": "sha256", "normalize_newlines": true },
  "entry_points": ["main.m"],                    // relative to the project root
  "extra": ["data/*.csv"],                       // Extra globs, for mlock.status
  "run": { "seed": "rng default", "note": "baseline" },
  "products": [ { "name": "MATLAB", "version": "26.2", "product_number": 1, "certain": true } ],
  "files": [ { "path": "main.m", "bytes": 104, "sha256": "43c7..." } ],
  // Always an array of objects; toolbox paths are stored portably.
  "external_files": [ { "path": "$MATLABROOT/toolbox/matlab/..." } ]
}
```

## Layout

```
mlock/
├── +mlock/
│   ├── lock.m         % resolve + hash + write lockfile
│   ├── verify.m       % re-hash pinned files, detect content drift
│   ├── status.m       % re-resolve, detect dependency-set drift
│   ├── update.m       % re-lock in place from the lock's own metadata
│   ├── check.m        % verify release + products on this machine
│   ├── audit.m        % verify + status + check in one call
│   ├── resolve.m      % low-level dependency discovery
│   └── +internal/     % helpers (absPath, sha256File, hashFiles, ...)
├── tests/
│   └── testMlock.m
└── README.md
```

## Test

```matlab
runtests('tests')
```

## Pre-commit hooks

Local checks via [pre-commit](https://pre-commit.com) are configured in
[`.pre-commit-config.yaml`](.pre-commit-config.yaml):

```bash
pip install pre-commit
pre-commit install --install-hooks       # commit-stage file hygiene
pre-commit install --hook-type pre-push  # run the test suite before push
```

- **commit stage** — fast, MATLAB-free file hygiene (trailing whitespace, final
  newline, YAML/JSON validity, LF line endings).
- **pre-push stage** — `matlab-tests` runs `runtests('tests')` and blocks the
  push on any failure (mirrors CI).
- **manual** — `matlab-lint` prints a Code Analyzer report (advisory, never
  blocks): `pre-commit run matlab-lint --all-files`.

The MATLAB hooks call [`tools/run_matlab_hook.py`](tools/run_matlab_hook.py),
which **skips gracefully (exit 0) when MATLAB is not on `PATH`**, so contributors
without a local MATLAB can still commit — CI remains the authoritative gate.

## Continuous integration

[`.github/workflows/test.yml`](.github/workflows/test.yml) runs the test suite on
every push and pull request via MathWorks' official GitHub Actions
(`matlab-actions/setup-matlab` + `matlab-actions/run-tests`), on both Linux and
Windows with the latest released MATLAB. JUnit results and Cobertura coverage are
uploaded as build artifacts. Licensing is handled automatically for public repos.

## Notes & limitations

- Dependency discovery is only as good as `requiredFilesAndProducts`: calls made
  purely by string (`feval`, `str2func`, dynamic paths) may be missed — pin those
  with `Extra`.
- `verify` checks **file integrity** (hashes); `check` checks **the environment**
  (release + products). Run both for a full reproducibility gate.
- MATLAB has no installer that restores from a lockfile, so `mlock` detects
  and reports drift rather than fixing it automatically.
```

## License

Released under the [MIT License](LICENSE) © 2026 Hugo Morão.
