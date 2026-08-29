# Roadmap

> Long-term direction and raw ideas. Items here are NOT actionable tasks.
> When an idea is refined into bounded work, it moves to `TODO_LIST.md`.

## Themes

### 1. Cross-platform reach

The server module today is NixOS-only. macOS machines are served by the client
module alone.

Raw ideas:

- `darwinModules` output configuring macOS sshd via nix-darwin — parked with
  reason (2026-08-29): effort is a settings _mapping_ onto nix-darwin's
  services.openssh surface plus launchd specifics, and the repo has no Darwin
  CI runner to prove it at runtime (the whole point after v0.1.0). First
  bounded step when revived: a mapping table nix-darwin settings ← our
  crypto/hardening profile, reviewed without code
- Darwin CI coverage for the OrbStack/Colima include logic (needs a Darwin
  runner or a mock of `builtins.pathExists`)

### 2. Ecosystem integration

Raw ideas:

- age / sops-nix integration for private key distribution. Design skeleton:
  (a) never ship private keys in this flake (public output, public repo);
  (b) scope = a _guide_ + example wiring sops-nix secrets for the client's
  identity files, not a new module option; (c) open question: per-host
  key placement via `age.identityPaths` vs HM `sops.secrets` — decide when
  the first consumer needs it
- Flake overlay pinning a specific OpenSSH version alongside the crypto profile
  — decision: parked. Pinning delays security updates and cuts against the
  "profile works over any modern OpenSSH" story; the compatibility matrix +
  `ssh -Q` runtime check already catch support gaps. Revisit only when an
  algorithm we need is newer than what nixpkgs ships
- `nixos-generate-config` interplay study (avoid fighting imperative sshd config)
  — parked with reason: our module only writes `services.openssh.settings` and
  two `/etc` files, all of which nixos-generate-config leaves alone; no fight
  observed in any consumer (2026-08-29). Reopen only if a consumer reports
  generated hardware-configuration interference.
- Retire downstream workarounds once a tagged release ships them: after v0.1.2,
  drop `nix-international-telephony`'s now-redundant
  `extraSettings.KbdInteractiveAuthentication = false` workaround and its
  duplicated docs claims

### 3. Test depth

Raw ideas:

- Multi-node NixOS test: this flake's client connecting to this flake's server,
  end-to-end — PARTIALLY DONE (2026-08-29): the VM already proves a real
  client↔server handshake with negotiated ML-KEM, wrong-key rejection and
  banner delivery; the remaining delta is putting the Home Manager _client
  module itself_ inside the VM (HM-in-NixOS evaluation), which needs a
  design pass on `home-manager.users` integration
- `sshd -T` exact-match runtime validation (was part of the removed VM test;
  restore alongside it)
- Positive prompt-path test: deliberately enable a PAM prompt module (or
  `unixAuth`) and prove `KbdInteractiveAuthentication no` blocks a real
  prompted-then-rejected exchange end-to-end. Refined design (2026-08-29):
  VM variant with `kbdInteractiveAuthentication = true` + `usePAM = true` +
  a passwordless-locked test user; drive `ssh -o PreferredAuthentications=
keyboard-interactive` under `sshpass` with a known-wrong password and
  assert refusal in the same run that already asserts the negative path.
  Bounded ~90min task when picked up; the method-list + golden assertions
  are the interim guards
- Table-driven fixture host in the HM eval: DECIDED yes (2026-08-29) —
  adopt when the next host-level option lands; loop `hosts × options`
  instead of one "full" host so every option pair is asserted uniformly

### 4. Post-quantum completion

ML-KEM key exchange is deployed; authentication signatures remain classical.

Raw ideas:

- ML-DSA (FIPS 204) signature support the moment OpenSSH ships it — watch
  upstream; no implementation timeline exists today. RECURRING check:
  scan the OpenSSH release notes at each quarterly matrix re-verification
  (next: 2026-12-01); the `ssh -Q` subtest fails the VM the moment a key
  type would be needed but unsupported
- Quarterly re-verification cadence for the README OpenSSH compatibility
  matrix against upstream release notes (watch the OpenSSH release feed).
  RECURRING: next re-verification due 2026-12-01, then quarterly
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
- ~~`nix flake update` cadence decision (inputs move on nixos-unstable)~~ decided 2026-08-29: the weekly GitHub workflow (`.github/workflows/update-flake-lock.yml`) opens a labeled PR every Monday; merge only with green checks. Security-relevant consumers pin release tags (see nix-internatial-telephony's `v0.1.2` pin) rather than chasing branches

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
