# conway1.1565.608-g18366f01-ci — test-models, rc-regression baseline

Steady per-model load timings captured by the `rebless` job of conway's
`rc-regression` workflow, over the full corpus at `--concurrency 1`.

97 models measured. `conway1.588.1550-ci_1.1565.608-g18366f01_delta.csv` diffs this run against `../conway1.588.1550-ci_test-models/`.

## Harness

Produced by `ifc_regression_batch_main --perf` — conway loading in a plain
node process. This is **not** the same harness as the older
`conway<version>-ci_*` snapshots, which ran `scripts/benchmark.cjs` against
headless-three, i.e. conway inside a three.js host.

`parseTimeMs` / `geometryTimeMs` / `totalTimeMs` are conway's own stage
timings in both harnesses and are broadly comparable on the same runner class.
The memory columns are not: `rssMb` here excludes a GL context and a three.js
scene graph, and `geometryMemoryMb` counts only conway's own vertex+index
payload, without the host's copy of the same geometry. `schemaVersion`,
`preprocessorVersion` and `originatingSystem` are `N/A` — the conway-native
perf writer does not capture them. Every other column is measured, with two
exceptions. A row whose `loadStatus` is not `OK` carries `N/A` for the
stages the load never reached. And the three retention columns carry `N/A`
whenever the run had no `--expose-gc` to settle with, on an `OK` row as
much as a failed one — see below.

**"Comparable on the same runner class" is doing real work in that sentence.**
Two conway CI regression jobs an hour apart, on near-identical code, came out
with every model faster in the later run by a median 1.55x (conway#554). A
timing delta between two releases carries that factor as well as any change in
conway, so treat a cross-version timing move as a lead rather than a
measurement unless it is far larger than 1.5x.

`parseTimeMs` additionally is **not** comparable across the conway#554
boundary. From #554 on, a forced collection settles the heap immediately
before the parse clock starts, so the parse runs from a collected floor
instead of collecting engine-init garbage inside the timed window. **That is
an absolute cost, not a percentage.** Measured locally over 12 interleaved
pairs it was 9-12 ms per load on two 2.5 MB models — 13-16% only because
their parse takes about 60 ms — and it is not resolvable at all against
MB-Khaya's 578 ms parse. So it tilts a fast model's parse in the direction of
the newer snapshot looking faster with nothing in the parser having changed,
and leaves a slow model's alone.

`peakRssMb` is the load's high-water mark (the kernel's, via
`resourceUsage().maxRSS`); `rssMb`, `heapUsedMb`, `heapTotalMb`,
`externalMb` and `arrayBuffersMb` are single samples taken at the end of the
load with no GC first. Do not read the instants as peaks, or `heapUsedMb` as a
live set — it includes garbage GC has not collected.

`externalMb` is off-heap memory V8 knows about and `arrayBuffersMb` is its
ArrayBuffer subset — that is where the source buffer and the parse structures
live, invisible to `heapUsedMb`. Neither sees the wasm heap, so
`heapUsedMb + externalMb` is not a substitute for RSS: on a 31 MB model it
reads 284 MB against an RSS of 510 MB.

`retainedRssMb`, `retainedHeapUsedMb` and `retainedExternalMb` are the only
columns here that answer *do we leak?* rather than *does this survive?*: each
is a settled sample taken after the model was torn down minus a settled sample
taken before the load began, so it is what one full load/teardown cycle left
behind. They are signed — a cycle can end below its baseline — and they read
`N/A` wherever the run had no `--expose-gc` to settle with, because an
unsettled difference is GC timing rather than retention.

**They are not a pure leak metric**, and this is the column most likely to be
misread. Teardown is exactly `model.invalidate(true)`: it drops the vtable
builder, the descriptor cache, the scratch parsing buffer and lazy entity
fields, and it does **not** drop `geometry`, `voidGeometry`, `curves`,
`profiles`, `materials` or the source buffer — the digest iterates all of
those after it runs, so it cannot. A retention figure is therefore *the
still-live model plus anything genuinely leaked*, and a change that makes the
live model bigger moves it in the same direction a leak does. Read a movement
alongside `geometryMemoryMb`, against this corpus's own history. It is a good
regression signal for a fixed model; it is not a number to quote on its own.

Retention is measured on 97 of 97
rows here, so the settle ran. conway's `rc-regression` job runs the
corpus **twice** in one job — this blessed pass in the shipped
configuration, then a control pass with `CONWAY_PERF_EXPOSE_GC=0` whose
only purpose is to check that the settle does not perturb the timing
columns. The control pass is never blessed and none of its numbers are
in this directory; its comparison is in that run's job summary and
`perf-serial-*` artifact.

`peakWasmHeapMb` is the wasm linear memory conway's geometry engine runs in,
which nothing else here can see. It is grow-only, so one reading is the
high-water mark. Do not read it as `geometryMemoryMb`: that column is the
vertex+index payload a consumer would copy out, and the heap around it also
holds allocator overhead, fragmentation and boolean intermediates — 8 MB of
payload under an 85 MB heap on one model in this corpus. A **third** native
quantity exists and is deliberately not a column here: the native's own live
allocation (`getAllocationSize`), which is what a residency budget governs.
The three differ by an order of magnitude and none of them converts into
another.

