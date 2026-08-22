# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> For long-term vision and unrefined ideas, use `ROADMAP.md`.
> Items are ranked by impact. Status is verified, not assumed.
> Sources: harvested from `docs/status/` session reports (2026-04-04 … 2026-05-02) and re-verified against code on 2026-08-22.

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

## Low Impact

| Task                                                             | Status    | Impact | Effort | Evidence                                       |
| ---------------------------------------------------------------- | --------- | ------ | ------ | ---------------------------------------------- |
| Add `examples/` directory with ready-to-use client+server configs | 🔴 `TODO` | Low    | 30min  | No `examples/` dir; requested since session 1  |
| Extract default banner text to a shared constant or file          | 🔴 `TODO` | Low    | 10min  | 15-line inline default at `modules/nixos/ssh.nix:60-75` |

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
