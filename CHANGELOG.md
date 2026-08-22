# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-08-22

First tagged release. Everything below is the net difference between the
initial commit and this tag.

### Added

- Home Manager SSH client module (`homeManagerModules.ssh`): hardened global
  defaults, per-host blocks with user inheritance, GitHub.com preset,
  OrbStack/Colima includes on Darwin, `~/.ssh/sockets` activation script
- NixOS SSH server module (`nixosModules.ssh`): hardened sshd defaults, global
  authorized keys, legal banner, user allow-list, `extraSettings` escape hatch
- `modules/shared/crypto.nix` — single source of truth for all SSH crypto
  algorithms (Nix lists plus comma-joined `*String` variants), imported by both
  modules
- `modules/shared/banner.nix` — the default legal banner as an importable
  constant (byte-identical to the original inline default)
- Banner validation: `services.ssh-server.bannerText` rejects control
  characters (anything outside printable ASCII, newline and tab) at evaluation
  time, because they can corrupt the sshd banner channel
- `sshKeys` flake output exposing tracked public keys (`lars`, `lars-evo-x2`)
- Content test suite (`nix flake check`), all Nix attribute-equality based
  (`assertEq`, no serialized-JSON grepping):
  - client: real `programs.ssh.settings` forcing, `*` global defaults,
    `github.com` preset, host blocks, user inheritance, per-host
    port/identityFile/keepalives, `extraOptions` merging
  - server: crypto lists and string forms (guards the list-vs-string settings
    quirk), authorized keys file, banner path and text, custom port,
    `extraSettings` override, disabled-state no-op, module assertion suite
  - every assertion family was kill-switch tested (deliberately broken once
    to prove it fails)
- Formatting via treefmt-nix/nixfmt (`nix fmt`), enforced as a `checks.*.format`
  derivation and in CI
- `devShells.default` with the `nil` Nix language server
- CI pipeline (`.github/workflows/check.yml`)
- Documentation: `CONTRIBUTING.md`, `CHANGELOG.md`, `AGENTS.md`, `TODO_LIST.md`,
  `ROADMAP.md`, `FEATURES.md`; README crypto rationale, OpenSSH compatibility
  matrix (verified against upstream release notes 6.5 → 10.0), post-quantum
  status, and nixpkgs pinning guidance
- `.envrc` (direnv) and `.editorconfig`
- flake-parts based flake architecture with `nix-systems` system list

### Changed

- Host `user` is optional — inherits from `ssh-config.user`, which defaults to
  `config.home.username` (was hardcoded to a personal username)
- `types.port` (0–65535) instead of `types.int` for port options
- `extraSettings` now validates types (str, int, bool only)
- Banner path uses `lib.mkDefault` for composability
- Home Manager client migrated from deprecated `matchBlocks` to
  `programs.ssh.settings` with upstream PascalCase directive names
- Dropped `x86_64-darwin` from supported systems (deprecated in Nixpkgs 26.05);
  supported: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux`

### Fixed

- CI `Check` workflow: `nix flake check --all-systems` attempted to build
  foreign-system check derivations (e.g. `aarch64-darwin` on an x86_64-linux
  runner), failing every run since inception with "platform mismatch". The
  workflow now evaluates all systems with `--no-build` and builds only the
  native-system checks. Verified green on GitHub — the first passing runs in
  the repository's history
- Home Manager eval check forced `matchBlocks`, which has been empty since the
  settings migration — the client module had zero effective coverage while
  appearing green
- Test evals embedded a personal public key; replaced with a throwaway
  ed25519 key that exists only for CI

### Removed

- `MIGRATION_TO_NIX_FLAKES_PROPOSAL.md` — all decisions implemented or
  documented elsewhere

[Unreleased]: https://github.com/LarsArtmann/nix-ssh-config/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/LarsArtmann/nix-ssh-config/releases/tag/v0.1.0
