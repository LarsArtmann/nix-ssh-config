# Status Report — 2026-04-04_02-21

**Project:** nix-ssh-config
**Branch:** master
**Commit:** 8017855 — feat: add global authorizedKeys option for NixOS SSH server configuration
**Report by:** Crush (GLM-5.1)
**Previous report:** 2026-04-04_01-49

---

## What Changed Since Last Report

| Commit    | Message                                                                   |
| --------- | ------------------------------------------------------------------------- |
| `8017855` | feat: add global authorizedKeys option for NixOS SSH server configuration |

Added `services.ssh-server.authorizedKeys` option to the NixOS module, allowing declarative SSH public key authorization. Keys are written to `/etc/ssh/authorized_keys`. Updated README with new option and usage example with `builtins.attrValues nix-ssh-config.sshKeys`.

---

## a) FULLY DONE

| #   | Item                               | Details                                                                                                                                                                                                            |
| --- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | **Flake scaffolding**              | `flake.nix` (45 lines) — 3 inputs (nixpkgs, home-manager, treefmt-full-flake), 4 system architectures, clean output structure                                                                                      |
| 2   | **Home Manager SSH client module** | `modules/home-manager/ssh.nix` (139 lines) — 6 options, wildcard defaults block, GitHub optimized matchBlock, OrbStack/Colima conditional includes, per-host submodule with 7 configurable fields                  |
| 3   | **NixOS SSH server module**        | `modules/nixos/ssh.nix` (155 lines) — 8 options including new `authorizedKeys`, hardened sshd settings (ciphers, KEX, connection limits, banner, access control), global key file at `/etc/ssh/authorized_keys`    |
| 4   | **Public key exposure**            | `sshKeys.lars` exposed as flake output via `builtins.readFile ./ssh-keys/lars.pub`                                                                                                                                 |
| 5   | **Formatting**                     | treefmt-full-flake per-system formatter for 4 architectures                                                                                                                                                        |
| 6   | **Global authorized keys**         | New `authorizedKeys` option + `/etc/ssh/authorized_keys` file + `AuthorizedKeysFile` updated to include it. README example shows `builtins.attrValues nix-ssh-config.sshKeys` pattern                              |
| 7   | **Duplicate code removal**         | Singular module aliases (`homeManagerModule`/`nixosModule`) removed in `e134229`                                                                                                                                   |
| 8   | **.gitignore**                     | Properly ignores private keys, allows `*.pub` tracking, standard IDE/OS/direnv ignores                                                                                                                             |
| 9   | **flake.lock**                     | Dependencies pinned to specific versions                                                                                                                                                                           |
| 10  | **Security defaults**              | Client: forwardAgent=false, addKeysToAgent=no, controlMaster=no. Server: PasswordAuth=false, PermitRootLogin=no, X11Forwarding=false, AllowTcpForwarding=false, MaxAuthTries=3, MaxSessions=2, modern ciphers only |

---

## b) PARTIALLY DONE

| #   | Item                     | Status                                           | What's Missing                                                                                                                                                                                                                                                                    |
| --- | ------------------------ | ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **README documentation** | Updated with `authorizedKeys` option and example | Still references `yourusername` instead of actual GitHub org/user. Missing documentation for all host submodule options (only table shows 6 of ~13 total options). `authorizedKeysFiles` default in table doesn't match actual default (missing `/etc/ssh/authorized_keys` entry) |

---

## c) NOT STARTED

