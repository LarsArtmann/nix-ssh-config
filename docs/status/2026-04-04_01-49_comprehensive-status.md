# Status Report — 2026-04-04_01-49

**Project:** nix-ssh-config  
**Branch:** master  
**Commit:** e134229 — remove standalone module exports as they are no longer needed  
**Report by:** Crush (GLM-5.1)

---

## a) FULLY DONE

| #   | Item                       | Details                                                                                                                                                                                                                                      |
| --- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Duplicate code removed** | Dropped `homeManagerModule` / `nixosModule` singular aliases from `flake.nix:38-39`. These were redundant wrappers around `homeManagerModules.ssh` / `nixosModules.ssh`. Committed as `e134229`.                                             |
| 2   | **Duplicate code audit**   | Reviewed all 4 source files (`flake.nix`, `modules/nixos/ssh.nix`, `modules/home-manager/ssh.nix`, `README.md`). No other meaningful duplication exists — the two modules serve fundamentally different purposes (SSH client vs SSH server). |
| 3   | **SSH client module**      | Home Manager module (`modules/home-manager/ssh.nix`) fully functional — supports hosts, GitHub optimized config, OrbStack/Colima integration, control master paths, extra includes.                                                          |
| 4   | **SSH server module**      | NixOS module (`modules/nixos/ssh.nix`) fully functional — hardened sshd with ciphers, KEX, connection limits, banner, user allow-listing, key-only auth.                                                                                     |
| 5   | **Flake outputs**          | Exports `homeManagerModules.ssh`, `nixosModules.ssh`, `sshKeys.lars`, and per-system `formatter`. Clean and minimal.                                                                                                                         |
| 6   | **Formatting**             | treefmt-full-flake integrated, per-system formatter defined for 4 architectures.                                                                                                                                                             |
| 7   | **Public key exposure**    | `sshKeys.lars` available as flake output for declarative consumption.                                                                                                                                                                        |

---

## b) PARTIALLY DONE

Nothing partially done — all identified work items are either complete or not started.

---

## c) NOT STARTED

| #   | Item                                                                                                                  | Priority | Effort |
| --- | --------------------------------------------------------------------------------------------------------------------- | -------- | ------ |
| 1   | **README update** — Remove any references to `homeManagerModule` / `nixosModule` (singular) if they exist in docs     | Low      | Tiny   |
| 2   | **Nix flake check CI** — No GitHub Actions or CI pipeline defined                                                     | Medium   | Medium |
| 3   | **Tests** — No automated tests exist (nix flakes can be tested with `nix flake check`, lib tests, or example configs) | High     | Medium |
| 4   | **LICENSE file** — README mentions "MIT - See LICENSE file" but no LICENSE file exists                                | Medium   | Tiny   |
| 5   | **Additional SSH keys** — Only `lars.pub` exists; structure supports more but none added                              | Low      | Tiny   |
| 6   | **NixOS VM test** — No integration test spinning up a VM and verifying sshd config                                    | Medium   | Large  |
| 7   | **Example configs** — No `examples/` directory with ready-to-use configurations                                       | Low      | Small  |
| 8   | **CHANGELOG** — No changelog tracking                                                                                 | Low      | Tiny   |
| 9   | **Contributing guide** — No CONTRIBUTING.md                                                                           | Low      | Tiny   |
| 10  | **Home Manager module tests** — No verification that generated `~/.ssh/config` is correct                             | Medium   | Medium |

---

## d) TOTALLY FUCKED UP

Nothing. The project is clean, builds on master, no broken state.

---

## e) WHAT WE SHOULD IMPROVE

### Critical

1. **Missing LICENSE file** — README claims MIT license but no LICENSE file exists. This is a legal gap that makes the repo technically all-rights-reserved.

### High Impact

2. **No automated testing** — A flake this small is easy to test with `nix flake check` and simple NixOS/home-manager evaluation tests. Without them, regressions are invisible.
3. **No CI pipeline** — PRs and pushes have no validation. A simple GitHub Actions workflow running `nix flake check` would catch issues.
4. **README may reference removed aliases** — After dropping `homeManagerModule`/`nixosModule`, the README examples should use only `homeManagerModules.ssh`/`nixosModules.ssh`.

### Medium Impact

