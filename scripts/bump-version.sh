#!/usr/bin/env bash
# Bump the OpenBOR version across every version source from one file (VERSION).
#
# Single source of truth: the repo-root VERSION file, formatted as MAJOR.MINOR.BUILD
# (e.g. 3.1.6394). The release git tag is v<MAJOR>.<MINOR>_b<BUILD> (e.g. v3.1_b6394).
#
# Usage:
#   scripts/bump-version.sh            # read VERSION, BUILD +1
#   scripts/bump-version.sh 6395       # set BUILD explicitly
#
# What it updates (do NOT hand-edit these):
#   VERSION                       single source of truth
#   engine/version.h              runtime banner -> "v<MAJOR>.<MINOR> Build <BUILD>" (all platforms)
#   engine/resources/OpenBOR.rc   Windows VERSIONINFO (numeric + string fields)
#   engine/resources/OpenBOR.res  recompiled from .rc via the build image's windres
#
# It commits the result but does NOT create a tag or release. Tag + `gh release
# create` are done separately (a release published event is what triggers CI).
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO"

# The build image carries i686-w64-mingw32-windres (not present on the host).
IMAGE="${OBOR_BUILD_IMAGE:-ghcr.io/iintothewind/openbor-build:6392}"

if [[ ! -f VERSION ]]; then
    echo "ERROR: VERSION file not found at repo root." >&2
    exit 1
fi

# Parse the current single source: MAJOR.MINOR.BUILD
# Use a herestring (not a process substitution): read returns non-zero on input
# without a trailing newline, which under `set -e` would abort before any output.
VER="$(tr -d '[:space:]' < VERSION)"
IFS='.' read -r MAJOR MINOR BUILD <<< "$VER"
if [[ -z "${MAJOR:-}" || -z "${MINOR:-}" || -z "${BUILD:-}" ]]; then
    echo "ERROR: VERSION must be MAJOR.MINOR.BUILD (got: $(tr -d '[:space:]' < VERSION))" >&2
    exit 1
fi

if [[ $# -ge 1 ]]; then
    NEW_BUILD="$1"
else
    NEW_BUILD=$((BUILD + 1))
fi

# Validate BUILD is pure digits (Windows FILEVERSION needs digits-only segments).
if ! [[ "$NEW_BUILD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: BUILD must be digits only (got: $NEW_BUILD)" >&2
    exit 1
fi

RELEASE_TAG="v${MAJOR}.${MINOR}_b${NEW_BUILD}"
HUMAN="${MAJOR}.${MINOR} ${NEW_BUILD}"          # display string, e.g. "3.1 6394"
NUMERIC="${MAJOR},${MINOR},0,${NEW_BUILD}"      # FILEVERSION quad, e.g. "3,1,0,6394"

echo "Bumping version: ${MAJOR}.${MINOR}.${BUILD} -> ${MAJOR}.${MINOR}.${NEW_BUILD}  (tag ${RELEASE_TAG})"

# 1) VERSION (single source of truth)
printf '%s.%s.%s\n' "$MAJOR" "$MINOR" "$NEW_BUILD" > VERSION

# 2) engine/version.h -> runtime banner "v<MAJOR>.<MINOR> Build <BUILD>"
sed -i \
    -e "s/^#define VERSION_MAJOR .*/#define VERSION_MAJOR \"${MAJOR}\"/" \
    -e "s/^#define VERSION_MINOR .*/#define VERSION_MINOR \"${MINOR}\"/" \
    -e "s/^#define VERSION_BUILD .*/#define VERSION_BUILD \"${NEW_BUILD}\"/" \
    engine/version.h

# 3) engine/resources/OpenBOR.rc -> Windows VERSIONINFO
#    Numeric fields take digits only; the letter-bearing build label lives in the
#    string fields (FileVersion/ProductVersion).
sed -i \
    -e "s/^ FILEVERSION .*/ FILEVERSION ${NUMERIC}/" \
    -e "s/^ PRODUCTVERSION .*/ PRODUCTVERSION ${NUMERIC}/" \
    -e "s/^\(\s*VALUE \"FileVersion\", \).*/\1\"${HUMAN}\"/" \
    -e "s/^\(\s*VALUE \"ProductVersion\", \).*/\1\"${HUMAN}\"/" \
    engine/resources/OpenBOR.rc

# 4) Regenerate OpenBOR.res from the updated .rc (win-x32 links the committed .res,
#    so it must match). windres runs inside the build image.
echo "Recompiling engine/resources/OpenBOR.res via ${IMAGE} ..."
docker run --rm \
    -v "$REPO":/src -w /src/engine \
    --entrypoint bash "$IMAGE" -c '
        set -e
        i686-w64-mingw32-windres resources/OpenBOR.rc -O coff resources/OpenBOR.res
    '

if [[ ! -s engine/resources/OpenBOR.res ]]; then
    echo "ERROR: OpenBOR.res is empty/missing after windres." >&2
    exit 1
fi

# 5) Commit (no tag, no release).
git add VERSION engine/version.h engine/resources/OpenBOR.rc engine/resources/OpenBOR.res
git commit -m "chore(release): bump version to ${MAJOR}.${MINOR} build ${NEW_BUILD}

Single-source VERSION=${MAJOR}.${MINOR}.${NEW_BUILD}; runtime banner, Windows
VERSIONINFO and the linked OpenBOR.res updated together. Release tag: ${RELEASE_TAG}."

echo
echo "Done. Committed version ${MAJOR}.${MINOR}.${NEW_BUILD}."
echo "Next: review 'git show --stat', then push, tag ${RELEASE_TAG}, and"
echo "      'gh release create ${RELEASE_TAG} ...' to trigger CI builds."
