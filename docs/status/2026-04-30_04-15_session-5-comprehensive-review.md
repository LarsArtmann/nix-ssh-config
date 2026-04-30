# Session 5 Status Report — Comprehensive Review & Refactoring

**Date:** 2026-04-30 04:15 CEST
**Branch:** master
**Base commit:** `e0ac693` → `6e9f688` (auto-committed module refactoring)
**Pending uncommitted:** flake.nix, README.md, LICENSE, MIGRATION_TO_NIX_FLAKES_PROPOSAL.md

---

## Summary

Full codebase review and refactoring session. Read every file, cross-referenced with upstream NixOS sshd module source (via Sourcegraph), identified 11 issues ranging from critical to low severity, and resolved 10 of them. Added automated evaluation checks that catch module breakage at `nix flake check` time.

---

## A. Fully Done

| # | What | Details |
|---|------|---------|
| 1 | **Shared crypto module** | Created `modules/shared/crypto.nix` (36 lines) — single source of truth for all SSH crypto algorithms. Exposes both Nix lists and pre-joined strings. Both modules now import from it. Eliminates the DRY violation that caused 3 trial-and-error fix commits in session 4. |
| 2 | **Removed `Protocol = 2`** | Deprecated since OpenSSH 7.0 (2016). Was generating warnings in sshd_config. Completely removed from NixOS module. |
| 3 | **Fixed dead `ssh-config.user` option** | Was declared but never referenced in any `matchBlocks`. Now wired into the `*` wildcard block via `user = lib.mkDefault config.ssh-config.user;`. |
| 4 | **Changed default user from `"lars"` to `config.home.username`** | Hardcoded personal username made the module non-reusable. Now defaults to the Home Manager canonical username. Added `defaultText` for documentation rendering. |
| 5 | **Added `checks` output** | `nix flake check` now evaluates both modules on all 4 architectures (aarch64-darwin, x86_64-linux, x86_64-darwin, aarch64-linux). Uses `builtins.deepSeq` to force full evaluation into a derivation. Would have caught all 3 session 4 fix commits. |
| 6 | **Added `devShells` output** | `nix develop` provides `nixfmt` and `nil` (Nix LSP). Contributors get a standardized environment. |
| 7 | **Fixed LICENSE file** | README referenced "MIT — See LICENSE file" but no LICENSE existed. Created MIT license with 2026 Lars Artmann copyright. |
| 8 | **Fixed README inaccuracies** | Corrected `authorizedKeysFiles` default (was showing only one path, now shows all three + "see below" reference). Added `identityFile` to options table. Added Host Submodule Options table (7 options documented). Fixed GitHub URL from `yourusername` to `LarsArtmann`. Added `ssh-config.user` default as `config.home.username`. |
| 9 | **Added OpenSSH compatibility documentation** | New "OpenSSH Version Compatibility" table: `mlkem768x25519-sha256` ≥ 9.9, `sntrup761x25519-sha512` ≥ 8.5, `curve25519-sha256` ≥ 6.5, `chacha20-poly1305` ≥ 6.5. New "Post-Quantum Status" section: ML-KEM deployed, ML-DSA not yet available. |
| 10 | **Documented NixOS list-vs-string gotcha** | Added inline comment in `modules/nixos/ssh.nix` explaining why `Ciphers`/`KexAlgorithms` use lists (NixOS auto-joins) while `HostKeyAlgorithms`/`PubkeyAcceptedAlgorithms` use pre-joined strings (freeform keys). This was the root cause of 5 fix commits in session 4. |
| 11 | **Fixed `environment.etc` duplicate block** | NixOS module had two separate `environment.etc` blocks which Nix rejects. Merged into single block using `lib.optionalAttrs` + `//`. |
| 12 | **Fixed `nixfmt-rfc-style` deprecation** | devShells used `nixfmt-rfc-style` which is now an alias for `nixfmt`. Changed to `nixfmt`. |
| 13 | **Formatted all files** | Ran `nix fmt` — 3 files reformatted (table alignment in README, formatting in flake.nix and proposal). |

---

## B. Partially Done

| # | What | Status | What's Left |
|---|------|--------|-------------|
| 1 | **Migration proposal updates** | The `MIGRATION_TO_NIX_FLAKES_PROPOSAL.md` was reformatted by `nix fmt` but not substantively updated to reflect completed work (§2.1 shared crypto is done, §2.3 user default is done, §3.1 checks is done, §3.2 devShells is done, §6.1 LICENSE is done). | Update proposal to mark completed items, add new discovery about `user` option wiring, re-prioritize remaining items. |

---

## C. Not Started