**`geometryMemoryMb` is comparable only within one writer, which is why
every row now carries a `writer` column.** The IFC **CLI** and the IFC
regression child read 16.8 vs 22.3 MB for the same model — the same
`calculateGeometrySize()`, sampled in two pipelines that capture different
things ([conway#555](https://github.com/bldrs-ai/conway/issues/555)). The
mechanism is `RegressionCaptureState.memoization`: the IFC regression child
raises it to `FULL`, which stops `deleteTemporaries()` and leaves every CSG
intermediate and boolean operand in the map `calculateGeometrySize()` sums.
The digest walks those temporaries, so the two are not going to be made to
agree; the divergence is named instead. `gen_delta_csv.cjs` reads `writer`
and reports `N/A` rather than a number when it differences
`geometryMemoryMb` or a retention column across two of them.

IFC rows against STEP rows within this file are a **third** pair, and they do
disagree in principle for the same reason: `memoization` is a process-global
and the two regression children are separate processes, so only the IFC one
runs at `FULL`. That was true before the column existed too; the column is
what makes it visible. It has not been measured on a shared model, because
none of the corpus loads through both children.

**`totalTimeMs` is the load's wall clock — and it was not always**
([conway#562](https://github.com/bldrs-ai/conway/issues/562)). On the
regression children it used to be `geomEndMs - parseStartMs`, with
`geomStartMs` taken on the line after `parseEndMs`, so it was
`parseTimeMs + geometryTimeMs` by construction and excluded the file read,
the wasm init and the teardown. It now runs from before the file read to
after `model.invalidate(true)`, and `parsePlusGeometryMs` carries the old
sum. So **`totalTimeMs` steps up once at this boundary** and a delta across
it is a change of methodology, not of the engine — read
`parsePlusGeometryMs` for continuity, which works between two
regression-produced snapshots. Neither column is time-to-first-mesh: these
rows come from a resident, fully-extracted open, not the windowed deferred
pump Share drives (conway#562 §2).

**Do not read that as "the loader writes the same thing".** It does not, and
this is the one caveat most likely to be acted on by mistake, because both
now answer to the word "total". `ConwayModelLoader` opens its clock and
THEN builds and initialises a per-load `ConwayGeometry`; a regression child
initialises before its clock starts. Engine init — about 195 ms — is inside
one window and outside the other, which is 120% of `index.ifc`'s own total,
24% of `haus.ifc`'s and 4.3% of `MB-Khaya`'s. `parsePlusGeometryMs` is
not a way round it either: the loader emits no such column at all, and the
stage clocks it would sum are not the same intervals (the child's parse
clock includes `parseHeader` and its geometry clock includes constructing
`IfcGeometryExtraction`, where the loader excludes both).

So **`gen_delta_csv.cjs` withholds EVERY measurement column when the two
rows come from different harnesses** — every timing column, every memory
column, `geometryMemoryMb` and `peakWasmHeapMb` included. What survives
such a join is `filename`, `loadStatus`, `uname`, `schemaVersion` and
`engine`: identity, not data. The row says so on its face — a
**`comparability`** column reading `crossHarness`, so a page of `N/A` is
distinguishable from "not measured" and from "absent from that older
snapshot". Whether a single file should mix harnesses at all is
[conway#572](https://github.com/bldrs-ai/conway/issues/572).

**The retention columns carried a second, unrelated split until conway#557
([conway#557](https://github.com/bldrs-ai/conway/issues/557)).** The IFC
regression child used to build a *second* `ConwayGeometry` inside
`geometryExtraction`, so that engine's linear memory was allocated inside
the retention window and never released while the engine `main()` had
initialised sat idle. It measured as a ~55-60 MB constant on every IFC row
regardless of model size, plus its `initialize()` inside `geometryTimeMs`.
From #557 on both regression children extract on the single engine they
initialised before the baseline, so their retention columns are the same shape
and an IFC row here no longer carries a term a STEP row cannot. What does NOT
survive that boundary is a comparison with an older snapshot: IFC `retainedRssMb`,
`peakRssMb` and `geometryTimeMs` all step down once at #557 on unchanged
geometry — MB-Khaya's `retainedRssMb` 379-389 to 326-333, `index.ifc` 58.96
to 2.38, `IfcOpenHouse_IFC4`'s `geometryTimeMs` 156 to 70 ms, with digests
byte-identical throughout. The one cross-pipeline split left is the loader
path, which brings up a `ConwayGeometry` per load inside its own timed
region; nothing in this file comes from there.

Snapshots blessed before conway#552 carry none of `peakWasmHeapMb`,
`peakRssMb`, `externalMb` or `arrayBuffersMb`, nor a measured
`geometryMemoryMb`, and nothing blessed before conway#554 carries the three
retention columns, so those columns come out `N/A` in a delta against them. That is a missing
measurement, not a zero: do not read it as "no change". A snapshot blessed
before conway#557 carries those columns but populated differently on its IFC
rows; see the #557 note above before differencing one.

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
