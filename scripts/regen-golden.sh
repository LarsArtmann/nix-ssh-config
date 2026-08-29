#!/usr/bin/env bash
# Regenerate tests/sshd-t-golden.txt from a real VM run (capture mode).
#
# Usage:
#   ./scripts/regen-golden.sh
#
# How it works: empties the golden (which flips the VM test's snapshot
# subtest into capture mode — see the "GOLDEN-BEGIN" branch in
# tests/checks.nix), runs the VM integration test, extracts the printed
# GOLDEN block from the -L transcript, and writes it back byte-stable.
# Refuses a dirty tree; restores the golden on any failure. After a
# successful run, review `git diff tests/sshd-t-golden.txt` on purpose:
# the golden is manual-regen, never auto-updated (decision D3, plan 3).
set -euo pipefail

GOLDEN="tests/sshd-t-golden.txt"
VM_CHECK=".#checks.x86_64-linux.nixos-vm-sshd"
DRIVER_PREFIX="vm-test-run-sshd-hardened-config> "

[ -d .git ] || {
  echo "not a git repo"
  exit 1
}
[ -z "$(git status --porcelain --untracked-files=no)" ] || {
  echo "working tree not clean — commit or stash first"
  exit 1
}
[ "$(uname -m)-linux" = "x86_64-linux" ] || {
  echo "the VM integration test only exists on x86_64-linux"
  exit 1
}

restore() {
  git restore -- "$GOLDEN"
  echo "regen failed — golden restored"
}
trap restore ERR

: >"$GOLDEN"

nix build -L "$VM_CHECK" 2>&1 |
  {
    # Strip ANSI (colored -L logs hide plain greps) and the driver's
    # line prefix, keep only the captured block.
    sed 's/\x1b\[[0-9;]*m//g' |
      sed -n "/GOLDEN-BEGIN/,/GOLDEN-END/p" |
      grep -v "GOLDEN-BEGIN\|GOLDEN-END" |
      sed "s/^${DRIVER_PREFIX}//"
  } >"$GOLDEN"

# Sanity: a real capture contains directives the module controls.
grep -q "passwordauthentication" "$GOLDEN" ||
  {
    echo "capture looks empty/invalid"
    exit 1
  }
grep -q "port" "$GOLDEN" ||
  {
    echo "capture looks empty/invalid"
    exit 1
  }

trap - ERR
echo "golden regenerated ($GOLDEN): $(wc -l <"$GOLDEN") lines — review git diff before committing"
