# Contributing

## Development Setup

```bash
nix develop
```

Or with [direnv](https://direnv.net/):

```bash
echo "use flake" > .envrc && direnv allow
```

## Making Changes

1. Edit modules in `modules/`
2. Evaluate all systems: `nix flake check --all-systems --no-build`
3. Build + run the native checks: `nix flake check`
4. Format: `nix fmt`
5. Submit a PR

## Gate discipline

- **Never pipe a gate.** `nix flake check … | tail -1` reports the pipe's exit
  code, not nix's — a crashing eval looks green. Run the bare command (or
  `cmd && echo OK`).
- **Claims follow exit codes.** Write "green" (in docs, reports, chat) only
  after the gate's exit code is in hand — never while it is still running.
- **After changing behavior or documented defaults**, grep the docs (README,
  FEATURES, AGENTS, `examples/`) for the old claim before declaring done.

## Checks

All PRs must pass (mirrored by CI):

- `nix flake check --all-systems --no-build` — module evaluation on all supported systems
- `nix flake check` — builds and runs the current system's checks
- `nix fmt -- --fail-on-change` — formatting

Note: `nix flake check --all-systems` without `--no-build` tries to build
foreign-system check derivations and fails with a platform mismatch on any
single-machine runner.

## Architecture

- `modules/shared/crypto.nix` — single source of truth for all crypto algorithms
- `modules/home-manager/ssh.nix` — client (Home Manager)
- `modules/nixos/ssh.nix` — server (NixOS)
- Crypto algorithms are defined as Nix lists with `*String` variants for comma-separated contexts

## Testing

The test suite includes:

- Module evaluation checks (NixOS + Home Manager, all supported systems)
- Content assertions on both modules via Nix attribute equality (`assertEq` in
  `flake.nix`): crypto lists and forms, host blocks, user inheritance,
  banner, authorized keys, port passthrough, `extraSettings` overrides,
  disabled-state no-op, module assertions, examples
- A QEMU integration test on x86_64-linux (`checks.x86_64-linux.nixos-vm-sshd`):
  boots a real VM, asserts the runtime `sshd -T` config, and performs an
  actual key-based login with the throwaway keypair in `tests/`. Runtime
  budget: roughly a minute per boot, three boots per run — a full
  `nix flake check` including the VM test is a several-minute gate; build
  with `nix build -L` (or read the driver transcript from the store) when a
  green run's per-subtest log lines need to be inspectable.
- Docs-drift guards (`docs-option-inventory`, `docs-check-count`): README's
  option tables must match the modules' real option inventories exactly, and
  FEATURES.md's content-check counts must match the actual number of checks.
  Adding or removing a check, or renaming an option, turns these red until
  README/FEATURES are updated — that is the point.
- Formatting check via treefmt-nix (runs as part of `nix flake check`)

When adding assertions, prove once that they can fail (break the value
deliberately and watch the check go red) — a test that cannot fail is
decoration.

## Conventions

- Status reports and planning docs are plain Markdown in `docs/status/` and
  `docs/planning/` (no HTML reports). Fully resolved reports are annotated
  inline (strikethrough + evidence) and `git mv`'d into `docs/status/archived/`.
- There is no `docs/DOMAIN_LANGUAGE.md`: domain terms are defined once, in
  the README's crypto rationale.

## Releases

1. Verify the full local gate (see Checks) — a release gate must include the
   runtime VM test, not just evaluation (v0.1.0 shipped on eval-green alone
   and its headline feature was runtime-broken within the hour).
2. Date the `CHANGELOG.md` `[Unreleased]` section.
3. Create an annotated tag and push it together with `master`.
4. Create the GitHub *Release object* (`gh release create`) — tags alone do
   not produce one, and compare links in the CHANGELOG 404 until pushed.
5. Watch CI on GitHub (both jobs) after the push.
