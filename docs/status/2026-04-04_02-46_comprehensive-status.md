# Status Report — 2026-04-04_02-46

**Project:** nix-ssh-config
**Branch:** master
**Commit:** 8867c43 — feat: add ed25519 SSH key and harden SSH configuration with modern algorithms
**Report by:** Crush (GLM-5.1)
**Previous report:** 2026-04-04_02-21

---

## What Changed Since Last Report

| Commit | Message |
|--------|---------|
| `8867c43` | feat: add ed25519 SSH key and harden SSH configuration with modern algorithms |

Major security hardening pass + RSA key replaced with Ed25519:

- **New key**: `ssh-keys/lars-ed25519.pub` added; old `lars.pub` (RSA) staged for deletion
- **Client crypto**: Home Manager module now sets `KexAlgorithms` (mlkem768x25519-sha256, sntrup761x25519, curve25519), `Ciphers` (AEAD only), `MACs` (ETM only), `HostKeyAlgorithms` (ed25519 preferred), `PubkeyAcceptedAlgorithms`, `IdentityFile` (~/.ssh/id_ed25519)
- **Server crypto**: NixOS module updated — removed weak DH groups and AES-CTR ciphers, added MACs list, HostKeyAlgorithms, replaced KEX with post-quantum + curve25519 only
- **Flake**: `sshKeys.lars` now points to ed25519 key (was RSA)
- **README**: Updated with post-quantum feature flag, security defaults section rewritten

### Uncommitted Changes (pending)

- **Staged**: `ssh-keys/lars.pub` deletion (old RSA key removal)
- **Unstaged**: `README.md` modifications (feature bullet, security defaults, directory structure, example key type)
- **Unstaged**: `flake.nix` modification (`sshKeys` consolidated to single `lars` key pointing to ed25519)

These are in-progress changes — likely from a concurrent session or manual edits.

---

## a) FULLY DONE

| # | Item | Details |
|---|------|---------|
| 1 | **Flake scaffolding** | `flake.nix` (45 lines) — 3 inputs, 4 architectures, clean output structure with `homeManagerModules.ssh`, `nixosModules.ssh`, `sshKeys.lars`, per-system `formatter` |
| 2 | **Home Manager SSH client module** | `modules/home-manager/ssh.nix` (147 lines) — 6 options, wildcard defaults block with full crypto suite (post-quantum KEX, AEAD ciphers, ETM MACs, ed25519 preferred), GitHub optimized matchBlock, OrbStack/Colima conditional includes, per-host submodule (7 fields) |
| 3 | **NixOS SSH server module** | `modules/nixos/ssh.nix` (165 lines) — 8 options (`authorizedKeys` included), hardened sshd with post-quantum KEX, AEAD-only ciphers, ETM MACs, connection limits, banner, access control, global `/etc/ssh/authorized_keys` |
| 4 | **Post-quantum key exchange** | Both client and server configured with `mlkem768x25519-sha256` (ML-KEM hybrid, NIST FIPS 203) as primary KEX algorithm |
| 5 | **Ed25519 key migration** | RSA key deprecated, Ed25519 key added. `sshKeys.lars` in flake now points to `lars-ed25519.pub`. Client defaults to `~/.ssh/id_ed25519` |
| 6 | **Public key exposure** | `sshKeys.lars` exposed as flake output, pointing to ed25519 key |
| 7 | **Global authorized keys** | `authorizedKeys` option writes to `/etc/ssh/authorized_keys`, included in `AuthorizedKeysFile` path |
| 8 | **Formatting** | treefmt-full-flake per-system formatter for 4 architectures |
| 9 | **Duplicate code removal** | Singular module aliases removed |
| 10 | **.gitignore** | Properly ignores private keys, tracks `*.pub`, standard IDE/OS/direnv ignores |
| 11 | **flake.lock** | Dependencies pinned |
| 12 | **Server hardening complete** | Ciphers: AEAD only. MACs: ETM only. KEX: post-quantum + curve25519. Host keys: ed25519 preferred. No X11, no TCP forwarding, no tunnel. MaxAuthTries=3, MaxSessions=2. Banner. Verbose logging |
| 13 | **Client hardening complete** | Same crypto profile as server. IdentityFile defaults to ed25519. ForwardAgent=false. AddKeysToAgent=no. ControlMaster=no by default |

---

## b) PARTIALLY DONE

