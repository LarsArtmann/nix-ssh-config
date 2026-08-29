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
- Retire downstream workarounds once a tagged release ships them: after v0.1.2,
  drop `nix-international-telephony`'s now-redundant
  `extraSettings.KbdInteractiveAuthentication = false` workaround and its
  duplicated docs claims

### 3. Test depth

Raw ideas:

- Multi-node NixOS test: this flake's client connecting to this flake's server,
  end-to-end (exercise the crypto profile against a real handshake)
- `sshd -T` exact-match runtime validation (was part of the removed VM test;
  restore alongside it)
- Positive prompt-path test: deliberately enable a PAM prompt module (or
  `unixAuth`) and prove `KbdInteractiveAuthentication no` blocks a real
  prompted-then-rejected exchange end-to-end (needs `sshpass`/expect; design
  first — the current method-list assertion is the interim guard)
- Table-driven fixture host in the HM eval (loop hosts × options instead of
  one "full" host)

### 4. Post-quantum completion

ML-KEM key exchange is deployed; authentication signatures remain classical.

Raw ideas:

- ML-DSA (FIPS 204) signature support the moment OpenSSH ships it — watch
  upstream; no implementation timeline exists today
- Quarterly re-verification cadence for the README OpenSSH compatibility
  matrix against upstream release notes (watch the OpenSSH release feed)
- Re-evaluate the algorithm lists whenever OpenSSH deprecates entries (the
  single source of truth in `modules/shared/crypto.nix` makes this a one-file
  change)

### 5. Module surface candidates

Raw ideas for options/features, most needing only a design pass before they
become bounded TODO_LIST rows:

- `UsePAM` passthrough option (`null`/`bool`; nixpkgs supports `null` since
  2025-12) for OpenSSH builds without PAM
- `AuthenticationMethods` option for real chained 2FA
  (`publickey,keyboard-interactive`) — natural companion to the
  `kbdInteractiveAuthentication` option
- `services.ssh-server.listenAddresses`
- Host `match` blocks (`ssh-config.hosts.*.match`)
- Host `certificateFile` (host certificates)
- `knownHosts` passthrough (`programs.ssh.knownHosts`)
- Client keepalive/`ControlMaster`/`UpdateHostKeys` as options instead of
  hardcoded values
- `PerSourcePenalties` / `MaxStartups` hardened defaults decisions
- ~~`LoginGraceTime` explicit default + doc (upstream 120s + jitter since 9.9)~~ done in v0.1.3 work (2026-08-29): module pins 30s; documented in README
- `sntrup761x25519-sha512` IANA alias alongside the `@openssh.com` name
  (OpenSSH 9.9+)

### 6. CI & infrastructure

Raw ideas:

- Binary-cache strategy for CI (attic / GitHub Actions cache) so VM-test
  rebuilds stop costing minutes cold; magic-nix-cache has deprecation signals
  and the self-hosted cache flaps (502s observed 2026-08-29)
- Automated release gate: tag → build → VM test → changelog compare-links
  valid → `gh release create`, one flow
- `nix flake update` cadence decision (inputs move on nixos-unstable)

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

Settled: the "keep or remove the `home-manager` flake input" question was
resolved — keep, it powers the Home Manager evaluation checks via
`homeManagerConfiguration` and has already caught real issues.

Still open (maintainer calls, no code change implied):

- **v0.1.0 disposition**: its headline feature (`authorizedKeys`) never worked
  at runtime. Recommendation: leave it (CHANGELOG already warns; compare links
  are intact; deleting rewrites history for anyone who pinned).
- **`sshKeys` output future**: personal public keys as a public flake output —
  keep, or move to the private consumer config?
- **SECURITY.md**: single-home the threat model (README owns it today) —
  create `SECURITY.md` or keep the README section canonical?
- **ARCHITECTURE placement**: keep the architecture section inside
  `AGENTS.md` (recommended) or promote it to its own file?
