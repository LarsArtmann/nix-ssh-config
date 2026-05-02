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
2. Run checks: `nix flake check --all-systems`
3. Format: `nix fmt`
4. Submit a PR

## Checks

All PRs must pass:

- `nix flake check --all-systems` — module evaluation + VM integration test
- `nix fmt -- --fail-on-change` — formatting

## Architecture

- `modules/shared/crypto.nix` — single source of truth for all crypto algorithms
- `modules/home-manager/ssh.nix` — client (Home Manager)
- `modules/nixos/ssh.nix` — server (NixOS)
- Crypto algorithms are defined as Nix lists with `*String` variants for comma-separated contexts

## Testing

The test suite includes:

- Module evaluation tests (all architectures)
- NixOS VM integration test (boots QEMU, validates sshd config)
- Home Manager config content verification
- Security defaults assertions (no password auth, no root login, etc.)