| # | What | Priority | Effort | Notes |
|---|------|----------|--------|-------|
| 1 | GitHub Actions CI workflow | High | 30 min | `.github/workflows/check.yml` with `nix flake check --all-systems` + `nix fmt -- --check`. Proposal §4.4 has template. |
| 2 | NixOS VM integration test | Medium | 3 hr | Spin up QEMU VM, verify sshd starts, banner served, ciphers correct, key auth works. Gold standard but time-intensive. Proposal §4.2. |
| 3 | Home Manager config content verification | Medium | 1 hr | Verify generated `~/.ssh/config` text contains expected content (Host, User, KexAlgorithms, etc.). Proposal §4.3. |
| 4 | `CONTRIBUTING.md` | Low | 15 min | Standard contribution guidelines. |
| 5 | `CHANGELOG.md` | Low | 10 min | Track versions and changes. |
| 6 | `.editorconfig` | Low | 5 min | Cross-editor formatting consistency. |
| 7 | `.envrc` for direnv | Low | 2 min | `use flake` — auto-activates devShell on cd. |
| 8 | `justfile` | Low | 15 min | Standardized task runner for check/fmt/update/test. |
| 9 | Update migration proposal to reflect done items | Medium | 15 min | Mark §2.1, §2.3, §3.1, §3.2, §6.1 as complete. |
| 10 | Evaluate/remove unused `home-manager` input | Medium | 10 min | Kept for `checks` — could use `nixpkgs.lib.evalModules` directly instead. Decision needed. |
| 11 | Crypto algorithm rationale documentation | Low | 30 min | Why these specific algorithms, what threat model they address. |
| 12 | `apps` output (vm-test, fmt-check) | Low | 30 min | Convenience commands. |
| 13 | nix-darwin server module (`darwinModules`) | Low | 1 hr | macOS sshd configuration. |
| 14 | age/sops-nix integration | Low | 2 hr | Secret management for SSH keys. |
| 15 | Git versioning (v0.1.0 tag) | Low | 5 min | First release tag. |

---

## D. Totally Fucked Up

Nothing. All changes evaluate cleanly. `nix flake check --all-systems` passes on all 4 architectures. No regressions introduced.

---

## E. What We Should Improve

| # | Area | Current State | Improvement |
|---|------|---------------|-------------|
| 1 | **`user` option scope** | `ssh-config.user` sets default user on `*` wildcard only; individual hosts must specify `user` explicitly | Consider auto-inheriting `ssh-config.user` as default for all host blocks (via `lib.mkDefault`) |
| 2 | **Banner file handling** | Banner is written to `environment.etc."ssh/banner".text` which may conflict with other modules | Use `lib.mkDefault` to allow overrides |
| 3 | **Module option `ssh-config` naming** | Uses hyphen which is unconventional in Nix module system (dots are standard) | Consider `ssh.client` or `programs.ssh-config` for consistency with HM conventions |
| 4 | **`services.ssh-server` namespace** | Custom namespace instead of extending `services.openssh` directly | Could use `services.openssh.settings` directly with a wrapper, but current approach is cleaner for encapsulation |
| 5 | **No `description` on shared crypto module** | `crypto.nix` has no module header explaining purpose | Add header comment with algorithm rationale and version requirements |
| 6 | **`AuthorizedKeysFile` uses space separator** | Hardcoded in NixOS module | Should be documented that spaces are the sshd_config separator for this directive |
| 7 | **`builtins.pathExists` in HM module** | Runtime path check for OrbStack/Colima configs | This is evaluated at build time — works correctly but may surprise contributors |
| 8 | **No `lib.types.nullOr` on bannerText content validation** | Accepts any string | Could validate banner doesn't contain control characters that break sshd |
| 9 | **Checks only verify evaluation, not runtime** | `nix flake check` proves modules evaluate, not that sshd actually starts | VM integration tests would close this gap |
| 10 | **`stateVersion` warning in NixOS checks** | Test config doesn't set `system.stateVersion`, produces warning | Add `system.stateVersion = "25.05";` to test config for clean output |

---

## F. Top 25 Things to Do Next

### Priority 1 — Critical/High Impact

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Add GitHub Actions CI (`.github/workflows/check.yml`) | 30 min | Prevents broken commits from landing on master |
| 2 | Update migration proposal to mark completed items | 15 min | Keeps documentation honest and actionable |
| 3 | Suppress `system.stateVersion` warning in NixOS test config | 2 min | Clean `nix flake check` output |
| 4 | Add header comment to `crypto.nix` with algorithm rationale + version requirements | 10 min | Future maintainers understand the "why" |
| 5 | Commit current uncommitted changes (flake.nix, README, LICENSE) | 5 min | Don't lose work |

