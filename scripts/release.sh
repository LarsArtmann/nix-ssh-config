#!/usr/bin/env bash
# Release flow for nix-ssh-config: tag -> push -> GitHub Release objects.
#
# Usage:
#   DRY_RUN=1 ./scripts/release.sh <version>   # print the plan (default)
#   DRY_RUN=0 ./scripts/release.sh <version>   # execute (tag must not exist)
#
# Steps (see CONTRIBUTING.md "Releases"):
#   1. verify clean tree and full local gate were run (gate NOT run here —
#      run it yourself; this script refuses a dirty tree),
#   2. CHANGELOG.md must have a dated section for <version>,
#   3. CHANGELOG compare links must resolve into a [0.x.y] entry,
#   4. create annotated tag (notes = the CHANGELOG section), push master + tag,
#   5. create the GitHub Release object from the tag message, mark Latest.
set -euo pipefail

VERSION="${1:?usage: ./scripts/release.sh <version> (prefix DRY_RUN=1 to preview, DRY_RUN=0 to execute)}"
TAG="v${VERSION#v}"
VER="${TAG#v}"
DRY_RUN="${DRY_RUN:-1}"

say() { if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else echo "$*"; fi; }
run() {
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else "$@"; fi
}

[ -d .git ] || { echo "not a git repo"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean — commit first"; exit 1; }

grep -q "^## \[${VER}\] — " CHANGELOG.md ||
  { echo "CHANGELOG.md has no dated '## [${VER}] — YYYY-MM-DD' section"; exit 1; }

grep -q "^\[${VER}\]: https://github.com/LarsArtmann/nix-ssh-config/compare/" CHANGELOG.md ||
  { echo "CHANGELOG.md compare link [${VER}] missing"; exit 1; }

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag $TAG already exists"; exit 1
fi

NOTES="$(awk -v start="## [${VER}] — " 'index($0, start) == 1 {on=1; next} on && /^## \[/{exit} on {print}' CHANGELOG.md)"
[ -n "$NOTES" ] || { echo "CHANGELOG section for ${VER} is empty — refusing to tag"; exit 1; }

run git tag -a "$TAG" -m "nix-ssh-config $TAG" -m "$NOTES"
run git push origin master "$TAG"
run gh release create "$TAG" --title "$TAG" --notes-from-tag
run gh release edit "$TAG" --latest
say "verify: gh run watch (both jobs, incl. the VM test on the tag commit)"
echo "done (dry-run=$DRY_RUN)"
