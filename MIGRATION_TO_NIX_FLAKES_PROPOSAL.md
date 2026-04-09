# Migration to Nix Flakes — Improvement Proposal

**Project:** nix-ssh-config
**Date:** 2026-04-09
**Author:** Crush (GLM-5.1)
**Status:** Draft — Awaiting Maintainer Decision

---

## Executive Summary

This project already uses Nix flakes as its packaging and distribution mechanism. However, the current flake is **minimal** — it exports modules and keys but lacks automated testing, development tooling, CI, shared abstractions, and several quality-of-life outputs that modern flakes provide. This proposal identifies **6 improvement areas** with **26 actionable items**, organized by priority and effort.

The single most impactful change: **adding `checks` outputs with module evaluation tests**, which would have prevented the 3 trial-and-error fix commits in session 4.

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Architecture Issues](#2-architecture-issues)
3. [Missing Flake Outputs](#3-missing-flake-outputs)
4. [Quality & Testing](#4-quality--testing)
5. [Developer Experience](#5-developer-experience)
6. [Documentation Gaps](#6-documentation-gaps)
7. [Security & Correctness](#7-security--correctness)
8. [Implementation Roadmap](#8-implementation-roadmap)
9. [Decisions Required](#9-decisions-required)
10. [Appendix: Source Inventory](#appendix-source-inventory)

---

## 1. Current State Assessment

### What Works Well

| Area | Assessment |
|---|---|
| **Module architecture** | Clean separation: `homeManagerModules.ssh` (client) and `nixosModules.ssh` (server). Each is a self-contained Nix module with proper `options`/`config` structure. |
| **Security posture** | Post-quantum KEX (ML-KEM hybrid), AEAD-only ciphers, ETM-only MACs, Ed25519 preferred. Hardened defaults throughout. |
| **Flake structure** | 45-line `flake.nix` with 3 inputs, 4 system architectures, `forEachSystem` helper. Minimal and readable. |
| **Key management** | `sshKeys.lars` exposed as flake output for declarative consumption. Ed25519 key migration complete. |
| **Formatting** | `treefmt-full-flake` integrated as per-system formatter. |
| **Git hygiene** | Clean working tree, proper `.gitignore`, coherent commit history. |

### What's Missing or Broken

| Area | Severity | Details |
|---|---|---|
| **No `checks` output** | **High** | `nix flake check` only validates basic schema. No module evaluation tests. |
| **No CI pipeline** | **High** | Zero automated validation on push or PR. |
| **No LICENSE file** | **Critical** | README says "MIT — See LICENSE file" but no LICENSE file exists. Legal gap. |
| **Duplicated crypto constants** | **High** | Both modules define the same 4 algorithm sets independently. DRY violation causing drift risk. |
| **No devShells** | **Medium** | No `nix develop` environment for contributors. |
| **No `home-manager` input usage** | **Medium** | Input declared but never referenced in any output. Dead weight in flake.lock. |
| **Hardcoded default user** | **Medium** | `ssh-config.user` defaults to `"lars"` instead of `config.home.username`. |
| **README inaccuracies** | **Medium** | Wrong `authorizedKeysFiles` default, incomplete option docs, `yourusername` placeholder. |

---

## 2. Architecture Issues

### 2.1 Duplicated Crypto Algorithm Definitions

**Problem:** Both `modules/home-manager/ssh.nix` and `modules/nixos/ssh.nix` independently define the same 4 algorithm sets:

```
pqKex       — Post-quantum key exchange algorithms
aeadCiphers — AEAD-only cipher suite
etmMacs     — Encrypt-then-MAC algorithms
modernHostKeys — Ed25519 and modern host key types
```

The NixOS module uses **Nix lists** (for `Ciphers`, `KexAlgorithms`) and **comma-separated strings** (for `Macs`, `HostKeyAlgorithms`, `PubkeyAcceptedAlgorithms`). The Home Manager module uses **raw strings** for everything (because `extraOptions` takes strings).

**Why this matters:** If one module is updated with a new algorithm, the other must be updated identically. Session 4 proved this — 3 fix commits were needed to resolve format confusion.

**Proposed solution:** Create `modules/shared/crypto.nix`:

```nix
# modules/shared/crypto.nix
# Shared cryptographic algorithm definitions for SSH hardening.
#
# NixOS services.openssh.settings is inconsistent:
#   - Ciphers, KexAlgorithms → accept Nix lists
#   - Macs, HostKeyAlgorithms, PubkeyAcceptedAlgorithms → require comma-separated strings
#
# Home Manager programs.ssh.matchBlocks *.extraOptions → all require strings
#
# Therefore: expose lists (canonical) + a `join` helper for string conversion.

{lib}: let
  join = lib.concatStringsSep ",";

  pqKex = [
    "mlkem768x25519-sha256"           # ML-KEM hybrid (NIST FIPS 203), OpenSSH 9.9+
    "sntrup761x25519-sha512@openssh.com" # NTRU Prime hybrid, OpenSSH 8.5+
    "curve25519-sha256@libssh.org"
    "curve25519-sha256"
  ];

  aeadCiphers = [
    "chacha20-poly1305@openssh.com"
    "aes256-gcm@openssh.com"
    "aes128-gcm@openssh.com"
  ];

  etmMacs = [
    "hmac-sha2-512-etm@openssh.com"
    "hmac-sha2-256-etm@openssh.com"
    "umac-128-etm@openssh.com"
  ];

  modernHostKeys = [
    "ssh-ed25519"
    "sk-ssh-ed25519@openssh.com"
    "rsa-sha2-512"
    "rsa-sha2-256"
  ];
in {
  inherit pqKex aeadCiphers etmMacs modernHostKeys;

  pqKexString = join pqKex;
  aeadCiphersString = join aeadCiphers;
  etmMacsString = join etmMacs;
  modernHostKeysString = join modernHostKeys;
}
```

Both modules would then import from this shared source:

```nix
let crypto = import ../shared/crypto.nix { inherit lib; };
```

**Effort:** 30 minutes | **Priority:** High

### 2.2 Unused `home-manager` Input

**Problem:** The `home-manager` input is declared in `flake.nix` lines 6–9 but never referenced in any output. The modules themselves only use standard module arguments (`config`, `lib`, `pkgs`).

**Impact:** Adds ~30 lines to `flake.lock`, increases closure, and creates a maintenance burden when `home-manager` releases break compatibility.

**Recommendation:** Evaluate whether downstream consumers use `inputs.nix-ssh-config.inputs.home-manager.follows = "home-manager"`. If not, remove the input.

**Effort:** 10 minutes (evaluation) | **Priority:** Medium

### 2.3 Hardcoded Default User

**Problem:** `modules/home-manager/ssh.nix` line 17 sets `default = "lars"`. This makes the module opinionated about the username, reducing reusability.

**Recommendation:** Change to `config.home.username` or remove the default entirely (forcing users to set it).

```nix
user = lib.mkOption {
  type = lib.types.str;
  default = config.home.username;
  description = "Username for SSH connections";
};
```

**Effort:** 5 minutes | **Priority:** Medium

---

## 3. Missing Flake Outputs

### 3.1 `checks` — Automated Module Evaluation Tests

**Problem:** No `checks` output. `nix flake check` only verifies basic flake schema, not whether modules actually evaluate correctly.

**Proposed structure:**

```nix
checks = forEachSystem ({system, pkgs}: let
  nixpkgs-lib = nixpkgs.lib;
in {
  nixos-module-evaluates = nixpkgs-lib.nixosSystem {
    inherit system;
    modules = [
      self.nixosModules.ssh
      {
        services.ssh-server = {
          enable = true;
          allowUsers = ["testuser"];
          authorizedKeys = ["ssh-ed25519 AAAA... test@host"];
        };
        boot.isContainer = true;
        fileSystems."/".device = "/dev/null";
      }
    ];
  };

  home-manager-module-evaluates = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeManagerModules.ssh
      {
        ssh-config = {
          enable = true;
          hosts.test = {
            hostname = "example.com";
            user = "admin";
          };
        };
        home.username = "test";
        home.homeDirectory = "/home/test";
      }
    ];
  };
});
```

**Note:** If `home-manager` input is removed (§2.2), the HM test would need to be restructured or the input kept solely for testing.

**Effort:** 1–2 hours | **Priority:** High

### 3.2 `devShells` — Development Environment

**Problem:** No `devShells` output. Contributors have no standardized development environment.

**Proposed:**

```nix
devShells = forEachSystem ({pkgs, ...}: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      nixfmt-rfc-style
      nil                    # Nix LSP
      nix-eval-jobs          # Parallel evaluation
    ];
    shellHook = ''
      echo "nix-ssh-config development shell"
      echo "Run 'nix flake check' to validate"
    '';
  };
});
```

**Effort:** 15 minutes | **Priority:** Medium

### 3.3 `apps` — Convenience Commands

**Problem:** No `apps` output for common development tasks.

**Potential apps:**

| App | Purpose |
|---|---|
| `vm-test` | Spin up a NixOS VM with the SSH server module enabled and verify sshd starts |
| `fmt-check` | Run formatter in check mode without modifying files |

**Effort:** 30 minutes | **Priority:** Low

---

## 4. Quality & Testing

### 4.1 Evaluation Tests (§3.1 covers basic eval)

### 4.2 NixOS VM Integration Tests

The gold standard for NixOS module testing is the NixOS VM test framework (`nixos/lib/testing-python.nix`). This spins up a QEMU VM, starts sshd, and verifies the configuration works end-to-end.

**Example test structure:**

```nix
# tests/nixos-sshd.nix
{pkgs, ...}: let
  testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/uqxUhFQpJaBq+dDd+shObEjKm8YOPimFx7XHgqTFJ lars@Lars-MacBook-Air-2026-04";
in
  pkgs.nixosTest {
    name = "sshd-hardenened-config";

    nodes.server = {config, ...}: {
      imports = [../modules/nixos/ssh.nix];
      services.ssh-server = {
        enable = true;
        allowUsers = ["root"];
        authorizedKeys = [testKey];
      };
      # Verify key cipher/MAC/KEX settings are applied
      # by checking services.openssh.settings
    };

    nodes.client = {pkgs, ...}: {
      environment.systemPackages = [pkgs.openssh];
    };

    testScript = ''
      server.start()
      server.wait_for_unit("sshd.service")
      server.wait_for_open_port(22)
      # Verify banner is served
      server.succeed("sshd -T | grep Banner")
      # Verify password auth is disabled
      server.succeed("sshd -T | grep 'passwordauthentication no'")
      # Verify modern ciphers only
      server.succeed("sshd -T | grep chacha20-poly1305")
    '';
  }
```

**Effort:** 2–3 hours | **Priority:** Medium (highly valuable but time-intensive)

### 4.3 Home Manager Configuration Verification

Test that the generated `~/.ssh/config` file contains expected content:

```nix
# tests/home-manager-ssh-config.nix
let
  config = home-manager.lib.homeManagerConfiguration {
    # ... setup ...
    modules = [
      self.homeManagerModules.ssh
      {
        ssh-config = {
          enable = true;
          hosts.testserver = {
            hostname = "192.168.1.100";
            user = "admin";
            port = 2222;
          };
        };
      }
    ];
  };
  sshConfig = config.home.file.".ssh/config".text;
in
  pkgs.runCommand "verify-ssh-config" {} ''
    echo "${sshConfig}" | grep "Host testserver"
    echo "${sshConfig}" | grep "HostName 192.168.1.100"
    echo "${sshConfig}" | grep "User admin"
    echo "${sshConfig}" | grep "Port 2222"
    echo "${sshConfig}" | grep "mlkem768x25519-sha256"
    touch $out
  ''
```

**Effort:** 1 hour | **Priority:** Medium

### 4.4 GitHub Actions CI

**Proposed `.github/workflows/check.yml`:**

```yaml
name: Check
on:
  push:
    branches: [master]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main
      - run: nix flake check --all-systems
      - run: nix fmt -- --check
```

**Effort:** 30 minutes | **Priority:** High

---

## 5. Developer Experience

### 5.1 Direnv Integration

Add `.envrc` for automatic shell activation:

```bash
# .envrc
use flake
```

Combined with `devShells.default`, contributors get automatic tool setup on `cd`.

**Effort:** 2 minutes | **Priority:** Low

### 5.2 Justfile / Task Runner

Although the project is small, a `justfile` standardizes common operations:

```just
# justfile
check:
    nix flake check --all-systems

fmt:
    nix fmt

fmt-check:
    nix fmt -- --check

update:
    nix flake update

test:
    nix flake check

vm-test:
    nix build .#checks.x86_64-linux.nixos-sshd-integration
```

**Effort:** 15 minutes | **Priority:** Low

---

## 6. Documentation Gaps

### 6.1 Missing Files

| File | Status | Effort |
|---|---|---|
| `LICENSE` | **Critical — Missing** | 2 min |
| `CONTRIBUTING.md` | Not started | 15 min |
| `CHANGELOG.md` | Not started | 10 min |
| `.editorconfig` | Not started | 5 min |

### 6.2 README Inaccuracies

| Issue | Current | Correct | Location |
|---|---|---|---|
| `authorizedKeysFiles` default | `["%h/.ssh/authorized_keys"]` | `["%h/.ssh/authorized_keys" "/etc/ssh/authorized_keys.d/%u" "/etc/ssh/authorized_keys"]` | README options table |
| Host submodule options | 6 listed | 7 total (`extraOptions` missing) | README options table |
| GitHub URL | `yourusername` | Actual org/user | README Quick Start |
| `user` default | `"lars"` | Should reflect actual default or be changed | README options table |
| OpenSSH min version | Not documented | `mlkem768x25519-sha256` ≥ 9.9, `sntrup761x25519-sha512` ≥ 8.5 | Missing section |

### 6.3 Suggested README Additions

- **OpenSSH version compatibility matrix** (which algorithms require which version)
- **Crypto algorithm rationale** (why these specific choices, what threat model)
- **Post-quantum status section** (KEX done, signatures future — ML-DSA timeline)
- **NixOS `sshd_config` format gotcha** (which directives take lists vs strings)
- **Migration guide** for users of removed singular aliases (`homeManagerModule`/`nixosModule`)

---

## 7. Security & Correctness

### 7.1 OpenSSH Version Compatibility

The current KEX priority list requires:

| Algorithm | Min OpenSSH | Status |
|---|---|---|
| `mlkem768x25519-sha256` | 9.9 (Oct 2024) | Default since 10.0 |
| `sntrup761x25519-sha512` | 8.5 (Mar 2021) | Widely available |
| `curve25519-sha256` | 6.5 (Oct 2016) | Universal |
| `chacha20-poly1305` | 6.5 | Universal |

**Risk:** Servers running OpenSSH < 6.5 (extremely rare in 2026) will fail to connect. Servers with static KEX configurations that exclude all listed algorithms will also fail.

**Recommendation:** Document minimum versions. Consider whether a fallback to `diffie-hellman-group14-sha256` should be available (configurable per-host via `extraOptions`).

### 7.2 Post-Quantum Signature Roadmap

| Area | Status | Timeline |
|---|---|---|
| Key exchange (ML-KEM) | ✅ Deployed | Complete |
| Authentication (ML-DSA) | ❌ Not available | IETF draft exists, no OpenSSH implementation timeline |
| Threat level | Low urgency | Attacker needs captured handshake AND future quantum computer |

**Recommendation:** Add a README section documenting this and a note in `modules/shared/crypto.nix` for future ML-DSA migration.

### 7.3 Missing Identity File Handling

The Home Manager module defaults to `~/.ssh/id_ed25519` as identity file but does not verify this file exists. Users without an Ed25519 key will see SSH errors.

**Recommendation:** Either document the prerequisite or add a check/warning.

---

## 8. Implementation Roadmap

### Phase 1 — Critical Fixes (30 minutes)

| # | Task | Effort |
|---|---|---|
| 1 | Add MIT LICENSE file | 2 min |
| 2 | Fix README `authorizedKeysFiles` default | 2 min |
| 3 | Document all host submodule options in README | 5 min |
| 4 | Update README GitHub URL | 1 min |
| 5 | Add OpenSSH minimum version compatibility notes | 15 min |

### Phase 2 — Shared Architecture (1 hour)

| # | Task | Effort |
|---|---|---|
| 6 | Create `modules/shared/crypto.nix` with shared constants | 30 min |
| 7 | Refactor both modules to import shared constants | 20 min |
| 8 | Add comments in NixOS module documenting list-vs-string format | 5 min |

### Phase 3 — Testing & CI (3 hours)

| # | Task | Effort |
|---|---|---|
| 9 | Add `checks` output with module evaluation tests | 1.5 hr |
| 10 | Add Home Manager config content verification test | 1 hr |
| 11 | Add GitHub Actions CI workflow | 30 min |

### Phase 4 — Developer Experience (1 hour)

| # | Task | Effort |
|---|---|---|
| 12 | Add `devShells` output | 15 min |
| 13 | Add `.envrc` for direnv | 2 min |
| 14 | Add `justfile` for common tasks | 15 min |
| 15 | Add `.editorconfig` | 5 min |

### Phase 5 — Polish (2 hours)

| # | Task | Effort |
|---|---|---|
| 16 | Change default `user` from `"lars"` to `config.home.username` | 5 min |
| 17 | Evaluate/remove unused `home-manager` input | 10 min |
| 18 | Extract banner text to separate constant | 10 min |
| 19 | Add crypto algorithm rationale documentation | 30 min |
| 20 | Add `CONTRIBUTING.md` | 15 min |
| 21 | Add `CHANGELOG.md` | 10 min |
| 22 | Add post-quantum status section to README | 10 min |

### Phase 6 — Advanced Testing (4 hours)

| # | Task | Effort |
|---|---|---|
| 23 | Add NixOS VM integration test (sshd starts, key auth works) | 3 hr |
| 24 | Add SSH config syntax validation test | 1 hr |

### Future Considerations

| # | Task | Effort |
|---|---|---|
| 25 | Add `apps` output (vm-test, fmt-check) | 30 min |
| 26 | Consider nix-darwin server module (`darwinModules`) | 1 hr |
| 27 | Consider age/sops-nix integration | 2 hr |
| 28 | Add git versioning (v0.1.0 tag) | 5 min |
| 29 | Plan for post-quantum signature migration (ML-DSA) | TBD |

---

## 9. Decisions Required

These decisions affect implementation and can only be made by the maintainer:

### 9.1 Shared Crypto Module: Lists or Strings?

The shared `crypto.nix` module should expose **lists as canonical** with a `join` helper:

```nix
# Consumers use:
crypto.pqKex              # ["mlkem768x25519-sha256" ...]
crypto.pqKexString        # "mlkem768x25519-sha256,..."

# NixOS: use lists directly for Ciphers/KexAlgorithms,
#         use *String for Macs/HostKeyAlgorithms/PubkeyAcceptedAlgorithms
# Home Manager: use *String for everything in extraOptions
```

This is explicit, type-safe, and makes the NixOS inconsistency visible rather than hidden.

### 9.2 Should `home-manager` Input Stay or Go?

| Option | Pros | Cons |
|---|---|---|
| **Keep** | Enables `home-manager.lib.homeManagerConfiguration` in `checks`; downstream users can `follows` | Dead weight if nobody uses `follows`; extra lock entries |
| **Remove** | Cleaner flake.lock; less maintenance | Can't write HM evaluation tests; downstream users can't `follows` |

**Recommendation:** Keep — the testing benefit alone justifies it. But if evaluation tests are written differently (e.g., using `nixpkgs.lib.evalModules` directly), the input could be removed.

### 9.3 Default User: `"lars"` vs `config.home.username` vs No Default

| Option | Pros | Cons |
|---|---|---|
| `config.home.username` | Automatically correct for any user | Creates dependency on `home.username` being set; circular if not |
| No default (`lib.mkOption { type = lib.types.str; }`) | Forces explicit configuration | Breaking change for current users |
| Keep `"lars"` | No breaking change | Not reusable for others |

**Recommendation:** Change to `config.home.username` — it's the semantically correct default for a Home Manager module.

### 9.4 KEX Fallback for Legacy Servers

Should the client KEX list include `diffie-hellman-group14-sha256` as a last-resort fallback?

| Option | Pros | Cons |
|---|---|---|
| **Current** (no fallback) | Maximum security; fails loud on old servers | Breaks on OpenSSH < 6.5 |
| **Add fallback** | Works on virtually any SSH server | Slightly weaker negotiation position |

**Recommendation:** Keep current. OpenSSH 6.5 was released in 2014. By 2026, any server still running it has bigger security problems.

---

## Appendix: Source Inventory

```
.
├── .gitignore                         (23 lines)  — Ignores private keys, Nix artifacts, IDE/OS/direnv
├── README.md                          (195 lines) — Module reference, quick start, security defaults
├── flake.lock                         (127 lines) — Pinned: nixpkgs, home-manager, treefmt-full-flake
├── flake.nix                          (45 lines)  — 3 inputs, 4 systems, 4 output categories
├── docs/
│   └── status/
│       ├── 2026-04-04_01-49_comprehensive-status.md
│       ├── 2026-04-04_02-21_comprehensive-status.md
│       ├── 2026-04-04_02-46_comprehensive-status.md
│       └── 2026-04-04_06-58_session-4-status.md
├── modules/
│   ├── home-manager/
│   │   └── ssh.nix                    (162 lines) — SSH client: 6 options, wildcard defaults, GitHub block
│   ├── nixos/
│   │   └── ssh.nix                    (170 lines) — SSH server: 8 options, hardened sshd, banner, keys
│   └── (shared/ — proposed)           crypto.nix
└── ssh-keys/
    └── lars-ed25519.pub               (1 line)    — Ed25519 public key
```

**Total source:** ~597 lines (Nix: 377, Markdown: 195, Gitignore: 23)

### Commit History (20 commits)

| Hash | Message |
|---|---|
| `3c5452a` | fix: correct formatting inconsistencies across docs and modules |
| `252dc08` | docs: add comprehensive session 4 status report (2026-04-04) |
| `b52e543` | fix: Macs also expects list, only HostKeyAlgorithms needs string |
| `d6686c5` | fix: use Macs (not MACs) to match NixOS sshd settings casing |
| `2dd120d` | fix: use string for MACs/HostKeyAlgorithms, list for Ciphers/KexAlgorithms |
| `2a92b33` | fix: revert Ciphers/KexAlgorithms to lists — NixOS expects lists for these |
| `d9f990a` | fix: convert Ciphers and KexAlgorithms from lists to comma-separated strings |
| `c761b32` | refactor(nixos): extract crypto algorithms into named constants |
| `77ed2b0` | feat: update SSH configuration modules for nix-ssh-config project |
| `1c079f9` | docs: add comprehensive project status report (session 3, 2026-04-04) |
| `af9dc53` | refactor: complete RSA to Ed25519 key migration |
| `8867c43` | feat: add ed25519 SSH key and harden SSH configuration with modern algorithms |
| `9a906b7` | docs: add comprehensive project status report (session 2, 2026-04-04) |
| `8017855` | feat: add global authorizedKeys option for NixOS SSH server configuration |
| `1c327ec` | docs: add comprehensive project status report (2026-04-04) |
| `e134229` | remove standalone module exports as they are no longer needed |
| `fa07246` | feat: expose sshKeys as flake output for declarative key consumption |
| `4650ca1` | fix: correct formatter output for per-system builds |
| `6d7d5a9` | chore: lock flake dependencies to specific versions |
| `624cf95` | feat: add treefmt-full-flake integration for formatting |
| `a7e5332` | Initial commit: Modular SSH configuration for Nix systems |
