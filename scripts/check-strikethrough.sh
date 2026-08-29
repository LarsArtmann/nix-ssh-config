#!/usr/bin/env bash
# Strikethrough-balance lint over tracked Markdown. Single source shared
# by the CI step (.github/workflows/check.yml) and local runs — edit here
# only. Grammar: every ~~ opened in a doc must be closed; code spans and
# fences are excluded (literal tildes there don't strike); multi-line
# strikes are legal, so the check is per-file, not per-line.
set -euo pipefail

bad=0
for f in $(git ls-files '*.md'); do
  # `|| true` inside the group: grep exits 1 on zero matches, and
  # pipefail would otherwise abort the whole script on the first
  # tilde-free file.
  n=$(awk '/^```/{f=!f; next} !f' "$f" | sed 's/`[^`]*`//g' | { grep -o '~~' || true; } | wc -l)
  if [ $((n % 2)) -ne 0 ]; then
    echo "UNBALANCED: $f ($n)"
    bad=1
  fi
done
exit $bad