### Priority 2 — Quality & Testing

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | Add Home Manager SSH config content verification test | 1 hr | Proves generated config text is correct |
| 7 | Add NixOS VM integration test (sshd starts, key auth works) | 3 hr | Gold standard — proves runtime correctness |
| 8 | Add `lib.mkDefault` to banner text to allow overrides | 2 min | Makes module more composable |
| 9 | Auto-inherit `ssh-config.user` in all host blocks | 5 min | Reduces boilerplate for consumers |
| 10 | Add `.editorconfig` for cross-editor consistency | 5 min | Prevents tab/space wars |

### Priority 3 — Developer Experience

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | Add `CONTRIBUTING.md` | 15 min | Lowers barrier for contributors |
| 12 | Add `.envrc` (`use flake`) | 2 min | Auto-activates dev shell |
| 13 | Add `justfile` for common tasks | 15 min | Standardized developer commands |
| 14 | Add `CHANGELOG.md` | 10 min | Track project evolution |
| 15 | Add `apps` output for `fmt-check` | 15 min | Convenient CI-local check |

### Priority 4 — Architecture & Polish

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | Evaluate replacing `home-manager` input with `nixpkgs.lib.evalModules` | 30 min | Reduces flake.lock size if HM input not needed for checks |
| 17 | Consider renaming `ssh-config` to `ssh.client` | 30 min | More conventional Nix module naming |
| 18 | Add crypto algorithm rationale section to README | 30 min | Explains threat model and algorithm choices |
| 19 | Document `AuthorizedKeysFile` space-separator behavior | 5 min | Prevents confusion about why spaces not commas |
| 20 | Add `nix-darwin` server module (`darwinModules`) | 1 hr | Cross-platform server config |

### Priority 5 — Future

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 21 | Git versioning (v0.1.0 tag) | 5 min | First release |
| 22 | age/sops-nix integration for secret management | 2 hr | Secure private key distribution |
| 23 | Post-quantum signature migration plan (ML-DSA) | TBD | Future-proof when OpenSSH adds support |
| 24 | Consider `lib.types.nullOr` validation on bannerText | 15 min | Prevent invalid sshd configs |
| 25 | Explore NixOS `nixos/lib/testing-python.nix` for multi-node SSH tests | 2 hr | End-to-end client↔server verification |

---

## G. Top Question I Cannot Answer

**Should the `home-manager` flake input be kept or removed?**

- **Keep:** Enables `home-manager.lib.homeManagerConfiguration` in `checks` (current approach). Downstream consumers can use `inputs.nix-ssh-config.inputs.home-manager.follows = "home-manager"`.
- **Remove:** Reduces flake.lock by ~30 lines. Removes maintenance burden when HM releases break compatibility. The HM check could be rewritten using `nixpkgs.lib.evalModules` directly (bypassing `homeManagerConfiguration`).

This is a maintainer decision — the tradeoff is between testing convenience and dependency minimalism. I recommend **keeping it** because the check already proved its value by catching the `home.stateVersion` issue during development.

---

## File Inventory (Current State)

```
.
├── .config/metadata.yaml              (4 lines)
├── .gitignore                         (23 lines)
├── LICENSE                            (21 lines)    ← NEW
├── MIGRATION_TO_NIX_FLAKES_PROPOSAL.md (622 lines)  ← reformatted
├── README.md                          (228 lines)   ← rewritten
├── flake.lock                         (127 lines)
├── flake.nix                          (100 lines)   ← +checks, +devShells
├── docs/
│   └── status/
│       ├── 2026-04-04_01-49_comprehensive-status.md
│       ├── 2026-04-04_02-21_comprehensive-status.md
│       ├── 2026-04-04_02-46_comprehensive-status.md
│       └── 2026-04-04_06-58_session-4-status.md
├── modules/
│   ├── shared/
│   │   └── crypto.nix                 (36 lines)    ← NEW
│   ├── home-manager/
│   │   └── ssh.nix                    (158 lines)   ← refactored
│   └── nixos/
│       └── ssh.nix                    (137 lines)   ← refactored
└── ssh-keys/
    └── lars-ed25519.pub               (1 line)

Total: ~1,488 lines (Nix: 431, Markdown: 850+231, Other: 76)
```

## Verification

```
$ nix flake check --all-systems
evaluating flake...
...
all checks passed!
```

All 4 architectures × 2 module checks + devShells + formatter = 16 derivations evaluated successfully.

---

_Generated by Crush (GLM-5.1) — Session 5_