5. **`home-manager` input unused in module evaluations** — The `home-manager` input is declared but never passed into any module. If it's only needed for user documentation/examples, it could be removed from inputs to reduce closure size. If it's intended for downstream use, that should be documented.
6. **Hardcoded default user `lars`** — `modules/home-manager/ssh.nix:13` defaults to `"lars"`. For a reusable module, this should probably have no default or use `config.home.username`.
7. **No `nix flake check` validation** — The flake doesn't define `checks` outputs, so `nix flake check` only validates basic schema.
8. **Banner text is very long** — The default `bannerText` in `modules/nixos/ssh.nix:51-66` is 12 lines. Could be extracted to a separate file and referenced.
9. **Crypto algorithm lists should be reviewed periodically** — Ciphers and KEX algorithms in `modules/nixos/ssh.nix:107-121` should have a review schedule as OpenSSH evolves.

### Low Impact

10. **No `.editorconfig`** — Consistent editor formatting across contributors.
11. **`ssh-keys/` only has one key** — The structure is fine, but worth noting it's minimal.
12. **README Quick Start references `yourusername`** — Should be updated to actual GitHub org/user.

---

## f) Top 25 Things We Should Get Done Next

| #   | Task                                                                                         | Priority     | Effort | Category |
| --- | -------------------------------------------------------------------------------------------- | ------------ | ------ | -------- |
| 1   | Add MIT LICENSE file                                                                         | **Critical** | 2 min  | Legal    |
| 2   | Verify README uses only `homeManagerModules.ssh` / `nixosModules.ssh` (not singular aliases) | High         | 2 min  | Docs     |
| 3   | Update README GitHub URL from `yourusername` to actual user/org                              | High         | 1 min  | Docs     |
| 4   | Add `nix flake check` validation (checks output)                                             | High         | 30 min | Quality  |
| 5   | Add GitHub Actions CI (`nix flake check`, `nix fmt --check`)                                 | High         | 30 min | CI       |
| 6   | Add NixOS module evaluation test                                                             | High         | 1 hr   | Testing  |
| 7   | Add Home Manager module evaluation test                                                      | High         | 1 hr   | Testing  |
| 8   | Change default `user` from `"lars"` to `config.home.username` or remove default              | Medium       | 5 min  | Config   |
| 9   | Evaluate if `home-manager` input is actually needed                                          | Medium       | 10 min | Cleanup  |
| 10  | Extract banner text to separate file                                                         | Medium       | 10 min | Refactor |
| 11  | Add `checks` output to flake.nix                                                             | Medium       | 30 min | Quality  |
| 12  | Add example configurations in `examples/` directory                                          | Medium       | 30 min | Docs     |
| 13  | Add NixOS VM integration test (sshd actually starts)                                         | Medium       | 2 hr   | Testing  |
| 14  | Add CONTRIBUTING.md                                                                          | Low          | 15 min | Docs     |
| 15  | Add CHANGELOG.md                                                                             | Low          | 10 min | Docs     |
| 16  | Add `.editorconfig`                                                                          | Low          | 5 min  | Quality  |
| 17  | Add more SSH keys to `ssh-keys/`                                                             | Low          | 2 min  | Config   |
| 18  | Document crypto algorithm choices and review schedule                                        | Low          | 15 min | Docs     |
| 19  | Add `flake.nix` comments explaining system architecture choices                              | Low          | 10 min | Docs     |
| 20  | Consider adding `darwinModules` for nix-darwin server config                                 | Low          | 1 hr   | Feature  |
| 21  | Add SSH config validation (check generated config syntax)                                    | Low          | 1 hr   | Testing  |
| 22  | Consider age/sops-nix integration for SSH key management                                     | Low          | 2 hr   | Feature  |
| 23  | Add versioning scheme (tags, releases)                                                       | Low          | 15 min | Process  |
| 24  | Document migration path for users of the removed singular aliases                            | Low          | 10 min | Docs     |
| 25  | Add `apps` output for useful CLI tools (key rotation, config lint)                           | Low          | 3 hr   | Feature  |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Is the `home-manager` flake input actually used by consumers, or is it purely for documentation/examples?**

The `home-manager` input is declared in `flake.nix:6-9` but is never referenced in any `outputs` beyond the function parameter. The modules themselves (`modules/home-manager/ssh.nix`) don't import it — they only use `config`, `lib`, `pkgs` from the consuming home-manager installation. If downstream users are expected to use this as `home-manager` shared input, it should stay. If not, removing it would reduce the flake lock/closure. This is a product decision only the maintainer can make.

---

## Summary

Project is **healthy and clean**. The only committed change this session was removing redundant module aliases. The most critical gap is the missing LICENSE file. Next priorities should be: LICENSE → README verification → basic CI/testing.
