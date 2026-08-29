# DRAFT: home-manager — `programs.ssh.knownHosts`

**Status: DRAFT — do NOT file before re-running the verification table
against current master on the day of filing** (verify-before-filing:
the draft below was verified against a 2026-08-29 snapshot only).

## Why

NixOS has `programs.ssh.knownHosts` to manage the system-wide
`/etc/ssh/known_hosts`, but Home Manager has no per-user equivalent.
Users who live entirely in Home Manager (non-NixOS hosts, dotfiles-only
setups) must hand-manage `~/.ssh/known_hosts` or shell out an
activation script. Our own flake (nix-ssh-config) had to park a
`knownHosts` passthrough because the pinned HM lacks the option
(ROADMAP theme 5).

## Proposed shape

Mirror NixOS's option under `programs.ssh`:

```nix
programs.ssh.knownHosts."github.com".publicKey =
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
programs.ssh.knownHosts."*.corp".extraHostNames = [ "git.corp" ];
```

rendering into a generated `~/.ssh/known_hosts` (wired next to
`~/.ssh/config`, replacing the file or via `Include` — design detail
for the PR discussion).

## Verification table (re-verify before filing)

| Date            | Target                                                                                                 | Method                                       | Result                                                                                                                                                                 |
| --------------- | ------------------------------------------------------------------------------------------------------ | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-08-29      | HM pinned `99c9ec63390f1d8c14d95d9e8b17cc29cfbd4e11` (~master, 2026-08-27), `modules/programs/ssh.nix` | read full source (raw.githubusercontent.com) | **no `knownHosts` option exists** — options are: enable, package, extraConfig, extraOptionOverrides, includes, settings, matchBlocks (deprecated), enableDefaultConfig |
| 2026-08-29      | HM issue/PR search (`gh search` issues+prs "knownHosts" / "known hosts")                               | GitHub search API                            | no prior or competing request found (PR 7655 "remove top level options" and CI bumps are unrelated)                                                                    |
| TODO filing day | HM master `modules/programs/ssh.nix`                                                                   | re-read raw source                           | _fill in_                                                                                                                                                              |
| TODO filing day | HM search                                                                                              | re-run searches                              | _fill in_                                                                                                                                                              |

## Filing target

nix-community/home-manager issue first (feature discussion), PR after a
maintainer signals the option shape. Reference NixOS's
`programs.ssh.knownHosts.*` (nixpkgs `nixos/modules/programs/ssh.nix`)
as the parity target.
