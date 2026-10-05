# Test Models

## Getting the model files

Every model here is stored in [Git LFS](https://git-lfs.com). A clone made
without git-lfs, or with smudge skipped, has ~130-byte pointer files in place
of the models. Run

```
yarn setup                  # every STEP model, plus conway's PR-smoke set
yarn setup --all            # everything (~3.5 GB, ~3 GB of it IFC)
yarn setup 'ifc/misc/**'    # just the git-lfs --include patterns you name
```

`tools/lfs-setup.sh` installs git-lfs if it is missing (apt or brew), turns
on the LFS filters for this clone, pulls, and lists anything that is still a
pointer. The filters matter beyond downloading: without the clean filter,
`git add` on a materialized model commits its raw bytes over the pointer.
Smudge stays skipped, so a branch checkout never pulls gigabytes on its own;
models arrive only through an explicit pull. When the script installs git-lfs
with apt, it also puts skip-smudge back system-wide, because the package's own
install step turns it on.

It exits non-zero unless everything asked for arrived. That includes a
pattern or a smoke-list name that matches nothing, and a GitHub LFS bandwidth
or quota error after four tries. From an environment setup script that should
carry on regardless, call it as

```
( cd test-models && yarn setup ) || echo "test-models: models not materialized"
```


## IFC
The ifc/sp/sp-* models are concatenations of other existing IFCs at https://github.com/Swiss-Property-AG/Portfolio.

sp-231MB.ifc is a merge of all models in that directory.
sp-469MB.ifc is a merge of two copies of sp-231MB.ifc, and so on.
