# nix-ssh-config

A Nix flake providing modular, hardened SSH client & server configurations for NixOS and nix-darwin. Secure by default, post-quantum ready (ML-KEM hybrid key exchange). Consumed as a flake input by other NixOS/Home Manager configurations.

---

## Commands

```bash
nix flake check --all-systems --no-build   # Evaluate checks on ALL supported systems (no building)
nix flake check                            # Build + run the current system's checks
nix fmt                                    # Format all files (treefmt via treefmt-nix)
nix fmt -- --fail-on-change                # CI-mode: fail if files need formatting
nix develop                                # Dev shell with nil (Nix LSP)
```

CI (`.github/workflows/check.yml`) runs the three check commands above in order. All must pass.

### Supported systems

`aarch64-darwin`, `x86_64-linux`, `aarch64-linux`. **`x86_64-darwin` is excluded** (deprecated in Nixpkgs 26.05) via a filter over the `nix-systems` input.

### Why `--all-systems` needs `--no-build`

`nix flake check --all-systems` alone tries to **build** foreign-system check derivations (e.g. `aarch64-darwin` `runCommand` on an `x86_64-linux` runner) and fails with `platform mismatch`. Evaluate all systems with `--no-build`, build only the native system. Do not "simplify" this back to bare `--all-systems` — it broke every CI run until it was fixed.

---

## Architecture

```
modules/
├── shared/crypto.nix        # Single source of truth for ALL crypto algorithms
├── home-manager/ssh.nix     # Client config  → homeManagerModules.ssh
└── nixos/ssh.nix            # Server config  → nixosModules.ssh
```

- **`modules/shared/crypto.nix`** — Defines four algorithm lists (`pqKex`, `aeadCiphers`, `etmMacs`, `modernHostKeys`) and their comma-joined `*String` variants. Both client and server import this. Any crypto change happens here and propagates to both.
- **Client** (`home-manager/ssh.nix`) — Options under `ssh-config.*`. Generates `programs.ssh.settings` blocks (`*` global defaults, `github.com`, plus user hosts). Has a Home Manager activation script that creates `~/.ssh/sockets` with mode 700.
- **Server** (`nixos/ssh.nix`) — Options under `services.ssh-server.*`. Generates `services.openssh.settings` plus `environment.etc` entries for authorized keys and banner. Guards everything with `lib.mkIf config.services.ssh-server.enable`.
- **Flake** — Built with flake-parts (`mkFlake { inherit inputs; }` receiving an attrset, not a bare module list) plus the treefmt-nix flakeModule.

### Flake outputs

| Output                       | What                                                                     |
| ---------------------------- | ------------------------------------------------------------------------ |
| `homeManagerModules.ssh`     | SSH client module (Home Manager)                                         |
| `nixosModules.ssh`           | SSH server module (NixOS)                                                |
| `sshKeys`                    | Attrset of tracked public keys (`lars`, `lars-evo-x2`) — consumed as `nix-ssh-config.sshKeys.lars` etc. |
| `checks.<system>.*`          | 4 test derivations (2 module-eval, 2 security content assertions) + `format` (treefmt) |
| `devShells.<system>.default` | `mkShellNoCC` with `nil` only — formatting comes from treefmt, not the shell |
| `formatter.<system>`         | treefmt (via treefmt-nix `flakeModule`, nixfmt enabled)                  |

There is **no** `apps` output and **no** VM integration test at present (the pre-flake-parts test suite was intentionally reduced during migration; restoring coverage is tracked in TODO_LIST.md).

---

## Critical gotchas

### NixOS sshd settings: lists vs strings (DO NOT get this wrong)

`services.openssh.settings` treats keys differently depending on whether they are **explicit NixOS options** or **freeform keys**:

| Directive                                       | Form expected                                          | Why                                    |
| ----------------------------------------------- | ------------------------------------------------------ | -------------------------------------- |
| `Ciphers`, `Macs`, `KexAlgorithms`              | **Nix list** — NixOS joins with commas                 | Explicit options                       |
| `HostKeyAlgorithms`, `PubkeyAcceptedAlgorithms` | **Pre-joined string** (`crypto.modernHostKeysString`)  | Freeform keys                          |
| `AuthorizedKeysFile`                            | **Space-separated string**                             | `sshd_config` format (multiple paths)   |

This is why `crypto.nix` exports both list and `*String` variants. The server module uses lists for Ciphers/Macs/KexAlgorithms but strings for HostKeyAlgorithms/PubkeyAcceptedAlgorithms. Getting this wrong produces malformed `sshd_config`. Documented inline at `modules/nixos/ssh.nix`.

### Home Manager uses strings everywhere

The HM client uses `programs.ssh.settings` (freeform), so **all** crypto directives take the `*String` (comma-joined) form. Note the key name is `MACs` (mixed case) on the HM side, not `Macs`.

### `extraSettings` merges last (can override defaults)

On the server, `config.services.ssh-server.extraSettings` is merged with `//` **after** the hardcoded defaults. Consumers can override any default (e.g. `LoginGraceTime`). Keep this ordering when editing.

### `lib.mkIf` on `environment.etc` attrs, not on `.text`

The server uses `lib.optionalAttrs` wrapped around the `environment.etc` attrset, conditioned on whether keys/banner are provided. Do not move the condition onto `.text` — that produces a broken `environment.etc` entry.

### The HM eval check is weaker than it looks

`checks.home-manager-module-evaluates` forces `hmEval.config.programs.ssh.matchBlocks` with `deepSeq`. Since the client migrated to `programs.ssh.settings`, `matchBlocks` is an empty internal attrset — the check proves evaluation but not the generated content. Strengthening it is tracked in TODO_LIST.md.

### Real test key committed in flake.nix

The `testKey` used by the test evaluations is a real personal public key. Replacing it with a throwaway is tracked in TODO_LIST.md; until then, do not treat it as disposable test data.

---

## Conventions

- **Option namespaces**: client options live under `ssh-config.*` (hyphen, not dots — a known deviation from Nix convention; deferred to a hypothetical v2.0). Server options live under `services.ssh-server.*`.
- **Types**: ports use `types.port` (0–65535), not `types.int`. `extraSettings` is constrained to `attrsOf (oneOf [str int bool])` — not `anything`.
- **Composability**: the `Banner` path uses `lib.mkDefault` so downstream modules can override it.
- **User inheritance**: `ssh-config.hosts.*.user` defaults to `null` and inherits from `ssh-config.user` (which defaults to `config.home.username`).
- **State versions in tests**: use `lib.mkDefault "25.05"` to keep `nix flake check` warning-free.
- **Task automation lives in flake.nix** — no Makefile, no justfile (organizational convention).

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
- `home-manager` — follows nixpkgs; used for `homeManagerConfiguration` in test evals (deliberately kept for test fidelity)
- `flake-parts` — flake architecture (`mkFlake`)
- `treefmt-nix` — formatter + `checks.*.format` (nixfmt)
- `nix-systems` — canonical system list (filtered to drop `x86_64-darwin`)

---

## Documentation map

| File           | Owns                                                    |
| -------------- | ------------------------------------------------------- |
| `README.md`    | End-user intro, module reference, security rationale     |
| `FEATURES.md`  | Honest feature inventory by status                       |
| `TODO_LIST.md` | Open, bounded work items                                 |
| `ROADMAP.md`   | Long-term themes, non-goals                              |
| `CHANGELOG.md` | What changed per version                                 |
| `docs/status/`  | Point-in-time session reports — all fully annotated and moved to `docs/status/archived/` (open follow-ups live in TODO_LIST.md / ROADMAP.md) |
