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
  actual key-based login with the throwaway keypair in `tests/`
- Formatting check via treefmt-nix (runs as part of `nix flake check`)

When adding assertions, prove once that they can fail (break the value
deliberately and watch the check go red) — a test that cannot fail is
decoration.

## Conventions

- Status reports and planning docs are plain Markdown in `docs/status/` and
  `docs/planning/` (no HTML reports).
- There is no `docs/DOMAIN_LANGUAGE.md`: domain terms are defined once, in
  the README's crypto rationale.
