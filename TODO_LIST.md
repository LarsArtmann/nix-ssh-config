# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> For long-term vision and unrefined ideas, use `ROADMAP.md`.
> Items are ranked by impact. Status is verified, not assumed.
> Sources: harvested from `docs/status/` session reports (2026-04-04 … 2026-05-02), re-verified against code and extended with session 7 findings on 2026-08-22 (`docs/status/2026-08-22_04-45_docs-health-audit-and-ci-fix.md`).

## Status legend

| Status           | Meaning                                                     |
| ---------------- | ----------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                                   |
| 🟡 `IN_PROGRESS` | Actively being worked on.                                   |
| 🔵 `BLOCKED`     | Cannot proceed, external dependency or decision needed.     |
| 🟢 `DONE`        | Completed. Remove from this list and log in `CHANGELOG.md`. |

## High Impact

| Task                                                                                                                 | Status       | Impact | Effort | Evidence                                                                                                    |
| -------------------------------------------------------------------------------------------------------------------- | ------------ | ------ | ------ | ----------------------------------------------------------------------------------------------------------- |
| Fix HM eval check to force `programs.ssh.settings` (currently deepSeq's `matchBlocks`, vacuous since the settings migration) | 🔴 `TODO`    | High   | 10min  | `flake.nix:116` forces `matchBlocks` (empty); real config lives in `settings`                               |
| Restore content assertions cut in the flake-parts migration (custom port, authorizedKeys, banner, crypto lists, `extraSettings` merge, HM host-block content) | 🔴 `TODO` | High   | 2h     | `flake.nix:109-131` keeps only 2 content checks (password auth, root login); 10 of the 14 pre-migration eval tests were dropped at `e910e78`    |
| Tag v0.1.0 release                                                                                                   | 🔴 `TODO`    | High   | 2min   | `git tag -l` is empty; requested in all six session reports                                                 |
| Push the staged CI fix and verify a green `Check` run on GitHub (workflow previously failed on every run: platform mismatch building foreign-system checks) | 🔴 `TODO` | High   | 5min   | `gh run list`: all 9 runs failed; fix verified locally in `check.yml` (`--no-build` eval + native build)     |

## Medium Impact

| Task                                                                                                           | Status    | Impact | Effort | Evidence                                                        |
| -------------------------------------------------------------------------------------------------------------- | --------- | ------ | ------ | --------------------------------------------------------------- |
| Replace hardcoded real test key with a throwaway key (or `self.sshKeys`) in test evals                          | 🔴 `TODO` | Med    | 10min  | `flake.nix:51` embeds a personal key                             |
| Replace JSON-grep `assertContains` with Nix-level comparisons (`nix eval` / attribute equality)                 | 🔴 `TODO` | Med    | 30min  | `flake.nix:95-104` greps raw JSON strings                        |
| Restore NixOS VM integration test (QEMU, `testers.nixosTest`, x86_64-linux only)                                | 🔴 `TODO` | Med    | 2h     | Removed at `e910e78`; previously validated sshd at runtime       |
| Add host submodule convenience options: `proxyJump`, `forwardX11`, `localForwards`, `dynamicForwards`, `remoteForwards` | 🔴 `TODO` | Med    | 30min  | `modules/home-manager/ssh.nix:25-66` has none of them           |
| Validate `bannerText` rejects control characters (or convert to `submodule` with content + enable)              | 🔴 `TODO` | Med    | 15min  | `modules/nixos/ssh.nix:58-77` accepts any string                 |
| Verify OpenSSH compatibility matrix against upstream release notes (pre-tag)                                      | 🔴 `TODO` | Med    | 30min  | `README.md:198-204` — inherited claim, never verified against upstream |
| Decide nixpkgs pinning strategy for downstream consumers (rolling unstable vs release)                            | 🔴 `TODO` | Med    | 15min  | `flake.nix:5` pins `nixos-unstable`; consumers inherit via follows |

## Low Impact

| Task                                                             | Status    | Impact | Effort | Evidence                                       |
| ---------------------------------------------------------------- | --------- | ------ | ------ | ---------------------------------------------- |
| Add `examples/` directory with ready-to-use client+server configs | 🔴 `TODO` | Low    | 30min  | No `examples/` dir; requested since session 1  |
| Extract default banner text to a shared constant or file          | 🔴 `TODO` | Low    | 10min  | 15-line inline default at `modules/nixos/ssh.nix:60-75` |
| Remove unused `pkgs` binding in NixOS module                        | 🔴 `TODO` | Low    | 1min   | `modules/nixos/ssh.nix:4` — nil_ls warning in every session |
| Render-check annotated archived reports in a Markdown viewer        | 🔴 `TODO` | Low    | 10min  | `docs/status/archived/` — strikethrough tables verified structurally, never visually |
| Add markdown link-checker step to CI                                | 🔴 `TODO` | Low    | 20min  | `.github/workflows/check.yml` — doc links currently unchecked |
| Add aarch64-linux native CI job                                      | 🔴 `TODO` | Low    | 30min  | CI builds only x86_64-linux natively; needs free arm64 runners |

## Blocked / Decisions

| Task                                                                                      | Status       | Impact | Effort | Evidence                                               |
| ------------------------------------------------------------------------------------------ | ------------ | ------ | ------ | ------------------------------------------------------ |
| Confirm or decline `docs/DOMAIN_LANGUAGE.md` (recommendation: decline — terms live once in README) | 🔵 `BLOCKED` | Low  | 5min   | Session 7 report, question g/3 — awaiting maintainer    |
| Decide canonical status-report format for this repo (recommendation: `.md`)                | 🔵 `BLOCKED` | Low    | 5min   | Skill default is HTML; user has twice requested `.md`  |

---

<!-- Guidance:
  - Source of truth is the CODE. Verify each item before adding, many
    documented TODOs are already done.
  - One task per row. If it takes more than ~2 hours, split it into smaller
    tasks.
  - Cite evidence (file:line) so the next person can verify without re-deriving.
  - DONE items should be REMOVED, not kept. Use CHANGELOG.md for history.
  - If a task is vague ("improve X"), refine it into concrete steps or move it
    to ROADMAP.md.
-->