| # | Item | Status | What's Missing |
|---|------|--------|----------------|
| 1 | **RSA key removal** | Old `lars.pub` staged for deletion, `flake.nix` updated | Still uncommitted. RSA key deletion + flake update + README update all in working tree but not committed together |
| 2 | **README documentation** | Updated with post-quantum features and ed25519 references | `authorizedKeysFiles` default in table still doesn't match actual default. Host submodule options incomplete (only 6 of 7 listed). GitHub URL still `yourusername`. `user` default still documented as `"lars"` |
| 3 | **Security defaults in README** | Server and client sections rewritten with crypto details | No explanation of *why* specific algorithms were chosen or compatibility matrix (which OpenSSH versions support mlkem768x25519-sha256?) |

---

## c) NOT STARTED

| # | Item | Priority | Effort |
|---|------|----------|--------|
| 1 | **LICENSE file** — README claims MIT but file doesn't exist | **Critical** | 2 min |
| 2 | **Automated tests** — No `checks` output, no evaluation tests | High | 2 hr |
| 3 | **CI pipeline** — No GitHub Actions workflow | High | 30 min |
| 4 | **Fix README `authorizedKeysFiles` default** — Table says `["%h/.ssh/authorized_keys"]`, actual default has 3 entries | Medium | 2 min |
| 5 | **Fix README GitHub URL** — Still `yourusername` | Medium | 1 min |
| 6 | **Document all host submodule options** — Missing `extraOptions` from table | Medium | 5 min |
| 7 | **OpenSSH version compatibility docs** — mlkem768x25519-sha256 requires OpenSSH 9.x+. Document minimum versions | Medium | 15 min |
| 8 | **Hardcoded default user `"lars"`** — Should use `config.home.username` | Medium | 5 min |
| 9 | **Evaluate `home-manager` input necessity** | Medium | 10 min |
| 10 | **Example configurations** — No `examples/` directory | Medium | 30 min |
| 11 | **CHANGELOG.md** | Low | 10 min |
| 12 | **CONTRIBUTING.md** | Low | 15 min |
| 13 | **`.editorconfig`** | Low | 5 min |
| 14 | **Versioning/tags** | Low | 15 min |
| 15 | **NixOS VM integration test** | Medium | 2 hr |
| 16 | **Home Manager module test** | Medium | 1 hr |
| 17 | **Extract banner text** | Low | 10 min |
| 18 | **Additional SSH keys** | Low | 2 min |
| 19 | **nix-darwin server module** | Low | 1 hr |
| 20 | **age/sops-nix integration** | Low | 2 hr |

---

## d) TOTALLY FUCKED UP

**Nothing broken.** However, there are **3 uncommitted changes in the working tree**:

1. **Staged**: `ssh-keys/lars.pub` deleted (old RSA key)
2. **Unstaged**: `README.md` modified (crypto docs + ed25519 references)
3. **Unstaged**: `flake.nix` modified (`sshKeys` consolidated)

These appear to be an incomplete key migration — the RSA key is staged for deletion, flake.nix updated to point to ed25519, README updated to match. This is coherent work but **not yet committed**. Working tree is in a half-migrated state.

---

## e) WHAT WE SHOULD IMPROVE

### Critical

1. **Missing LICENSE file** — Still not addressed. README says "MIT - See LICENSE file" but the file doesn't exist. Legal risk.

### High Impact

2. **Uncommitted key migration** — RSA→Ed25519 migration is half-done in working tree. Should be committed as a single coherent change.
3. **No automated testing** — Zero tests for 552 lines of Nix. Both modules have complex crypto configurations that should be validated.
4. **No CI** — No validation on push.
5. **README table inaccuracies** — `authorizedKeysFiles` default wrong. Host submodule options incomplete.

### Medium Impact

6. **OpenSSH version compatibility unknown** — Post-quantum KEX (`mlkem768x25519-sha256`) requires recent OpenSSH. No minimum version documented. Could break on older servers.
7. **Hardcoded `user = "lars"`** — Still present.
8. **No fallback for missing ed25519 identity** — Client defaults to `~/.ssh/id_ed25519` but doesn't create it. User may not have this key.
9. **`home-manager` input still undeclared-use** — Previous report flagged this, still unresolved.
10. **Crypto algorithm choices not documented with rationale** — Why these specific KEX/ciphers/MACs? What threat model? What compatibility tradeoffs?

### Low Impact

11. **README GitHub URL placeholder** — Still `yourusername`.
12. **No CHANGELOG** — Three sessions of changes, no tracking.
13. **No versioning** — No git tags.
14. **Only one SSH key** — Single ed25519 key for single user.

---

## f) Top 25 Things We Should Get Done Next

