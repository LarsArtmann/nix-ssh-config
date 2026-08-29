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
statix check                               # Nix anti-pattern linter (manual, not in CI; keep clean)
```

Pre-push pre-flight (one command, run all local gates in CI order):

```bash
nix fmt -- --fail-on-change && statix check && nix flake check --all-systems --no-build && nix flake check
```

CI (`.github/workflows/check.yml`) has two jobs: `check` (x86_64-linux, runs the three commands above plus a lychee markdown-link check) and `check-aarch64` (native arm64 runner, same gate). All steps must pass.

### Supported systems

`aarch64-darwin`, `x86_64-linux`, `aarch64-linux`. **`x86_64-darwin` is excluded** (deprecated in Nixpkgs 26.05) via a filter over the `nix-systems` input.

### Why `--all-systems` needs `--no-build`

`nix flake check --all-systems` alone tries to **build** foreign-system check derivations (e.g. `aarch64-darwin` `runCommand` on an `x86_64-linux` runner) and fails with `platform mismatch`. Evaluate all systems with `--no-build`, build only the native system. Do not "simplify" this back to bare `--all-systems` — it broke every CI run until it was fixed.

---

## Architecture

```
modules/
├── shared/crypto.nix        # Single source of truth for ALL crypto algorithms
├── shared/banner.nix        # Default legal banner constant (byte-stable)
├── home-manager/ssh.nix     # Client config  → homeManagerModules.ssh
└── nixos/ssh.nix            # Server config  → nixosModules.ssh
tests/
├── checks.nix               # The whole check suite as a flake-parts module
└── test-key{,.pub}          # Throwaway CI keypair (fixtures + VM test)
examples/                    # Copy-ready client/server modules → examples.*
```

- **`modules/shared/crypto.nix`** — Defines four algorithm lists (`pqKex`, `aeadCiphers`, `etmMacs`, `modernHostKeys`) and their comma-joined `*String` variants. Both client and server import this. Any crypto change happens here and propagates to both.
- **Client** (`home-manager/ssh.nix`) — Options under `ssh-config.*`. Generates `programs.ssh.settings` blocks (`*` global defaults, `github.com`, plus user hosts). Has a Home Manager activation script that creates `~/.ssh/sockets` with mode 700.
- **Server** (`nixos/ssh.nix`) — Options under `services.ssh-server.*`. Generates `services.openssh.settings` plus `environment.etc` entries for authorized keys and banner. Guards everything with `lib.mkIf config.services.ssh-server.enable`.
- **Flake** — Built with flake-parts (`mkFlake { inherit inputs; }` receiving an attrset, not a bare module list) plus the treefmt-nix flakeModule. `flake.nix` stays small (~60 lines: inputs, modules/examples/sshKeys outputs, treefmt, devShell); **every check lives in `tests/checks.nix`** (imported as a flake-parts module) — new tests go there, not into flake.nix.

### Flake outputs

| Output                                | What                                                                                                              |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `homeManagerModules.ssh`              | SSH client module (Home Manager)                                                                                  |
| `nixosModules.ssh`                    | SSH server module (NixOS)                                                                                         |
| `examples.client` / `examples.server` | Ready-to-use example modules, exercised by `checks.*.examples-evaluate`                                           |
| `sshKeys`                             | Attrset of tracked public keys (`lars`, `lars-evo-x2`) — consumed as `nix-ssh-config.sshKeys.lars` etc.           |
| `checks.<system>.*`                   | 18 eval/content checks (19 on Linux: assertion checks are Linux-only) + `format`/`treefmt`; on x86_64-linux additionally `nixos-vm-sshd` (QEMU integration test). `docs-option-inventory`/`docs-check-count` red-flag README/FEATURES drift when these change |
| `devShells.<system>.default`          | `mkShellNoCC` with `nil` only — formatting comes from treefmt, not the shell                                      |
| `formatter.<system>`                  | treefmt (via treefmt-nix `flakeModule`, nixfmt enabled)                                                           |

There is **no** `apps` output. The VM integration test was restored (2026-08-22) and immediately caught a real runtime bug (see the StrictModes gotcha below).

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

### `extraSettings` merges last (can override defaults)

On the server, `config.services.ssh-server.extraSettings` is merged with `//` **after** the hardcoded defaults. Consumers can override any default (e.g. `LoginGraceTime`). Keep this ordering when editing.

### `lib.mkIf` on `environment.etc` attrs, not on `.text`

The server uses `lib.optionalAttrs` wrapped around the `environment.etc` attrset, conditioned on whether keys/banner are provided. Do not move the condition onto `.text` — that produces a broken `environment.etc` entry.

### Global authorized_keys MUST be a copy, not a symlink (runtime-breaking)

`environment.etc."ssh/authorized_keys"` carries `mode = "0444"`. This is load-bearing: any mode other than `"symlink"` makes NixOS **copy** the file into `/etc`, while the default symlinks into `/nix/store`. sshd's StrictModes rejects every `AuthorizedKeysFile` whose realpath crosses the world-writable (1777) `/nix/store` — a symlinked global keys file is silently ignored at runtime ("Authentication refused: bad ownership or modes for directory /nix/store"), all key logins fail. Upstream NixOS uses the same copy trick for `/etc/ssh/authorized_keys.d/*`. The eval check `nixos-authorized-keys` and the VM subtest "not a symlink" both guard this; do not remove the mode.

### `sshd -T` prints PascalCase

