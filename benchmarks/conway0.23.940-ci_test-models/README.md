# conway 0.23.940 — public corpus, CI runner baseline

H3 benchmark of the **published** `@bldrs-ai/conway@0.23.940` npm package, run on
GitHub CI hardware by the `perf-baseline-oneoff` workflow in bldrs-ai/conway.

The existing `conway0.23.940_test-models/` gallery in this repo was measured in
June 2025 on an arm64 Mac. This directory re-measures the same engine on CI
hardware so its numbers can be compared to CI-measured snapshots without a
machine change confounding the delta. The `-ci` suffix marks that difference.

## Provenance

| | |
|---|---|
| conway | `0.23.940` (from npm, via yarn resolutions override) |
| headless-three | `76f9ab686e08e58e7fe798e6a11ed0ad52b38c4b` |
| corpus | `bldrs-ai/test-models@f79b86b5922ef906734f7971733e976a26c5143d` |
| runner | `ubuntu-24.04-4vcpu-8gb-150gbssd` (runner group `larger`) |
| workflow run | [31506357580](https://github.com/bldrs-ai/conway/actions/runs/31506357580) |
| job | [93830093936](https://github.com/bldrs-ai/conway/actions/runs/31506357580/job/93830093936) |
| conway commit | `b3fe08c` (merged to main as `52c89f7`, PR #455) |
| measured | 2026-08-11 |

## Comparability — read before computing a delta

These numbers are only comparable to others measured on the **same runner
class**. bldrs-ai/conway#464 retired `ubuntu-22.04-8vcpu-32gb-300gbssd`
(8 vcpu / 32 GB); everything from that point runs on the 4 vcpu / 8 GB runner
above. Halving the core count does not scale parse and geometry uniformly, and
the smaller memory ceiling introduces cliffs that do not exist on a 32 GB box,
so **a delta spanning that boundary measures the runner, not the engine.**

Every snapshot committed before #464 — including `conway0.23.940_test-models/`
and every `conway*_test-models/` gallery predating it — sits on the far side of
that boundary. Re-baseline both sides in one firing of the workflow rather than
differencing against them.

2 of 48 models fail to load at this version
(`ISSUE_098_R8_F1_MAB_AR_M3_XX_XXX_MO_7000.IFC`,
`KIT-Simple-Road-Test-Web-IFC4x3_RC2.ifc`); both fail identically at
1.451.1357, so they are corpus issues rather than a regression.

## Regenerating

Actions → *Perf baseline one-off (published conway on CI runner)* → Run
workflow, with `conway_versions: 0.23.940`, `targets: public`, and
`test_models_ref` set to the corpus SHA above.