| # | Task | Priority | Effort | Category |
|---|------|----------|--------|----------|
| 1 | Add MIT LICENSE file | **Critical** | 2 min | Legal |
| 2 | Commit the pending RSA→Ed25519 migration (stage flake.nix + README + lars.pub deletion) | **High** | 2 min | Migration |
| 3 | Fix README `authorizedKeysFiles` default value in options table | **High** | 2 min | Docs |
| 4 | Document all 7 host submodule fields in README table | **High** | 5 min | Docs |
| 5 | Add OpenSSH minimum version compatibility notes to README | **High** | 15 min | Docs |
| 6 | Add `checks` output to flake.nix (module evaluation tests) | **High** | 1 hr | Quality |
| 7 | Add GitHub Actions CI workflow | **High** | 30 min | CI |
| 8 | Change default `user` from `"lars"` to `config.home.username` | Medium | 5 min | Config |
| 9 | Evaluate/remove `home-manager` input if unused | Medium | 10 min | Cleanup |
| 10 | Update README GitHub URL from `yourusername` | Medium | 1 min | Docs |
| 11 | Add NixOS module evaluation test | Medium | 1 hr | Testing |
| 12 | Add Home Manager module evaluation test | Medium | 1 hr | Testing |
| 13 | Document crypto algorithm rationale and threat model | Medium | 30 min | Docs |
| 14 | Add fallback identity file handling or document prerequisite | Medium | 15 min | Config |
| 15 | Extract banner text to separate file/constant | Medium | 10 min | Refactor |
| 16 | Add example configurations in `examples/` | Medium | 30 min | Docs |
| 17 | Add NixOS VM integration test (sshd starts, key auth works) | Medium | 2 hr | Testing |
| 18 | Add CONTRIBUTING.md | Low | 15 min | Docs |
| 19 | Add CHANGELOG.md | Low | 10 min | Docs |
| 20 | Add `.editorconfig` | Low | 5 min | Quality |
| 21 | Add git versioning (v0.1.0 tag) | Low | 5 min | Process |
| 22 | Add more SSH keys as needed | Low | 2 min | Config |
| 23 | Consider nix-darwin server module | Low | 1 hr | Feature |
| 24 | Consider age/sops-nix integration for private key management | Low | 2 hr | Feature |
| 25 | Add `apps` output for CLI tools (key rotation, config lint) | Low | 3 hr | Feature |

---

## g) Top #1 Question I Cannot Figure Out Myself

**What is the minimum OpenSSH version required for `mlkem768x25519-sha256` KEX, and should we provide a fallback for older servers?**

The client module now prioritizes `mlkem768x25519-sha256` as the first KEX algorithm. This is a post-quantum hybrid key exchange based on ML-KEM (NIST FIPS 203). However:
- OpenSSH added `mlkem768x25519-sha256` support in **OpenSSH 9.9** (released late 2024)
- Many production servers still run OpenSSH 8.x (Ubuntu 20.04, Debian 10, RHEL 8)
- The client will fall through to `sntrup761x25519-sha512` or `curve25519-sha256` if the server doesn't support ML-KEM — **but only if the server supports KEX algorithm negotiation**
- If a server has a *static* KEX configuration that doesn't include any of our client's algorithms, the connection will fail

This is a **compatibility vs. security** tradeoff that only the maintainer can decide. Options:
1. Keep as-is (modern only, break on old servers)
2. Add `diffie-hellman-group14-sha256` as a fallback
3. Make the crypto profile configurable per-host (with `extraOptions` override)

---

## File Inventory

```
.
├── .gitignore                    (23 lines)
├── README.md                     (195 lines) — uncommitted changes pending
├── flake.lock                    (pinned deps)
├── flake.nix                     (45 lines) — uncommitted changes pending
├── docs/
│   └── status/
│       ├── 2026-04-04_01-49_comprehensive-status.md
│       ├── 2026-04-04_02-21_comprehensive-status.md
│       └── 2026-04-04_02-46_comprehensive-status.md  ← this file
├── modules/
│   ├── home-manager/
│   │   └── ssh.nix               (147 lines)
│   └── nixos/
│       └── ssh.nix               (165 lines)
└── ssh-keys/
    ├── lars.pub                  (staged for deletion)
    └── lars-ed25519.pub          (current key)
```

**Total source lines:** 552 (Nix: 357, Markdown: 195)

---

## Commit History (Full)

| Hash | Message |
|------|---------|
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

---

## Summary

Project is **healthy and significantly hardened** since last report. The RSA→Ed25519 migration is in progress (3 uncommitted files). Both modules now have post-quantum KEX, AEAD-only ciphers, and ETM-only MACs. **Critical gaps remain: missing LICENSE file and no tests/CI.** The #1 open question is OpenSSH version compatibility for the post-quantum KEX algorithms.