Modern OpenSSH prints effective config directives in documented PascalCase (`PasswordAuthentication no`), not lowercase. `grep 'passwordauthentication no'` matches nothing — use `grep -i` in tests.

### Home Manager wraps `settings` blocks in an internal structure

`programs.ssh.settings.<block>` is `{ before, after, data, header }`; the actual directives live under `.data` (same as the old `matchBlocks`). The flake's `hmBlock` helper unwraps it. If HM changes representation, that helper is what needs updating.

### VM testScript: `succeed` swallows output, `execute` returns it

In `nixosTest` scripts, `machine.succeed(cmd)` returns only stdout and hides failures behind an exception; `machine.execute(cmd)` returns `(status, output)` and is the only way to assert on a command's *failure* text (e.g. the exact `Permission denied (publickey)` message). Append `2>&1` inside the command or ssh's stderr never reaches `output`.

### `cache.home.lan` 502s are machine-local, not a repo problem

Local builds may show `unable to download 'https://cache.home.lan/monitor365/...': HTTP error 502` retries. Root cause: the maintainer's LAN nix substituter is down — that substituter comes from machine-local nix.conf, nothing in this repo. Nix retries 5×, disables the cache for 60s, and proceeds from cache.nixos.org; builds stay green. CI has the same best-effort policy by design: the `magic-nix-cache-action` step runs with `continue-on-error: true`, so a cache outage slows the run but never turns it red (decided 2026-08-29, M5 of plan 2).

---

## Conventions

- **Option namespaces**: client options live under `ssh-config.*` (hyphen, not dots — a known deviation from Nix convention; deferred to a hypothetical v2.0). Server options live under `services.ssh-server.*`.
- **Types**: ports use `types.port` (0–65535), not `types.int`. `extraSettings` is constrained to `attrsOf (oneOf [str int bool])` — not `anything`.
- **Composability**: the `Banner` path uses `lib.mkDefault` so downstream modules can override it.
- **User inheritance**: `ssh-config.hosts.*.user` defaults to `null` and inherits from `ssh-config.user` (which defaults to `config.home.username`).
- **State versions in tests**: use `lib.mkDefault "25.05"` to keep `nix flake check` warning-free.
- **Test keys are throwaway**: `tests/test-key{,.pub}` (see `tests/README.md`) exist only for CI evals and the VM test. Never embed personal keys in test code.
- **Kill-switch discipline**: every content assertion was once deliberately broken to prove it fails. Keep that true for new assertions — a test that cannot fail is decoration.
- **Gates run unmasked, claims follow exit codes**: never pipe a gate (`nix flake check | tail` reports the pipe's exit code, not nix's — this shipped a broken commit once). Run the bare command; write "green" only when the exit code is in hand. Learned twice (2026-08-22, 2026-08-29).
- **When a gate behaves impossibly, suspect the test first** (vacuous fixture, missing `enable`, async evidence) before blaming tooling caches — purge caches only after a minimal repro proves staleness (2026-08-29: a ~40-minute wrong diagnosis started with an eval-cache purge).
- **After behavior/default changes, grep the docs**: sweep README/FEATURES/AGENTS/examples for the old claim before declaring done (a stale documented default is a lie shipped on time).
- **Test evals must set `services.ssh-server.enable = true`** (or another activating flag): without it `mkIf` disables the module and upstream NixOS defaults silently answer the assertions, making them vacuous — they pass even when the module is broken. Found 2026-08-29 when a kill-switch refused to trip.
- **`toString` on Nix bools gives `"1"`/`""`**, not `"true"`/`"false"` — when tracing values inside derivation strings, use `builtins.toJSON`.
- **Task automation lives in flake.nix** — no Makefile, no justfile (organizational convention).

---

## Security posture

Conservative + post-quantum strategy. All rationale lives in `README.md` (not duplicated in code).

- **Key exchange**: `mlkem768x25519-sha256` (NIST FIPS 203 ML-KEM hybrid) primary; NTRU Prime hybrid fallback; Curve25519 last resort.
- **Ciphers**: AEAD-only (ChaCha20-Poly1305, AES-GCM). No CBC.
- **MACs**: Encrypt-then-MAC only. No encrypt-and-MAC, no HMAC-MD5/SHA1.
- **Host keys**: Ed25519 preferred; RSA-SHA2 accepted for compat. No DSA, no RSA-SHA1.
- **Server defaults**: passwords and keyboard-interactive off (`kbdInteractiveAuthentication` defaults to `passwordAuthentication`; `PasswordAuthentication no` alone leaves the NixOS-default `KbdInteractiveAuthentication yes` + `UsePAM` PAM prompt channel open — OTP modules or, where the sshd PAM service permits them, Unix passwords), root login off, X11/TCP/tunnel forwarding off, MaxAuthTries=3, MaxSessions=2, verbose logging, legal banner.
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

| File           | Owns                                                                                                                                         |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `README.md`    | End-user intro, module reference, security rationale                                                                                         |
| `FEATURES.md`  | Honest feature inventory by status                                                                                                           |
| `TODO_LIST.md` | Open, bounded work items                                                                                                                     |
| `ROADMAP.md`   | Long-term themes, non-goals                                                                                                                  |
| `CHANGELOG.md` | What changed per version                                                                                                                     |
| `docs/status/` | Point-in-time session reports — all fully annotated and moved to `docs/status/archived/` (open follow-ups live in TODO_LIST.md / ROADMAP.md) |
