# mlock examples

## `sample_project/`

A minimal project you can lock end-to-end:

```
sample_project/
├── run_analysis.m      # entry point
├── lib/
│   └── column_stats.m  # transitive dependency (found via genpath)
└── data/
    └── input.csv       # data file (not code — pin with Extra)
```

### Try it

From this repo root, put the package **and** the sample project on your path,
then move into the example:

```matlab
addpath(pwd);                                 % the folder that contains +mlock
addpath(genpath('examples/sample_project'));  % the sample project (incl. lib/)
cd examples/sample_project

run_analysis                     % sanity check: prints n / mean / std
```

Create the lockfile — the entry point plus its `lib/` helper are discovered
automatically; the CSV is pinned explicitly because code analysis can't see it:

```matlab
mlock.lock("run_analysis.m", Extra="data/*.csv")
```

This writes `mlock.lock.json` containing `run_analysis.m`, `lib/column_stats.m`,
and `data/input.csv`, each with a SHA-256, plus the MATLAB release and products.

Verify integrity and environment later:

```matlab
mlock.verify("mlock.lock.json")   % have the pinned files changed?
mlock.check("mlock.lock.json")    % can this machine satisfy the lock?
```

Editing any pinned file (or deleting `input.csv`) makes `mlock.verify` report the
drift. The generated `mlock.lock.json` is intentionally **not** committed here —
it is machine-specific; generate your own by running the commands above.