| #   | Item                                                                                                                                                                                                         | Priority     | Effort |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------ | ------ |
| 1   | **LICENSE file** — README claims "MIT - See LICENSE file" but no LICENSE file exists                                                                                                                         | **Critical** | 2 min  |
| 2   | **Automated tests** — No `checks` output, no `nix flake check` tests, no evaluation tests                                                                                                                    | High         | 2 hr   |
| 3   | **CI pipeline** — No GitHub Actions workflow                                                                                                                                                                 | High         | 30 min |
| 4   | **README `authorizedKeysFiles` default mismatch** — Table shows `["%h/.ssh/authorized_keys"]` but actual default is `["%h/.ssh/authorized_keys" "/etc/ssh/authorized_keys.d/%u" "/etc/ssh/authorized_keys"]` | Medium       | 2 min  |
| 5   | **Hardcoded default user `"lars"`** — Should use `config.home.username` or have no default                                                                                                                   | Medium       | 5 min  |
| 6   | **Evaluate if `home-manager` input is needed** — Declared but never referenced in outputs                                                                                                                    | Medium       | 10 min |
| 7   | **Example configurations** — No `examples/` directory                                                                                                                                                        | Medium       | 30 min |
| 8   | **CHANGELOG.md**                                                                                                                                                                                             | Low          | 10 min |
| 9   | **CONTRIBUTING.md**                                                                                                                                                                                          | Low          | 15 min |
| 10  | **`.editorconfig`**                                                                                                                                                                                          | Low          | 5 min  |
| 11  | **Versioning/tags** — No git tags or releases                                                                                                                                                                | Low          | 15 min |
| 12  | **NixOS VM integration test**                                                                                                                                                                                | Medium       | 2 hr   |
| 13  | **Home Manager module test** — Verify generated `~/.ssh/config`                                                                                                                                              | Medium       | 1 hr   |
| 14  | **Extract banner text** — 12-line inline string in options default                                                                                                                                           | Low          | 10 min |
| 15  | **Document crypto algorithm choices**                                                                                                                                                                        | Low          | 15 min |
| 16  | **Additional SSH keys** — Only `lars.pub` exists                                                                                                                                                             | Low          | 2 min  |
| 17  | **nix-darwin server module** — `darwinModules` for macOS sshd                                                                                                                                                | Low          | 1 hr   |
| 18  | **age/sops-nix integration**                                                                                                                                                                                 | Low          | 2 hr   |
| 19  | **SSH config validation tool**                                                                                                                                                                               | Low          | 1 hr   |
| 20  | **CLI apps output** — Key rotation, config lint                                                                                                                                                              | Low          | 3 hr   |

---

## d) TOTALLY FUCKED UP

Nothing. Working tree is clean, master branch, all commits coherent. No broken state.

---

## e) WHAT WE SHOULD IMPROVE

### Critical

1. **Missing LICENSE file** — README says "MIT - See LICENSE file" but the file doesn't exist. This means the repo is technically all-rights-reserved by default copyright law, which contradicts the README claim and could deter users/contributors.

### High Impact

2. **No automated testing** — Zero tests exist. For a Nix flake with 527 lines of Nix code, adding `checks` outputs with module evaluation tests is trivial and would catch regressions immediately.
3. **No CI** — Pushes and PRs go unchecked. A single GitHub Actions workflow running `nix flake check` would provide a safety net.
4. **README table is inaccurate** — `authorizedKeysFiles` default doesn't match reality. This misleads users.
5. **`home-manager` input potentially unused** — Consumes lock space and closure size for no clear benefit.

### Medium Impact

6. **Hardcoded `user = "lars"`** — Makes the module less reusable for non-Lars users. Should default to `config.home.username`.
7. **Host submodule options underdocumented** — Only 6 options in README table, but the submodule has `hostname`, `user`, `port`, `identityFile`, `serverAliveInterval`, `serverAliveCountMax`, `extraOptions` (7 fields). README should list all.
8. **No `examples/` directory** — Ready-to-use configs would lower the barrier to entry significantly.
9. **Banner text inline** — 12-line default string bloats the option definition. Extract to a file or constant.
10. **`ssh-keys/` directory is minimal** — Only one key. Fine for now, but worth noting.

### Low Impact

11. **README GitHub URL placeholder** — `yourusername` should be actual org/user.
12. **No `.editorconfig`** — Minor consistency concern for contributors.
13. **No CHANGELOG** — Hard to track what changed between uses.
14. **No git tags** — No versioning scheme for consumers to pin against.

---

## f) Top 25 Things We Should Get Done Next

