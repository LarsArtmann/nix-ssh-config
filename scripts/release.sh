#!/usr/bin/env bash
# Release flow for nix-ssh-config: tag -> push -> GitHub Release objects.
#
# Usage:
#   DRY_RUN=1 ./scripts/release.sh <version>   # print the plan (default)
#   ./scripts/release.sh <version>             # execute (tag must not exist)
#
# Steps (see CONTRIBUTING.md "Releases"):
#   1. verify clean tree and full local gate were run (gate NOT run here —
#      run it yourself; this script refuses a dirty tree),
#   2. CHANGELOG.md must have a dated section for <version>,
#   3. CHANGELOG compare links must resolve into a [0.x.y] entry,
#   4. create annotated tag, push master + tag,
#   5. create the GitHub Release object from the tag message, mark Latest.
set -euo pipefail

VERSION="${1:?usage: ./scripts/release.sh <version> (prefix DRY_RUN=1 to preview)}"
TAG="v${VERSION#v}"
DRY_RUN="${DRY_RUN:-1}"

say() { if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else echo "$*"; fi; }
run() {
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*"; else "$@"; fi
}

[ -d .git ] || { echo "not a git repo"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean — commit first"; exit 1; }

grep -q "^## \[${TAG#v}\] — " CHANGELOG.md ||
  { echo "CHANGELOG.md has no dated '## [${TAG#v}] — YYYY-MM-DD' section"; exit 1; }

grep -q "^\[${TAG#v}\]: https://github.com/LarsArtmann/nix-ssh-config/compare/" CHANGELOG.md ||
  { echo "CHANGELOG.md compare link [${TAG#v}] missing"; exit 1; }

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag $TAG already exists"; exit 1
fi

say "git tag -a $TAG   (annotated; write release notes in the editor)"
say "git push origin master $TAG"
say "gh release create $TAG --title ... --notes-from-tag"
say "gh release edit $TAG --latest"
say "watch CI: gh run watch (both jobs, incl. the VM test on the tag commit)"
echo "done (dry-run=$DRY_RUN)"
