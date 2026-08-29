# Design: Home Manager client module inside the NixOS VM

**Status:** design (not started) · **Theme:** 3 "Test depth" ·
**Refined:** 2026-08-29 (plan 3 M9) · **Estimated:** ~3–4h once approved

## Goal

The VM integration test currently boots a NixOS VM with a plain
`pkgs.openssh` client and asserts the server module's runtime behavior.
The client-side module (`homeManagerModules.ssh`, `ssh-config.*`) is only
proven by eval checks and `ssh -G` against the rendered file — not by a
real login performed **with the module's own rendered config**. This
design closes that gap: the VM client node consumes
`homeManagerModules.ssh` and every client subtest uses the generated
`~/.ssh/config`.

## Shape

```nix
# tests/checks.nix — VM client node (sketch)
nodes.client = { pkgs, lib, ... }: {
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  home-manager.useUserPackages = true;
  home-manager.users.client = {
    imports = [ self.homeManagerModules.ssh ];
    home.username = "client";
    home.homeDirectory = "/home/client";
    home.stateVersion = "25.05";
    ssh-config = {
      enable = true;
      user = "client";
      hosts.test = {
        hostname = "server";
        identityFile = "/home/client/.ssh/test_key";
      };
    };
  };
  users.users.client = {
    isNormalUser = true;
    description = "HM-driven VM client";
  };
};
```

Subtests change from `ssh -o … testuser@server` to
`su - client -c "ssh test"` (or `sudo -u client ssh test`), so the
connection is driven by the module's output, options `Host`-block
matching, control-socket paths (`~/.ssh/sockets`, created by the
module's activation script) and all defaults.

## Cost

- New VM dependency: `home-manager.nixosModules.home-manager` adds the
  HM module tree + activation to the client node (~+100MB closure,
  +10–20s boot/activate). The kbd-server and server nodes are untouched.
- The test driver type-checks/lints grow slightly (bigger script).
- CI stays single-job: still one x86_64 VM check, no new gates.

## Alternatives considered

1. **home-manager as a NixOS module inside all nodes** — rejected for
   server nodes: the server module is NixOS-native already; HM there is
   dead weight.
2. **Standalone HM VM (home-manager standalone + QEMU)** — rejected:
   standalone HM VMs are not a supported tester target; NixOS-module
   integration is the standard path.
3. **Render-and-copy only** (copy the rendered `~/.ssh/config` into a
   plain VM) — cheaper, but bypasses the HM activation script
   (`~/.ssh/sockets` mode 700), which is exactly the part that has
   broken in HM upstream before. Rejected as a fake proof.

## Preconditions / risks

- `inputs.home-manager` is already a flake input (used by evals) — no
  new input.
- The HM module requires `home.stateVersion`; assert a warning-free
  eval (state-version discipline already used in the eval fixtures).
- Kill-switch plan for the new subtests: tamper the rendered
  `ssh-config.hosts.test.port` (e.g. point it at 2299) → login must
  fail → restore. A test that cannot fail is decoration.

## Follow-ups

- Migrate the `ssh -Q` and negotiated-kex subtests to the HM client.
- Keep the existing BatchMode subtests as the no-HM control path.
