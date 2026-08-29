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

### Release & remote actions

| Status | Item                                                                                                                                                                                                                                                                                                                        | Evidence                                                                            |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 🔵     | **Ship v0.1.2 + close out issue #1.** Date the `CHANGELOG.md` `[Unreleased]` section, create the annotated tag, push tag + master, verify CI on both jobs, create GitHub *Release objects* (none exist — also for v0.1.0/v0.1.1), then comment on and close issue #1. Blocked on maintainer authorization for remote actions. | `CHANGELOG.md` `[Unreleased]`; `gh release list` empty (2026-08-29); issue #1 open  |

### Test depth

| Status | Item                                                                                                                                 | Evidence                                                        |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| 🔴     | VM: a **wrong key** is rejected (negative auth path)                                                                                 | `flake.nix` `nixos-vm-sshd`; only the offered-methods path is asserted today |
| 🔴     | VM: the banner is **actually delivered** to a connecting client (assert pre-auth banner text client-side)                            | `flake.nix:703-705` asserts server-side files only              |
| 🔴     | VM: negotiated KEX asserted as `mlkem768x25519-sha256` via `ssh -vv`, plus `ssh -Q` cross-check of our lists vs runtime sshd support | `flake.nix:712-714` greps `sshd -T` output only                 |
| 🔴     | Client runtime proof: `ssh -G` against a rendered Home Manager config (the server has runtime proof, the client none)                 | —                                                               |
| 🔴     | Docs-drift guard: every option in README's server/client tables must exist in the modules, and documented check counts must match `builtins.attrNames checks` (CI step or eval check)               | `README.md` options tables vs `modules/`; `FEATURES.md`/`AGENTS.md` counts |
| 🟡     | VM: `sshd -T` golden-snapshot comparison (full effective config) instead of per-directive greps                                      | `flake.nix:676-722`                                             |

### Refactoring

| Status | Item                                                                                                                         | Evidence                                     |
| ------ | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 🔴     | Deduplicate the two `deepSeq` eval checks (`home-manager-module-evaluates`, `nixos-module-evaluates`) into the content checks | `nix eval` check list; strictly weaker subsets |
| 🔴     | Extract the test suite from `flake.nix` into `tests/checks.nix` (flake.nix has grown to ~740 lines)                          | `flake.nix`                                  |

### Decisions (blocked on maintainer)

| Status | Item                                                                                                                                                                  | Evidence                                                                                     |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| 🔵     | **dprint policy**: wire `dprint.json` into treefmt so `nix fmt`/CI enforce markdown (it reformats archived reports too), or drop the config. Configured-but-unenforced since 2026-08-22 | `dprint.json`; `flake.nix:249` enables nixfmt only                                            |

### Low priority

| Status | Item                                                                                                                         | Evidence                                        |
| ------ | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| 🔴     | Repo meta files: `.github/CODEOWNERS`, issue/PR templates                                                                     | —                                               |
| 🔴     | CI automation: Dependabot/Renovate for the pinned Actions SHAs; weekly `flake.lock` update bot; combined checks-summary job (2 CI jobs → 1 status)                                  | `.github/workflows/check.yml` (pinned in `6d4f378`) |
| 🔴     | CI cache robustness: fallback for magic-nix-cache (deprecation signals); investigate `cache.home.lan` 502 flapping            | CI workflow; session logs 2026-08-29            |
| 🔴     | README badges (CI status + latest release)                                                                                    | `README.md`                                     |
| 🔴     | Per-user keys example (`users.users.<name>.openssh.authorizedKeys.keys`) alongside the global file                            | `examples/`                                     |
| 🔴     | Pre-push gate hook (devShell/pre-commit running the pre-flight command from `AGENTS.md`)                                      | `AGENTS.md` Commands                            |
| 🔴     | Property tests: every `types.port` option rejects 65536 and −1 (eval-failure tests)                                           | `modules/*.nix` port options                    |
| 🔴     | Assert the HM-rendered `~/.ssh/config` **text** in an eval check (current checks assert the settings attrset, not the rendered file) | `flake.nix` `hmBlock` helper               |
| 🔴     | Session-report lint: strikethrough-balance check as part of the CI link-check step                                            | `.github/workflows/check.yml` (lychee step)     |

## Resolved decisions

| Decision                                           | Verdict      | Rationale                                                                                                              |
| -------------------------------------------------- | ------------ | ---------------------------------------------------------------------------------------------------------------------- |
| Create `docs/DOMAIN_LANGUAGE.md`? (session 7, g/3) | **Decline**  | Every domain term is defined exactly once in README's crypto rationale; a glossary would duplicate (single-home rule). |
| Canonical status-report format (session 7, g/4)    | **Markdown** | Maintainer has repeatedly chosen `.md` over richer formats; recorded in `CONTRIBUTING.md`.                             |

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
