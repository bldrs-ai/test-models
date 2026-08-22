# conway1.558.1533-ci — test-models, rc-regression baseline

Steady per-model load timings captured by the `rebless` job of conway's
`rc-regression` workflow, over the full corpus at `--concurrency 1`.

97 models measured. `conway1.451.1357-ci_1.558.1533_delta.csv` diffs this run against `../conway1.451.1357-ci_test-models/`.

## Harness

Produced by `ifc_regression_batch_main --perf` — conway loading in a plain
node process. This is **not** the same harness as the older
`conway<version>-ci_*` snapshots, which ran `scripts/benchmark.cjs` against
headless-three, i.e. conway inside a three.js host.

`parseTimeMs` / `geometryTimeMs` / `totalTimeMs` are conway's own stage
timings in both harnesses and are broadly comparable on the same runner class.
The memory columns are not: `rssMb` here excludes a GL context and a three.js
scene graph. `schemaVersion`, `geometryMemoryMb`, `preprocessorVersion` and
`originatingSystem` are `N/A` — the conway-native perf writer does not
capture them.

Because `geometryMemoryMb` is absent here, `geometryMemoryMbDelta` is `N/A`
on every row of a delta against this snapshot. That is a missing measurement,
not a zero: do not read it as "no change in geometry memory".

## Regenerating

Push an `rc-*` tag.

To re-run without cutting a tag: Actions → *RC regression (full corpus +
baseline bless)* → Run workflow, and in **"Use workflow from"** pick the
`rc-*` **tag**, not a branch. The snapshot step gates on the ref being an
`rc-*` tag — it takes the version from the tag name and has nothing to name the
directory after otherwise — so dispatching from `main` runs the digest
regression and **silently skips the perf snapshot**, finishing green having
regenerated nothing. It says so in the job log:

    ::notice::Ref 'main' is not an rc-* tag; skipping the blessed perf snapshot.

If this directory is what you came to regenerate, that notice is the thing to
check for.