| #   | Task                                                                       | Priority     | Effort | Category      |
| --- | -------------------------------------------------------------------------- | ------------ | ------ | ------------- |
| 1   | Add MIT LICENSE file                                                       | **Critical** | 2 min  | Legal         |
| 2   | Fix README `authorizedKeysFiles` default value in table                    | **High**     | 2 min  | Docs          |
| 3   | Document all 7 host submodule options in README table                      | **High**     | 5 min  | Docs          |
| 4   | Add `checks` output to flake.nix (module evaluation tests)                 | **High**     | 1 hr   | Quality       |
| 5   | Add GitHub Actions CI workflow (`nix flake check`, `nix fmt --check`)      | **High**     | 30 min | CI            |
| 6   | Change default `user` from `"lars"` to `config.home.username`              | Medium       | 5 min  | Config        |
| 7   | Evaluate and potentially remove `home-manager` input                       | Medium       | 10 min | Cleanup       |
| 8   | Update README GitHub URL from `yourusername` to actual org                 | Medium       | 1 min  | Docs          |
| 9   | Add NixOS module evaluation test                                           | Medium       | 1 hr   | Testing       |
| 10  | Add Home Manager module evaluation test                                    | Medium       | 1 hr   | Testing       |
| 11  | Extract banner text to separate file or constant                           | Medium       | 10 min | Refactor      |
| 12  | Add example configurations in `examples/`                                  | Medium       | 30 min | Docs          |
| 13  | Add NixOS VM integration test (sshd starts, key auth works)                | Medium       | 2 hr   | Testing       |
| 14  | Add CONTRIBUTING.md                                                        | Low          | 15 min | Docs          |
| 15  | Add CHANGELOG.md                                                           | Low          | 10 min | Docs          |
| 16  | Add `.editorconfig`                                                        | Low          | 5 min  | Quality       |
| 17  | Add git versioning (v0.1.0 tag)                                            | Low          | 5 min  | Process       |
| 18  | Document crypto algorithm choices and review schedule                      | Low          | 15 min | Docs          |
| 19  | Add more SSH keys to `ssh-keys/` as needed                                 | Low          | 2 min  | Config        |
| 20  | Add `homeManagerModule` (singular) backward-compat alias or migration note | Low          | 5 min  | Compatibility |
| 21  | Consider nix-darwin server module (`darwinModules`)                        | Low          | 1 hr   | Feature       |
| 22  | Add SSH config syntax validation test                                      | Low          | 1 hr   | Testing       |
| 23  | Consider age/sops-nix integration for private key management               | Low          | 2 hr   | Feature       |
| 24  | Add `apps` output for CLI tools (key rotation, config lint)                | Low          | 3 hr   | Feature       |
| 25  | Add `nixosConfigurations` or `homeConfigurations` as example/demo outputs  | Low          | 30 min | Demo          |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Is the `home-manager` flake input needed, and if so, by whom?**

It's declared in `flake.nix:6-9` but never used in any output. The modules themselves only use standard module arguments (`config`, `lib`, `pkgs`). If downstream consumers are expected to use it as a shared input via `inputs.nix-ssh-config.inputs.home-manager.follows = "home-manager"`, it should stay. If nobody does that, it's dead weight adding ~150 entries to `flake.lock`. This is a product/ecosystem decision only the maintainer can make.

---

## File Inventory

```
.
├── .gitignore                    (23 lines)
├── README.md                     (188 lines) — updated this session
├── flake.lock                    (pinned deps)
├── flake.nix                     (45 lines)
├── docs/
│   └── status/
│       ├── 2026-04-04_01-49_comprehensive-status.md
│       └── 2026-04-04_02-21_comprehensive-status.md  ← this file
├── modules/
│   ├── home-manager/
│   │   └── ssh.nix               (139 lines)
│   └── nixos/
│       └── ssh.nix               (155 lines) — updated this session
└── ssh-keys/
    └── lars.pub                  (1 key)
```

**Total source lines:** 527 (Nix: 339, Markdown: 188)

---

## Commit History (Full)

| Hash      | Message                                                                   |
| --------- | ------------------------------------------------------------------------- |
| `8017855` | feat: add global authorizedKeys option for NixOS SSH server configuration |
| `1c327ec` | docs: add comprehensive project status report (2026-04-04)                |
| `e134229` | remove standalone module exports as they are no longer needed             |
| `fa07246` | feat: expose sshKeys as flake output for declarative key consumption      |
| `4650ca1` | fix: correct formatter output for per-system builds                       |
| `6d7d5a9` | chore: lock flake dependencies to specific versions                       |
| `624cf95` | feat: add treefmt-full-flake integration for formatting                   |
| `a7e5332` | Initial commit: Modular SSH configuration for Nix systems                 |

---

## Summary

Project is **healthy, clean, and growing**. This session added the `authorizedKeys` feature. The single most critical gap remains the missing LICENSE file. After that: fix README inaccuracies, add tests, add CI.
