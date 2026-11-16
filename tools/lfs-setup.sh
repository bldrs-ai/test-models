#!/usr/bin/env bash
# Materialize this repo's model files from Git LFS. Run as `yarn setup`.
#
#   yarn setup                  # every STEP model, plus conway's PR-smoke set
#   yarn setup --all            # everything (~3.5 GB, ~3 GB of it IFC)
#   yarn setup 'ifc/misc/**'    # just these git-lfs --include patterns
#
# Every model here is an LFS object. A clone made without git-lfs, or with a
# system config that skips smudge, has ~130-byte pointer files where the
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
# Exits 0 only when everything asked for is materialized: a pattern or a
# smoke-list name that matches nothing is an error, not an empty success.
# Idempotent. Already-present objects are not fetched again.
#
# Kept to bash 3.2 (macOS's /bin/bash): no mapfile, and empty arrays are
# expanded with the ${a[@]+"${a[@]}"} form, which `set -u` accepts there.

set -euo pipefail

cd "$(dirname "$0")/.."

log() { printf '[test-models setup] %s\n' "$*"; }

case "${1:-}" in
  -h | --help)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  --all)
    if [ $# -gt 1 ]; then
      log "--all takes no other arguments (got: $*)"
      exit 2
    fi
    ;;
esac
# An empty pattern would empty the include list, and an empty list pulls all
# ~3.5 GB. Only --all may do that.
for arg in "$@"; do
  if [ -z "$arg" ]; then
    log "empty pattern argument; use --all to pull everything"
    exit 2
  fi
done

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
    # Read before the install, which rewrites it. See below.
    smudgeBefore=$(git config --system --get filter.lfs.smudge 2>/dev/null || true)
    log "installing git-lfs (apt)"
    # Noninteractive, and willing to wait out an apt lock held by something
    # like unattended-upgrades on a freshly booted machine. stderr is left
    # alone so a failure says why.
    apt() {
      $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 "$@" >/dev/null
    }
    if ! apt install -y git-lfs && ! { apt update && apt install -y git-lfs; }; then
      log "could not install git-lfs with apt; see the errors above"
      exit 1
    fi
    # The Debian/Ubuntu package's postinst runs `git lfs install --system`,
    # which turns smudge ON machine-wide and overwrites whatever the machine
    # had. Cloud sandboxes set skip-smudge there on purpose; with it gone,
    # every later clone of this repo pulls all ~3.5 GB at checkout, which
    # filled the disk once while this script was being tested. So when the
    # machine had skip-smudge before, put it back. A machine that had no
    # system LFS config keeps the package's default.
    case "$smudgeBefore" in
      *--skip*)
        log "restoring system-wide skip-smudge, which the package install turned off"
        if ! $SUDO git lfs install --system --skip-smudge --skip-repo >/dev/null; then
          log "could not restore skip-smudge in the system git config; clones will now pull every model"
          exit 1
        fi
        ;;
    esac
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
#
# git-lfs splits --include on commas before it reads any pattern, so a path
# with a comma in it cannot be escaped, only matched around: each of , [ ] *
# in a resolved path becomes ?, which matches any one character, including
# itself. `ifc/bldrs/ïndex wëird, chars!123.ifc` is the path that needs it.
includes=()
resolved=()
unresolved=()
as_pattern() {
  local p=$1
  p=${p//\\/?}; p=${p//,/?}; p=${p//\[/?}; p=${p//\]/?}; p=${p//\*/?}
  printf '%s' "$p"
}

if [ $# -eq 0 ]; then
  # The whole STEP corpus is ~280 MB, small enough to take every time.
  includes+=("step/**")

  # Also take every model named on conway's PR-smoke list when conway is
  # checked out beside this repo, which is the layout of multi-repo sessions.
  # The list holds basenames, matched here as literal strings against every
  # tracked path's basename, so a name with glob characters in it means only
  # itself. A name can match more than one path; index.ifc does, and both
  # copies are taken. -z with core.quotePath=false keeps non-ASCII paths as
  # bytes rather than C-quoted strings.
  smoke=../conway/regression/smoke_models.txt
  if [ -f "$smoke" ]; then
    while IFS= read -r name || [ -n "$name" ]; do
      name=${name%$'\r'}
      name=${name#"${name%%[![:space:]]*}"}
      name=${name%"${name##*[![:space:]]}"}
      case "$name" in '' | '#'*) continue ;; esac
      found=0
      while IFS= read -r -d '' path; do
        if [ "${path##*/}" = "$name" ]; then
          includes+=("$(as_pattern "$path")")
          resolved+=("$path")
          found=1
        fi
      done < <(git -c core.quotePath=false ls-files -z)
      # Not fatal here, so everything else still arrives; it fails the run
      # at the end. A conway checkout newer than this one is the usual cause.
      if [ "$found" = 0 ]; then
        log "smoke list names '$name', but no tracked path has that name"
        unresolved+=("$name")
      fi
    done < "$smoke"
  fi
elif [ "$1" != --all ]; then
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

# 5. Verify. In `git lfs ls-files` output, '*' marks an object that is present
# in the working tree and '-' marks one that is still a pointer. The marker is
# matched by field, not by substring: "NEMA 23 - 76mm.STEP" has " - " in its
# name. Counting is done in awk, because BSD `wc -l` pads its output.
if [ -n "$joined" ]; then
  listing=$(git lfs ls-files --include="$joined")
else
  listing=$(git lfs ls-files)
fi
present=$(printf '%s\n' "$listing" | awk '$2 == "*" { n++ } END { print n + 0 }')
missing=$(printf '%s\n' "$listing" | awk '$2 == "-" { n++ } END { print n + 0 }')

# Every pattern must match something on its own: one that matches nothing
# would otherwise pass as long as another pattern matched. Smoke-list names
# were already checked when they were resolved, so this covers step/** and
# explicit patterns.
unmatched=()
if [ $# -eq 0 ]; then
  checked=("step/**")
elif [ "$1" != --all ]; then
  checked=("$@")
else
  checked=()
fi
for pattern in ${checked[@]+"${checked[@]}"}; do
  if [ -z "$(git lfs ls-files --include="$pattern")" ]; then
    unmatched+=("$pattern")
  fi
done

# Every path resolved from the smoke list is also checked on disk, by its own
# name, so a pattern that silently matched nothing cannot pass for success.
stubs=()
for path in ${resolved[@]+"${resolved[@]}"}; do
  if [ ! -f "$path" ] || head -c 64 -- "$path" | grep -q '^version https://git-lfs'; then
    stubs+=("$path")
  fi
done

log "materialized: $present, still pointers: $missing"
if [ $((present + missing)) = 0 ]; then
  log "nothing matched: ${joined:-<all>}"
  exit 1
fi
if [ ${#unmatched[@]} != 0 ]; then
  log "patterns that matched nothing: ${unmatched[*]}"
  exit 1
fi
if [ ${#unresolved[@]} != 0 ]; then
  log "unresolved smoke-list names: ${unresolved[*]}"
  exit 1
fi
if [ "$missing" != 0 ] || [ ${#stubs[@]} != 0 ]; then
  printf '%s\n' "$listing" | awk '$2 == "-"' | sed 's/^/  /'
  for path in ${stubs[@]+"${stubs[@]}"}; do
    printf '  still a pointer: %s\n' "$path"
  done
  exit 1
fi
