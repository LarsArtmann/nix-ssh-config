# nix-ssh-config

A Nix flake providing modular, hardened SSH client & server configurations for NixOS and nix-darwin. Secure by default, post-quantum ready (ML-KEM hybrid key exchange). Consumed as a flake input by other NixOS/Home Manager configurations.

---

## Commands

```bash
nix flake check --all-systems   # Run all checks: 14 eval tests + VM integration test (across 3 systems)
nix fmt                          # Format all files (treefmt via treefmt-full-flake)
nix fmt -- --fail-on-change      # CI-mode: fail if files need formatting (also: nix run .#fmt-check)
nix develop                      # Dev shell with nixfmt + nil (Nix LSP)
```

CI (`.github/workflows/check.yml`) runs `nix flake check --all-systems` then `nix fmt -- --fail-on-change`. Both must pass.

### Supported systems

`aarch64-darwin`, `x86_64-linux`, `aarch64-linux`. **`x86_64-darwin` was dropped** (deprecated in Nixpkgs 26.05). The QEMU VM integration test runs **only on `x86_64-linux`**.

---

## Architecture

```
modules/
├── shared/crypto.nix        # Single source of truth for ALL crypto algorithms
├── home-manager/ssh.nix     # Client config  → homeManagerModules.ssh
└── nixos/ssh.nix            # Server config  → nixosModules.ssh
```

- **`modules/shared/crypto.nix`** — Defines four algorithm lists (`pqKex`, `aeadCiphers`, `etmMacs`, `modernHostKeys`) and their comma-joined `*String` variants. Both client and server import this. Any crypto change happens here and propagates to both.
- **Client** (`home-manager/ssh.nix`) — Options under `ssh-config.*`. Generates `programs.ssh.settings` match blocks (`*` global defaults, `github.com`, plus user hosts). Has a Home Manager activation script that creates `~/.ssh/sockets` with mode 700.
- **Server** (`nixos/ssh.nix`) — Options under `services.ssh-server.*`. Generates `services.openssh.settings` plus `environment.etc` entries for authorized keys and banner. Guards everything with `lib.mkIf config.services.ssh-server.enable`.

### Flake outputs

| Output                              | What                                                                                                    |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `homeManagerModules.ssh`            | SSH client module (Home Manager)                                                                        |
| `nixosModules.ssh`                  | SSH server module (NixOS)                                                                               |
| `sshKeys`                           | Attrset of tracked public keys (`lars`, `lars-evo-x2`) — consumed as `nix-ssh-config.sshKeys.lars` etc. |
| `checks.<system>.*`                 | Test derivations (eval + content assertions)                                                            |
| `checks.x86_64-linux.nixos-vm-sshd` | QEMU VM integration test via `testers.nixosTest`                                                        |
| `apps.<system>.fmt-check`           | `treefmt --fail-on-change` wrapper                                                                      |
| `devShells.<system>.default`        | nixfmt + nil                                                                                            |
| `formatter.<system>`                | treefmt (from `treefmt-full-flake`)                                                                     |

---

## Critical gotchas

### NixOS sshd settings: lists vs strings (DO NOT get this wrong)

`services.openssh.settings` treats keys differently depending on whether they are **explicit NixOS options** or **freeform keys**:

| Directive                                       | Form expected                                         | Why                                   |
| ----------------------------------------------- | ----------------------------------------------------- | ------------------------------------- |
| `Ciphers`, `Macs`, `KexAlgorithms`              | **Nix list** — NixOS joins with commas                | Explicit options                      |
| `HostKeyAlgorithms`, `PubkeyAcceptedAlgorithms` | **Pre-joined string** (`crypto.modernHostKeysString`) | Freeform keys                         |
| `AuthorizedKeysFile`                            | **Space-separated string**                            | `sshd_config` format (multiple paths) |

This is why `crypto.nix` exports both list and `*String` variants. The server module uses lists for Ciphers/Macs/KexAlgorithms but strings for HostKeyAlgorithms/PubkeyAcceptedAlgorithms. Getting this wrong produces malformed `sshd_config`. Documented inline at `modules/nixos/ssh.nix`.

### Home Manager uses strings everywhere

The HM client uses `programs.ssh.settings` (freeform), so **all** crypto directives take the `*String` (comma-joined) form. Note the key name is `MACs` (mixed case) on the HM side, not `Macs`.

### Test helper touches Home Manager internals

The `getBlock` helper in `flake.nix` reads `eval.config.programs.ssh.matchBlocks.<name>.data`. The `.data` field is **Home Manager internal structure** and could break on an HM update. The client config was migrated from `matchBlocks` to `programs.ssh.settings` (commit `e4370ed`); if HM changes its internal representation, this helper will need updating.

### `extraSettings` merges last (can override defaults)

On the server, `config.services.ssh-server.extraSettings` is merged with `//` **after** the hardcoded defaults. Consumers can override any default (e.g. `LoginGraceTime`). Keep this ordering when editing.

### `lib.mkIf` on `environment.etc` attrs, not on `.text`

The server uses `lib.optionalAttrs` wrapped around the `environment.etc` attrset, conditioned on whether keys/banner are provided. Do not move the condition onto `.text` — that caused a historical bug (commit `e0ac693`).

---

## Conventions

- **Option namespaces**: client options live under `ssh-config.*` (hyphen, not dots — a known deviation from Nix convention; deferred to a hypothetical v2.0). Server options live under `services.ssh-server.*`.
- **Types**: ports use `types.port` (0–65535), not `types.int`. `extraSettings` is constrained to `attrsOf (oneOf [str int bool])` — not `anything`.
- **Composability**: `Banner` path uses `lib.mkDefault` so downstream modules can override it.
- **User inheritance**: `ssh-config.hosts.*.user` defaults to `null` and inherits from `ssh-config.user` (which defaults to `config.home.username`).
- **State versions in tests**: use `lib.mkDefault "25.05"` to keep `nix flake check` warning-free.

---

## Security posture

Conservative + post-quantum strategy. All rationale lives in `README.md` (not duplicated in code).

- **Key exchange**: `mlkem768x25519-sha256` (NIST FIPS 203 ML-KEM hybrid) primary; NTRU Prime hybrid fallback; Curve25519 last resort.
- **Ciphers**: AEAD-only (ChaCha20-Poly1305, AES-GCM). No CBC.
- **MACs**: Encrypt-then-MAC only. No encrypt-and-MAC, no HMAC-MD5/SHA1.
- **Host keys**: Ed25519 preferred; RSA-SHA2 accepted for compat. No DSA, no RSA-SHA1.
- **Server defaults**: passwords off, root login off, X11/TCP/tunnel forwarding off, MaxAuthTries=3, MaxSessions=2, verbose logging, legal banner.
- **Post-quantum signatures (ML-DSA)**: not yet available in OpenSSH — no implementation timeline. Watch upstream.

Public keys are tracked in `ssh-keys/*.pub`; private keys are gitignored. The `sshKeys` flake output reads them via `builtins.readFile`.

---

## Dependencies

- `nixpkgs` — `nixos-unstable`
- `home-manager` — follows nixpkgs; kept as input for `homeManagerConfiguration` in test evals
- `treefmt-full-flake` — formatter (`LarsArtmann/treefmt-full-flake`)
