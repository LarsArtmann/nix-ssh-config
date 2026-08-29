# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> For long-term vision and unrefined ideas, use `ROADMAP.md`.

## Status legend

| Status           | Meaning                                                     |
| ---------------- | ----------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                                   |
| 🟡 `IN_PROGRESS` | Actively being worked on.                                   |
| 🔵 `BLOCKED`     | Cannot proceed, external dependency or decision needed.     |
| 🟢 `DONE`        | Completed. Remove from this list and log in `CHANGELOG.md`. |

## Open items

### Test depth

| Status | Item                                                                                                                                                            | Evidence                                                  |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| 🔴     | Table-driven fixture host in the HM eval (decided yes 2026-08-29): loop hosts × options instead of one "full" host. Adopt when the next host-level option lands | `tests/checks.nix` `hmEval` fixture                       |
| 🔴     | HM client module inside the NixOS VM (HM-in-NixOS evaluation) so the module — not just a plain ssh client — gets runtime proof. Needs a design pass first       | `tests/checks.nix` VM nodes; ROADMAP theme 3 "multi-node" |

Executed 2026-08-29 (plan 3, M3): property tests (`nixos-port-bounds`,
`hm-port-bounds` via `builtins.tryEval`) and the prompt-path VM positive
control — the control immediately caught the PAM `unixAuth` coupling bug
(keys-only + explicit kbd-interactive was `pam_deny`-denied end-to-end),
fixed in the module and re-proven; see CHANGELOG.

## Resolved decisions

| Decision                                               | Verdict                            | Rationale                                                                                                                                                                                                                    |
| ------------------------------------------------------ | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Create `docs/DOMAIN_LANGUAGE.md`? (session 7, g/3)     | **Decline**                        | Every domain term is defined exactly once in README's crypto rationale; a glossary would duplicate (single-home rule).                                                                                                       |
| Canonical status-report format (session 7, g/4)        | **Markdown**                       | Maintainer has repeatedly chosen `.md` over richer formats; recorded in `CONTRIBUTING.md`.                                                                                                                                   |
| dprint policy (D1, plan 2)                             | **Wire formatting (via prettier)** | dprint's WASM plugins need network in the sandboxed CI format check, so prettier joined nixfmt in treefmt instead and `dprint.json` was removed; CHANGELOG excluded (append-only).                                           |
| v0.1.0 disposition (D2, plan 2)                        | **Leave it**                       | CHANGELOG already warns the headline feature was runtime-broken; rewriting/deleting tags breaks anyone who pinned; compare links intact.                                                                                     |
| `sshKeys` public output future (D3, plan 2)            | **Keep**                           | Public keys are public; the output is load-bearing in README's quick-start and consumed downstream.                                                                                                                          |
| SECURITY.md (D4, plan 2)                               | **Pointer file**                   | README stays the canonical threat model; `SECURITY.md` is a short pointer with disclosure policy (created 2026-08-29).                                                                                                       |
| ARCHITECTURE placement (D5, plan 2)                    | **Stay in AGENTS.md**              | One consumer (AI sessions + maintainer); a separate file is ceremony at this size.                                                                                                                                           |
| Track `~/.config/crush/skills` in a repo? (D5, plan 3) | **Yes, dotfiles repo — parked**    | The docs-health annotate tooling fix (plan 2 F78) lives only in the home dir; silent tooling drift is real. Creating the dotfiles repo is maintainer setup work outside this repo's scope — recorded so it is not forgotten. |

## Executed 2026-08-29 (plan 2 — removed rows, see CHANGELOG)

v0.1.2 release + issue #1 close-out · VM runtime depth (negotiated KEX,
`ssh -Q`, wrong-key, banner) · docs-drift guards · `tests/checks.nix`
extraction · CI automation (summary job, Dependabot, weekly lock PR,
cache-fallback policy) · client `ssh -G`/rendered-config proof · sshd -T
golden snapshot · smoke-check dedupe · docs hygiene (prettier, badges,
strikethrough lint, annotation convention) · repo meta (CODEOWNERS,
templates, pre-push hook) · option batches 1+2 (`listenAddresses`,
`LoginGraceTime=30`, host `certificateFile`, sntrup IANA alias, `usePam`,
`authenticationMethods`, `MaxStartups`/`PerSourcePenalties`, host
`controlMaster`/`updateHostKeys`) · downstream workaround retired and
pinned to v0.1.2 · flake.lock refresh · release script + update cadence.
Decision D1–D5 recorded above; F57 (`knownHosts` passthrough) parked —
the pinned Home Manager has no `programs.ssh.knownHosts` to pass through
to (ROADMAP theme 5).

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
