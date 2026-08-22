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

None. Everything from the 2026-08-22 execution plan
(`docs/planning/2026-08-22_04-49_pareto-execution-plan.md`) is done and
verified: real HM coverage, NixOS + HM content assertions (Nix attribute
equality), test hygiene, banner validation, upstream-verified OpenSSH matrix,
v0.1.0 tag, host forwarding options, `examples/`, the QEMU VM integration
test (which caught and fixed the global-keys StrictModes bug), CI link
checking, and the native aarch64-linux CI job. Long-term work lives in
`ROADMAP.md`.

## Resolved decisions

| Decision                                              | Verdict    | Rationale                                                                                                |
| ----------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------- |
| Create `docs/DOMAIN_LANGUAGE.md`? (session 7, g/3)    | **Decline** | Every domain term is defined exactly once in README's crypto rationale; a glossary would duplicate (single-home rule). |
| Canonical status-report format (session 7, g/4)       | **Markdown** | Maintainer has repeatedly chosen `.md` over richer formats; recorded in `CONTRIBUTING.md`.                |

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
