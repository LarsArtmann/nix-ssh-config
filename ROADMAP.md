# Roadmap

> Long-term direction and raw ideas. Items here are NOT actionable tasks.
> When an idea is refined into bounded work, it moves to `TODO_LIST.md`.

## Themes

### 1. Cross-platform reach

The server module today is NixOS-only. macOS machines are served by the client
module alone.

Raw ideas:

- `darwinModules` output configuring macOS sshd via nix-darwin (different module
  system than NixOS; effort concentrated in mapping the hardened settings to
  launchd-based sshd)
- Darwin CI coverage for the OrbStack/Colima include logic (needs a Darwin
  runner or a mock of `builtins.pathExists`)

### 2. Ecosystem integration

Raw ideas:

- age / sops-nix integration for private key distribution (requires a design
  decision on how keys reach machines)
- Flake overlay pinning a specific OpenSSH version alongside the crypto profile
- `nixos-generate-config` interplay study (avoid fighting imperative sshd config)

### 3. Test depth

Raw ideas:

- Multi-node NixOS test: this flake's client connecting to this flake's server,
  end-to-end (exercise the crypto profile against a real handshake)
- `sshd -T` exact-match runtime validation (was part of the removed VM test;
  restore alongside it)

### 4. Post-quantum completion

ML-KEM key exchange is deployed; authentication signatures remain classical.

Raw ideas:

- ML-DSA (FIPS 204) signature support the moment OpenSSH ships it — watch
  upstream; no implementation timeline exists today
- Re-evaluate the algorithm lists whenever OpenSSH deprecates entries (the
  single source of truth in `modules/shared/crypto.nix` makes this a one-file
  change)

## Non-goals

Things we are deliberately NOT pursuing and why:

- **Legacy-OpenSSH fallback KEX (e.g. `diffie-hellman-group14-sha256`):** the
  modern-only lists are the point; the README documents the OpenSSH >= 6.5
  requirement and `extraOptions`/`extraSettings` exist as escape hatches.
- **`x86_64-darwin` support:** deprecated in Nixpkgs 26.05; filtered out of
  `systems`.
- **Makefile / justfile task runners:** `flake.nix` is the single task runner in
  LarsArtmann projects.
- **Renaming the `ssh-config.*` option namespace to dotted Nix convention:** a
  breaking API change with no functional gain; deferred to a hypothetical v2.0
  if ever.

## Open questions

- None outstanding. The "keep or remove the `home-manager` flake input"
  question was settled: keep — it powers the Home Manager evaluation checks via
  `homeManagerConfiguration`, which has already caught real issues.
