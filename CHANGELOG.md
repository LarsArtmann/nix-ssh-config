# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- VM runtime proof for the headline claims: the integration test now asserts
  the client actually **negotiates** `mlkem768x25519-sha256` (`ssh -vv`
  transcript), that the installed OpenSSH supports every configured KEX,
  cipher and MAC (`ssh -Q` cross-check against the crypto lists), that an
  unauthorized key is rejected with the publickey-only method list, and that
  the legal banner is delivered to connecting clients — post-quantum KEX is
  a tested runtime fact, not a config claim
- Docs-drift guards: `docs-option-inventory` requires README's option tables
  to match the modules' real option inventories exactly (both directions),
  and `docs-check-count` requires FEATURES.md's per-system content-check
  counts to match the actual checks — the drift class behind "13 checks" and
  stale option tables now fails CI mechanically
- Client runtime proof: `hm-ssh-g-preview` runs `ssh -G` against the rendered
  `~/.ssh/config` and asserts the effective settings a real client would use
  (hostname, user, port plus the full AEAD cipher, ETM MAC and post-quantum
  KEX lists), and `hm-rendered-config` pins the generated file's section
  headers and crypto directive text
- VM golden snapshot: `tests/sshd-t-golden.txt` captures the effective
  `sshd -T` output of every directive the server module controls; the VM
  test fails with a precise key-by-key diff if runtime behavior drifts
- Option wins: server `listenAddresses` (bind specific `addr:port` pairs)
  and an explicit hardened `LoginGraceTime = 30` default (upstream: 120s
  plus random jitter since OpenSSH 9.9); client host `certificateFile`;
  the sntrup761 IANA alias (`sntrup761x25519-sha512`) is configured
  alongside the `@openssh.com` name; `examples/server.nix` now shows the
  evaluated per-user authorized-keys pattern
- Option batch 2: server `usePam` (null leaves the NixOS default true,
  false is a PAM-free host) and `authenticationMethods` (comma-chained
  two-factor auth) options; client per-host `controlMaster` and
  `updateHostKeys` overrides; explicit `MaxStartups = "10:30:60"` and
  `PerSourcePenalties = true` defaults (both overridable via
  `extraSettings`)
- flake.lock refreshed (nixpkgs 2026-08-26, home-manager 2026-08-27) with
  the full gate green on the new lock; a weekly PR-based update workflow
  and `scripts/release.sh` (dry-run capable) round off the release flow

### Changed

- The check suite moved out of `flake.nix` into `tests/checks.nix` (a
  flake-parts module). `flake.nix` shrinks to ~60 lines of inputs, outputs,
  formatting and the dev shell; adding a test no longer means spelunking a
  900-line file. All check names and counts are unchanged
- CI: a `checks-summary` job aggregates both architecture gates into a
  single required status; caching is explicitly best-effort (`continue-on-error`,
  FlakeHub opted out) so a cache outage slows a run instead of failing it
- CI automation: Dependabot keeps the pinned Actions SHAs current, and a
  weekly workflow opens a labeled `nix flake update` PR for manual review
- Docs hygiene is now self-enforcing: prettier joins nixfmt in treefmt
  (`nix fmt` formats Markdown/JSON/YAML; the CI `format` check verifies it),
  replacing the unused `dprint.json` whose WASM plugins cannot load in the
  sandboxed CI. `CHANGELOG.md` itself is excluded (append-only by policy).
  README gains CI/release badges, and a strikethrough-balance lint guards
  the report annotation grammar

## [0.1.2] — 2026-08-29

### Fixed

- **Keys-only now means keys-only.** The server module never set
  `KbdInteractiveAuthentication`, so the NixOS default (`yes`, with `UsePAM
  yes`) survived `passwordAuthentication = false` and PAM-serviced prompts
  stayed available over keyboard-interactive — on configurations whose sshd
  PAM service permits Unix passwords (and on any host adding PAM modules
  such as OTP/2FA), account passwords were still accepted (issue #1). New
  option `services.ssh-server.kbdInteractiveAuthentication` defaults to
  `passwordAuthentication` and is emitted into `services.openssh.settings`;
  set it to `true` explicitly for PAM-backed two-factor auth. Guarded by the
  new `nixos-kbd-interactive` eval check, extended
  `nixos-password-auth-disabled`/`nixos-custom-settings` assertions, and two
  new VM subtests (`sshd -T` plus an end-to-end assertion that the server
  offers publickey auth only); every new assertion was deliberately broken
  once to prove it fails

## [0.1.1] — 2026-08-22

The global-keys bugfix release. v0.1.0's `services.ssh-server.authorizedKeys`
never worked at runtime; if you rely on it, pin `v0.1.1` or later.

### Fixed

- **Global authorized keys now actually authorize.** The
  `/etc/ssh/authorized_keys` file was symlinked into `/nix/store`, and sshd's
  StrictModes silently rejects any AuthorizedKeysFile whose realpath crosses
  the world-writable store — every key-based login against a module-configured
  server failed while the keys looked present on disk. The file is now copied
  into `/etc` (`mode = "0444"`, the same mechanism upstream NixOS uses for
  `/etc/ssh/authorized_keys.d/*`). Found by the restored VM integration test
  on its first run

### Added

- QEMU integration test (`checks.x86_64-linux.nixos-vm-sshd`): boots a real
  VM, asserts the runtime `sshd -T` hardening, and performs an actual
  key-based login (restored from the pre-flake-parts suite, which had never
  tested login)
- Host convenience options: `proxyJump`, `forwardX11`, `localForwards`,
  `remoteForwards`, `dynamicForwards` — structured values handed to Home
  Manager's native renderer
- `examples.client` / `examples.server` flake outputs (copy-ready modules,
  exercised by a check on every system)
- Banner hardening: `bannerText` rejects control characters at evaluation
  time; the default banner moved to `modules/shared/banner.nix`
- Markdown link checking (lychee) and a native aarch64-linux CI job

### Changed

- Test assertions are Nix attribute equality (`assertEq`) instead of
  serialized-JSON grepping; every assertion family was deliberately broken
  once to prove it fails
- Test fixtures use a throwaway keypair (`tests/test-key{,.pub}`), never
  personal keys
- README's OpenSSH compatibility matrix verified against upstream release
  notes 6.5 → 10.0, with corrections (ML-KEM available by default since 9.9,
  sntrup761 disabled by default upstream) and documented nixpkgs pinning
  guidance

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

[Unreleased]: https://github.com/LarsArtmann/nix-ssh-config/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/LarsArtmann/nix-ssh-config/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/LarsArtmann/nix-ssh-config/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/LarsArtmann/nix-ssh-config/releases/tag/v0.1.0
