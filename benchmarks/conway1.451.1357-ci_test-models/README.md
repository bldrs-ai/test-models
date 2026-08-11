# conway 1.451.1357 — public corpus, CI runner baseline

H3 benchmark of the **published** `@bldrs-ai/conway@1.451.1357` npm package, run
on GitHub CI hardware by the `perf-baseline-oneoff` workflow in bldrs-ai/conway.

Paired with `conway0.23.940-ci_test-models/`: both versions were measured in the
same workflow firing, on the same runner class, over the same corpus SHA, so the
delta between those two directories isolates engine change from hardware change.

## Provenance

| | |
|---|---|
| conway | `1.451.1357` (from npm, via yarn resolutions override) |
| headless-three | `76f9ab686e08e58e7fe798e6a11ed0ad52b38c4b` |
| corpus | `bldrs-ai/test-models@f79b86b5922ef906734f7971733e976a26c5143d` |
| runner | `ubuntu-24.04-4vcpu-8gb-150gbssd` (runner group `larger`) |
| workflow run | [31506357580](https://github.com/bldrs-ai/conway/actions/runs/31506357580) |
| job | [93830094066](https://github.com/bldrs-ai/conway/actions/runs/31506357580/job/93830094066) |
| conway commit | `b3fe08c` (merged to main as `52c89f7`, PR #455) |
| measured | 2026-08-11 |

## Result vs 0.23.940 on this hardware

Across the 45 models loading OK at both versions, 1.451.1357 is **slower on this
runner**: median total-time ratio **1.53×**, median RSS ratio 1.05×. The spread
matters more than the median — the tail is where the cost is:

| model | total 0.23.940 | total 1.451.1357 | × | RSS 0.23.940 | RSS 1.451.1357 | × |
|---|---|---|---|---|---|---|
| ISSUE_159_kleine_Wohnung_R22.ifc | 1065 ms | 39345 ms | **36.9** | 398 MB | 3134 MB | **7.9** |
| FM_ARC_DigitalHub.ifc | 1595 ms | 3401 ms | 2.13 | 443 MB | 526 MB | 1.19 |
| SKYLARK250_design-kit_blocks_detailed.ifc | 24192 ms | 48303 ms | 2.00 | 3416 MB | 5496 MB | 1.61 |
| MB-Khaya.ifc | 3084 ms | 3460 ms | 1.12 | 637 MB | 618 MB | 0.97 |
| S_Office_Integrated%20Design%20Archi.ifc | 4806 ms | 4647 ms | 0.97 | 627 MB | 614 MB | 0.98 |

**Do not read this as a pure engine regression.** Both versions ran on a 4 vcpu /
8 GB runner, and the two worst rows are also the two largest memory consumers —
ISSUE_159 at 3.1 GB and SKYLARK250 at 5.5 GB RSS on an 8 GB box. A GC/paging
cliff at that ceiling is a plausible driver, and it would not appear on the
32 GB runner these models were previously measured on. Separating engine cost
from memory-ceiling cost needs a run on a larger instance, which the retired
8-vcpu pool can no longer provide.

What is solid: on the hardware CI actually runs today, these are the numbers,
and the tail is expensive.

## Comparability

See `../conway0.23.940-ci_test-models/README.md` — the same runner-boundary rule
applies. Snapshots predating bldrs-ai/conway#464 were measured on
`ubuntu-22.04-8vcpu-32gb-300gbssd` and are not directly differenceable against
this directory.

## Regenerating

Actions → *Perf baseline one-off (published conway on CI runner)* → Run
workflow, with `conway_versions: 0.23.940 1.451.1357`, `targets: public`, and
`test_models_ref` set to the corpus SHA above.
