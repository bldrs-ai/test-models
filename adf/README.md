# ADF

Align Technology ClinCheck / Invisalign treatment-planning files
(`AlignDataFile ( bin )`, Version 1.1). Imported from
[pablo-mayrgundter/freality#17](https://github.com/pablo-mayrgundter/freality/pull/17)
(`bio/med/dental/`), which has the full format notes and the reference parser.

| File | What |
|---|---|
| `PM.adf` | A dental scan: 13 upper + 14 lower teeth, FACC curves, feature curves, interproximal points, gingival spline CVs. Every tooth's crown surface is a MetaStream 3 (`mts`) progressive-mesh blob. |
| `PM.meshes.bin` | The 27 crown surfaces from `PM.adf`, decoded offline (`ADFM` v1 sidecar, 80k vertices). Built by freality's `tools/mts/build_meshes.py`; there's no browser-side mts decoder yet. |

`*.adf` is LFS-tracked like the other model formats. The sidecar is plain git,
like the existing `*.bin` files under `ifc/misc/`.
