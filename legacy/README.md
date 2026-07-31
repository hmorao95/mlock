# legacy/

These are the original prototype files, kept for reference only. They are
**superseded by the `+matlabdeps` package** in the repo root and are not on the
package's path, not tested, and not maintained.

| File | Replaced by |
|---|---|
| `write_environment_lock.m` | `matlabdeps.lock` |
| `verify_lock.m` | `matlabdeps.verify` |
| `check_requirements.m` | `matlabdeps.check` |
| `environment.lock.json` | a sample lock from a different project (BEAR replication); not a `matlabdeps` lock |

Note: `verify_lock.m` and `write_environment_lock.m` rely on a Java runtime,
which some MATLAB installs (including the one this package targets) do not ship.
Safe to delete this whole folder.
