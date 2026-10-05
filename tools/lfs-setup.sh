#!/usr/bin/env bash
# Materialize this repo's model files from Git LFS. Run as `yarn setup`.
#
#   yarn setup                  # every STEP model, plus conway's PR-smoke set
#   yarn setup --all            # everything (~3.5 GB, ~3 GB of it IFC)
#   yarn setup 'ifc/misc/**'    # just these git-lfs --include patterns
#
# Every model here is an LFS object. A clone made without git-lfs, or with a
# system config that skips smudge, has 132-byte pointer files where the
# models should be. Anything that reads them fails or produces nothing.
# conway's regression batch now refuses a pointer (conway#486), but only after
# two models had been blessed at zero rows (conway#477).
#
# Filters are installed with --skip-smudge on purpose. The CLEAN filter is the
# one that matters for safety: without it, `git add` on a materialized model
# stores the raw bytes in git over the pointer. With smudge skipped, a branch
# checkout never silently pulls gigabytes of IFC. Models arrive only through
# an explicit `git lfs pull`, which is what the rest of this script does.
#
# Idempotent. Already-present objects are not fetched again.

set -euo pipefail

cd "$(dirname "$0")/.."

log() { printf '[test-models setup] %s\n' "$*"; }

# 1. The git-lfs binary. Cloud sandboxes and fresh CI images often lack it.
if ! command -v git-lfs >/dev/null 2>&1; then
  if [ "$(id -u)" = 0 ]; then
    SUDO=
  elif sudo -n true 2>/dev/null; then
    SUDO=sudo
  else
    SUDO=none
  fi

  if [ "$SUDO" != none ] && command -v apt-get >/dev/null 2>&1; then
    log "installing git-lfs (apt)"
    $SUDO apt-get install -y git-lfs >/dev/null 2>&1 ||
      { $SUDO apt-get update >/dev/null 2>&1 && $SUDO apt-get install -y git-lfs >/dev/null; }
  elif command -v brew >/dev/null 2>&1; then
    log "installing git-lfs (brew)"
    brew install git-lfs
  else
    log "git-lfs is not installed and cannot be installed automatically here."
    log "Install it (https://git-lfs.com), then re-run: yarn setup"
    exit 1
  fi
fi

# 2. Filters for this clone only. See the header for why smudge is skipped.
git lfs install --local --skip-smudge >/dev/null

# 3. What to pull. Patterns are git-lfs --include syntax, comma-joined below.
# Model paths contain spaces ("driver board.step", "AP203 geometry only/")
# but no commas, so a comma join is safe.
includes=()
if [ $# -eq 0 ]; then
  # The whole STEP corpus is ~280 MB, small enough to take every time.
  includes+=("step/**")

  # Also take every model named on conway's PR-smoke list when conway is
  # checked out beside this repo, which is the layout of multi-repo sessions.
  # The list holds basenames, so each is resolved to its paths here. A name
  # can match more than one path; index.ifc does, and both copies are taken.
  smoke=../conway/regression/smoke_models.txt
  if [ -f "$smoke" ]; then
    while IFS= read -r name || [ -n "$name" ]; do
      case "$name" in '' | '#'*) continue ;; esac
      while IFS= read -r path; do
        includes+=("$path")
      done < <(git ls-files -- "$name" "*/$name")
    done < "$smoke"
  fi
elif [ "$1" = --all ]; then
  : # an empty include list pulls everything
else
  includes=("$@")
fi

joined=$(IFS=,; printf '%s' "${includes[*]:-}")

# 4. Pull, with backoff. LFS downloads go through whatever proxy the sandbox
# has, and a dropped connection should not end a session's setup.
pull() {
  if [ -n "$joined" ]; then
    git lfs pull --include="$joined"
  else
    git lfs pull
  fi
}

for attempt in 1 2 3 4; do
  if pull; then
    break
  fi
  if [ "$attempt" = 4 ]; then
    log "git lfs pull failed after $attempt attempts"
    exit 1
  fi
  log "git lfs pull failed (attempt $attempt), retrying"
  sleep $((2 ** attempt))
done

# 5. Report. In `git lfs ls-files` output, '*' marks an object that is
# present in the working tree and '-' marks one that is still a pointer.
if [ -n "$joined" ]; then
  listing=$(git lfs ls-files --include="$joined")
else
  listing=$(git lfs ls-files)
fi
# Match the marker by field, not by substring: "NEMA 23 - 76mm.STEP" has
# " - " in its name.
present=$(printf '%s\n' "$listing" | awk '$2 == "*"' | wc -l)
missing=$(printf '%s\n' "$listing" | awk '$2 == "-"' | wc -l)
log "materialized: $present, still pointers: $missing"
if [ "$missing" != 0 ]; then
  printf '%s\n' "$listing" | awk '$2 == "-"' | sed 's/^/  /'
  exit 1
fi
