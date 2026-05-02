# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Comprehensive test suite: 14 evaluation tests + NixOS VM integration test
- `apps.fmt-check` flake output for CI-friendly formatting checks
- `devShells.default` with nixfmt and nil (Nix LSP)
- `.envrc` for direnv auto-activation
- `.editorconfig` for cross-editor consistency
- `.github/workflows/check.yml` CI pipeline
- `CONTRIBUTING.md` with development setup and architecture overview
- Crypto algorithm rationale section in README
- OpenSSH version compatibility matrix in README
- Post-quantum status section in README
- `modules/shared/crypto.nix` — single source of truth for SSH crypto algorithms

### Changed

- Host `user` is now optional — inherits from `ssh-config.user` (defaults to `home.username`)
- `types.port` (0–65535) instead of `types.int` for port options
- `extraSettings` now validates types (str, int, bool only)
- Banner path uses `lib.mkDefault` for composability
- Dropped `x86_64-darwin` from supported systems (deprecated in Nixpkgs 26.05)
- Updated flake description to match repository

### Removed

- `MIGRATION_TO_NIX_FLAKES_PROPOSAL.md` — all decisions implemented or documented
