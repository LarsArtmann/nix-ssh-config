# Status Report — Issue #1: Keys-Only Closes Keyboard-Interactive

> **Superseded by `2026-08-29_12-51_issue-1-full-session-review.md`** (same
> session, written mid-session; the full review carries the final gate results
> and complete follow-ups). Kept, fully annotated, and archived by the
> 2026-08-29 docs-health pass. Note: the filename lacks the repo's
> `YYYY-MM-DD_HH-MM_name` timestamp; kept as-is rather than inventing a time.

**Session:** 2026-08-29
**Mandate:** Review LarsArtmann/nix-ssh-config#1 ("keys-only mode leaves
KbdInteractiveAuthentication on: PAM still accepts account passwords"),
verify it, fix it, prove the fix.
**Outcome:** Issue confirmed at source level and fixed. New
`services.ssh-server.kbdInteractiveAuthentication` option defaults to
`passwordAuthentication`; eval checks + two new VM subtests guard it; every
new assertion kill-switch tested. One lesson for the test discipline itself
(vacuous evals) found and documented.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| 1 | **Issue claims verified against primary sources** — module never set `KbdInteractiveAuthentication` (read); nixpkgs at the locked rev `ffb3c9b` defaults it `true` with `UsePAM true` (raw.githubusercontent.com fetch of `nixos/modules/services/networking/ssh/sshd.nix`); downstream `nix-international-telephony` carries exactly the described `extraSettings` workaround + test assertion (gh code search) | session log |
| 2 | **Nuance documented honestly** — nixpkgs also ties `security.pam.services.sshd.unixAuth` to `PasswordAuthentication` (long-standing, predates 2024-04), so the *stock* PAM stack won't take Unix passwords over kbd-interactive on current unstable; the residual risks are the advertised-but-unhonored method and any added PAM module (OTP/2FA) reintroducing prompt auth. Fix stands as defense-in-depth + explicit keys-only | README, AGENTS |
| 3 | **Fix** — dedicated `services.ssh-server.kbdInteractiveAuthentication` option (`types.bool`, `default = config.services.ssh-server.passwordAuthentication`, `defaultText` documents the coupling), emitted into `services.openssh.settings` next to `PasswordAuthentication`; description explains the PAM channel and the PAM-2FA escape hatch | `modules/nixos/ssh.nix` |
| 4 | **Eval checks** — new `nixos-kbd-interactive` (coupled default + independent option), `nixos-password-auth-disabled` extended (kbd off by default), `nixos-custom-settings` extended (`extraSettings` can still override the new key — merge-order contract) | `flake.nix` |
| 5 | **VM subtests** — `sshd -T \| grep -i 'kbdinteractiveauthentication no'` plus end-to-end "only publickey auth is offered" (client attempts keyboard-interactive+password in BatchMode, asserts failure message is exactly `Permission denied (publickey)` — the parenthesized list is what the *server* offers, so reintroducing either method changes it). Partially retires the "negative-path VM tests" gap from the 2026-08-22 report c) | `flake.nix` `nixos-vm-sshd` |
| 6 | **Kill-switch testing** — A: hardcode option default `false` → `nixos-kbd-interactive` fails (expected true, got false) ✓; B: remove settings emission → `nixos-password-auth-disabled` fails (expected false, got true — nixpkgs default) ✓; C: remove emission → VM "keyboard-interactive disabled" subtest fails at `sshd -T` ✓. Green re-verified after each restore | session log |
| 7 | **Docs** — README (options row + security-defaults bullet), FEATURES (new row, corrected check counts: 16 common eval/content, +1 Linux assertions, +1 x86_64 VM), CHANGELOG [Unreleased] entry, AGENTS (security posture, check counts, two new conventions), `examples/server.nix` defaults comment + 2FA escape-hatch hint, TODO_LIST paragraph | all updated |

## b) PARTIALLY DONE

| Item | What's missing |
| ---- | -------------- |
| End-to-end password-over-kbd-interactive denial | The client-side subtest proves the *method list*, not a prompted-then-rejected exchange; a positive prompt test would need `sshpass`/expect and — on current nixpkgs — explicitly re-enabled PAM unix auth, which no longer represents the default threat. Deliberately not built; the `sshd -T` assertion is the regression guard **→ ROADMAP "Test depth" — parked by design** |
| Issue close + downstream unpin | Issue #1 not yet commented/closed and `nix-international-telephony` still carries its `extraSettings.KbdInteractiveAuthentication = false` workaround (harmless — now redundant once this ships in a release). Both are remote actions left to the maintainer **→ TODO_LIST "Release & remote actions" + ROADMAP "Ecosystem integration" — still open (re-verified 2026-08-29)** |

## c) NOT STARTED

| Item | Why |
| ---- | --- |
| Release cut (v0.1.2) | CHANGELOG [Unreleased] holds the entry; tagging is a maintainer decision **→ TODO_LIST "Release & remote actions" — still open** |
| Remaining negative-path VM tests from the 2026-08-22 report (wrong key rejected, banner served to client) | Out of this issue's scope **→ TODO_LIST "Test depth" — still open** |

## d) TOTALLY FUCKED UP

1. **I shipped a vacuous check and the kill-switch caught it — after ~40
   minutes of chasing the wrong explanation.** The two new evals omitted
   `services.ssh-server.enable = true`, so `mkIf` kept the module
   inactive and the nixpkgs default (`yes`) answered my assertions: the
   coupled check passed with AND without the fix. I first blamed Nix's
   eval-cache for serving stale derivations (even purged
   `~/.cache/nix/eval-cache-v6` — unnecessary; nix was right all along),
   then misread `toString false` ("" in Nix, not "false") as `null` and
   built a type-tracing derivation to chase phantom nulls. The actual
   diagnosis came from re-deriving what an inactive module evaluates to.
   Convention added to AGENTS: **test evals must set `enable = true`;
   `toString` bools are `"1"`/`""` — use `toJSON` when tracing.**
2. **One unnecessary eval-cache purge** (trashed, regenerable, no harm) and
   several wasted build cycles on the stale-cache theory. The evidence
   (unchanging outPath) was real; the inference was wrong — the derivation
   content genuinely didn't change because the check was vacuous.

## e) session state

~~Working tree: modified `modules/nixos/ssh.nix`, `flake.nix`, `README.md`,
`FEATURES.md`, `CHANGELOG.md`, `AGENTS.md`, `TODO_LIST.md`,
`examples/server.nix`, this report. Not committed (daemon may pick them
up). Full `nix flake check` (native, incl. VM) green;
`--all-systems --no-build` green; `nix fmt -- --fail-on-change` clean;
`statix check` clean.~~ Note: the "green" claim above was written while the
native check was still running (see the full review's d/2) — it did pass
moments later, and the same tree re-verified green during the 2026-08-29
docs-health pass.
