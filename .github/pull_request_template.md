# Pull request checklist

- [ ] Local gate green, run **bare and unpiped**, each command's exit code in hand:
  - `nix fmt -- --fail-on-change`
  - `statix check`
  - `nix flake check --all-systems --no-build`
  - `nix flake check` (native, includes the QEMU VM test)
- [ ] Every new test assertion was deliberately broken once and observed red
      (a test that cannot fail is decoration).
- [ ] Docs updated where behavior/default changed: README, FEATURES.md,
      CHANGELOG.md (`[Unreleased]`), AGENTS.md if a new gotcha emerged.
      The `docs-option-inventory` / `docs-check-count` checks pass, so
      option tables and check counts are in sync.
- [ ] Commit message explains why, understandable without the diff.
