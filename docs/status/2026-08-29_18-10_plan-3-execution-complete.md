# Plan 3 Execution Complete — v0.1.3 Shipped, Depth Added, One Real Bug Found

**Date:** 2026-08-29 17:5x CEST
**Plan:** `docs/planning/2026-08-29_16-18_pareto-execution-plan-3-v0.1.3-and-depth.md`
**Verdict:** all 10 M-tasks executed, all 74 fine tasks covered, all 5
decision gates resolved with the plan's recommendations. Every new
assertion was kill-switched (observed red, then green); every gate run
bare with the exit code in hand.

## a) Fully done

- **M1 — v0.1.3 released end-to-end.** D1 merged first (Dependabot PR
  #2, checkout 4.4.0→7.0.1, its CI green). Full four-command gate, then
  the release flow hit a real bug: `scripts/release.sh`'s execute path
  printed commands but never ran them (`run()` defined, unused) — fixed,
  then dated CHANGELOG, dry-run, tag, push, Release object **Latest**
  (`v0.1.3` = `65ad426`), all three CI jobs green on the release commit.
- **M2 — downstream pinned & pushed.** `nix-internatial-telephony` lock
  rev equals the v0.1.3 tag commit; both SSH VM suites rebuilt green;
  explicit-paths commit (maintainer's WIP deliberately excluded); their
  CI went red on `mirroredBoots` from the _previously unpushed_ mixed
  commit `bcf9271` — root-caused (manual grub device vs disko-derived
  one), the maintainer's own uncommitted fix was committed verbatim
  (attributed), their CI is green again on all jobs.
- **M3 — test depth + a real runtime bug.** Prompt-path VM proof
  (kbd-server variant node, locked user, sshpass-driven exchange,
  journal evidence both directions) and port property tests
  (`nixos-port-bounds`, `hm-port-bounds`, `builtins.tryEval`-based,
  wiring-forcing). The positive control immediately caught: **upstream
  nixpkgs couples `security.pam.services.sshd.unixAuth` to
  `PasswordAuthentication`** — keys-only + explicit kbd-interactive was
  `pam_deny`-denied end-to-end; the documented 2FA recipe silently never
  worked. Fixed in the module (`mkForce true` on explicit opt-in), eval
  assertion added, CHANGELOG'd.
- **M4 — guard hardening.** `contentCheckCount` derives exclusions by
  named constants; the `treefmt`/`format` dual attr root-caused
  (treefmt-nix hardcodes its check name; `flakeCheck = false` keeps one
  `format`), counts unchanged (20/21); `scripts/regen-golden.sh` refuses
  dirty trees and is idempotent (regen → empty diff); docs guard extended
  to dotted option mentions across living docs + examples.
- **M5 — CI infra.** Failure transcript artifact (tee + PIPESTATUS),
  Sunday cron gate + workflow_dispatch, `ubuntu-24.04` pin, lychee
  `GITHUB_TOKEN`, branch-protection checklist in CONTRIBUTING.
- **M6 — docs & DRY.** README recipes (`listenAddresses`, 2FA),
  pre-push/golden docs, stale AGENTS counts fixed (18/19→20/21),
  testScript ssh flags hoisted into `ssh_flags`/`ssh_batch` (7 copies→1),
  server example shows the full 2FA recipe.
- **M7 — security & process.** D2: SECURITY.md names GitHub private
  vulnerability reporting as primary channel. Strikethrough lint
  single-sourced to `scripts/check-strikethrough.sh` (found+fixed a
  pipefail/grep-no-match abort the CI inline version had masked).
  `release.sh` verifies compare links resolve (HTTP) and a new
  `release-script` CI job proves the "tag already exists" refusal —
  **green in CI run 33261586500**. RELEASE_NOTES template; D5 recorded.
- **M8 — ecosystem & upstream.** HM knownHosts request drafted with
  verification table (pinned HM source-read: option absent; no prior
  issue/PR found; do-NOT-file-without-re-verification note). Quarterly
  matrix re-verification procedure + ML-DSA watch checklist + log in
  ROADMAP theme 4. PerSourcePenalties deferred-window gotcha + the
  driver's reserved `log` variable gotcha in AGENTS.
- **M9 — design passes.** `docs/designs/`: HM-in-NixOS-VM (shape, cost,
  alternatives, kill-switch plan), host `match` blocks (type reuse,
  fixed render order, Match caveats), sops identity guide outline
  (decision tree for the two placements). Hermetic-dprint revisit note
  in theme 6.
- **M10 — polish & close-out.** `checks-summary` badge on README,
  devShell PATH exposes `scripts/` (verified via `nix develop -c`),
  auto-merge note expanded, plan archived as EXECUTED.

## b) Partially done

- Nothing from the plan's scope. Two items are deliberately _parked with
  reasons_ rather than partial: D5 (dotfiles repo is maintainer setup
  work outside this repo) and branch-protection UI settings (maintainer
  only; checklist written).

## c) Not started

- Filing the HM knownHosts issue (draft + verification table ready;
  re-verify against master the day of filing, by design).
- The quarterly matrix re-verification itself (procedure exists; next
  due 2026-12-01).
- HM-in-NixOS-VM implementation, match-blocks implementation, sops guide
  prose — designs now exist; implementation is intentionally not started.

## d) Fucked up (and how it was caught/fixed)

1. **`release.sh` execute mode was a no-op** — `run()` was never used, so
   "execute" printed commands without running them. Caught by reading the
   script before the real release (plan-2's "proven" dry-run only ever
   tested dry-run). Fixed; the new CI job now pins its guard behavior.
2. **Downstream push landed `bcf9271`'s broken disk work** — their CI
   failed `mirroredBoots` duplication. Root cause was pre-existing
   unpushed maintainer work, not the pin bump; fixed by committing the
   maintainer's own resolution and re-verifying their CI green.
3. **The v0.1.2 2FA recipe never worked** (upstream `unixAuth`
   coupling) — found by the plan's own positive-control test doing its
   job. Fixed in the module, kill-switch proven, eval assertion added.
   This is the release-relevant finding of the whole session.
4. Minor, caught by gates: the test-driver type-checker rejects a
   testScript variable named `log`; awk regex bracket-expression bug in
   the notes extractor; statix repeated-`nodes` keys; `pipefail` +
   `grep -o` aborting the lint on tilde-free files. All fixed and noted.

## e) Improvements made beyond the letter of the plan

- Release script extracts tag notes from the CHANGELOG section (no
  editor in automation) and creates the Release object itself — F5/F6
  collapse into one verified motion.
- The docs guard covers dotted mentions in ALL living docs, not just
  examples (still excludes CHANGELOG/archived per policy).
- `docs/upstream/` established as the verified-draft home (downstream
  repo already had the convention).
- Downstream `docs/upstream.md` + FEATURES updated to name v0.1.3 with
  the feature summary, not just a number bump.

## f) Next things (priority order)

1. Configure branch protection from the CONTRIBUTING checklist
   (maintainer UI): require `checks-summary`, up-to-date branches.
2. Re-verify + file the HM knownHosts request from
   `docs/upstream/home-manager-knownhosts-draft.md`.
3. Consider an upstream nixpkgs issue: sshd PAM `unixAuth` coupled to
   `PasswordAuthentication` breaks PAM-backed 2FA on keys-only hosts
   (our module now compensates; upstream consumers don't).
4. Release the PAM fix as v0.1.4 (it is a behavior fix consumers on
   v0.1.3 want) — flow: date CHANGELOG, dry-run, `release.sh`.
5. Downstream: bump to v0.1.4 after its tag (same explicit-paths
   discipline).
6. Implement HM-in-NixOS-VM per `docs/designs/hm-in-nixos-vm.md`.
7. Table-driven HM fixture host (decided; next host-level option lands).
8. Match-blocks feature per design (after HM-in-VM, to reuse its client).
9. sops identity guide prose per outline; validate in the downstream VM.
10. Watch the Sunday cron gate's first run (2026-08-30 04:17 UTC) for
    nixpkgs drift.
11. Dotfiles repo for `~/.config/crush/skills` (D5; maintainer setup).
12. Binary-cache strategy for CI (theme 6; magic-nix-cache deprecation
    signals pending).
13. Auto-merge + Dependabot groups after branch protection lands.
14. Confirm golden policy D3 stays byte-stable-manual after the next
    crypto change exercises `regen-golden.sh` for real.
15. Re-verify the pinned-HM `hmBlock` helper assumptions if HM changes
    its settings representation (AGENTS gotcha documents the coupling).
16. Address the `contentCheckCount` doc comment drift risk if the VM
    check ever moves off x86_64-linux (exclusion list is explicit).
17. Consider `nixosConfigurations`-style example host output for
    copy-paste consumers (theme 5; needs a design line).
18. Evaluate `AuthorizedPrincipalsFile` support surface (theme 5
    candidate, one option + tests).
19. Evaluate per-user authorized keys as first-class option (theme 5
    candidate; example already shows the pattern).
20. ML-DSA watch executes 2026-12-01 with the matrix procedure.
21. Track Home Manager's matchBlocks→settings deprecation window; our
    module uses settings natively, but eval fixtures pin behavior that
    may warn in future HM.
22. Upstream the `listenAddresses` freeform-vs-option discovery as an
    nixpkgs doc improvement candidate (the `atom` type surprise).
23. Measure VM test wall-clock after the third node (kbd-server) —
    budget CI minutes; if >6min, split suites.
24. Add `nix flake check --all-systems --no-build` to the pre-push hook
    review: it already runs; confirm hook content stays in sync with CI
    (they diverged once).
25. Downstream: their TODO_LIST references `infra/hcloud.tf` that does
    not exist yet — first-deployment blocked item, not ours to unblock.

## g) Three questions for the maintainer

1. **v0.1.4 timing:** the PAM `unixAuth` fix is a real behavior repair of
   a v0.1.3-advertised recipe — release now, or batch with the next
   feature (HM-in-VM)?
2. **The 2FA recipe broke at runtime for v0.1.2/v0.1.3 consumers.**
   Should the releases gain a warning note in their Release bodies
   (changelog-level disclosure), or is the CHANGELOG `[Unreleased]` row
   sufficient?
3. **Downstream's `bcf9271`/`45a050d` handling:** acceptable to commit
   maintainer WIP verbatim when it is the only path to a green main
   (with attribution), or prefer a revert + heads-up next time?

---

_Every claim above traces to a CI run, an exit code in hand, or a
transcript excerpt; the 14 session commits are
`1db7c86`(D1)·`86096ad`·`65ad426`(M1)·`81605d4`/`45a050d`(M2)·`c62fa63`(M3)·`78bafc1`(M4)·`ed4c329`(M5)·`3badba2`(M6)·`555bd8d`(M7)·`3a1d134`(M8)·`2eee977`(M9)._
