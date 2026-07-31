# Contributing to mlock

Thanks for your interest in improving **mlock**. This is a small MATLAB package,
so the workflow is light.

## Getting set up

1. Clone the repo and put the folder that **contains** `+mlock` on your MATLAB path:
   ```matlab
   addpath('path/to/mlock');   % the parent of +mlock
   ```
2. Run the test suite:
   ```matlab
   runtests('tests')
   ```

## Development workflow

- Branch from `main` (`feature/…`, `fix/…`, `docs/…`, `chore/…`).
- Keep changes focused; one logical change per pull request.
- **Add or update tests** in `tests/testMlock.m` for any behavior change.
- Run the Code Analyzer on files you touch and keep them clean:
  ```matlab
  checkcode +mlock/yourfile.m
  ```
  (A few messages are intentional for backward compatibility — see the *Notes &
  limitations* section of the README before "fixing" them.)
- Update `CHANGELOG.md` under an `## [Unreleased]` heading using the
  [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

## Style

- Follow the surrounding code: `arguments` blocks for public functions,
  MatNWB-style docstrings, two-space continuation indents.
- The package targets **MATLAB R2021a+** and must not require Java. Prefer
  functions available across that range.
- Internal helpers live in `+mlock/+internal`; keep the public surface to
  `lock`, `verify`, `check`, `resolve`.

## Pre-commit hooks (optional but recommended)

```bash
pip install pre-commit
pre-commit install --install-hooks       # file hygiene on commit
pre-commit install --hook-type pre-push   # runs the test suite before push
```

## Commits and pull requests

- Write imperative, scoped commit messages (`fix(resolve): …`, `docs: …`).
- Fill in the pull request template. CI (GitHub Actions) must be green before merge.

## Reporting bugs / requesting features

Open an issue using the provided templates. For bugs, include the MATLAB release,
OS, a minimal entry point, and the exact error or unexpected lock output.
