# Design: host `match` blocks (conditional client blocks)

**Status:** design (not started) · **Theme:** 5 "Module surface candidates" ·
**Refined:** 2026-08-29 (plan 3 M9) · **Estimated:** ~4h incl. tests

## Goal

Let a consumer express ssh_config `Match` blocks (conditional
configuration: per-network settings, `exec` gates, tagged hosts) as
typed options instead of `extraOptions`/`extraConfig` escapes, while
keeping the current `ssh-config.hosts.*` shape untouched.

## Option shape

```nix
ssh-config.matchBlocks.corp-vpn = {
  # Typed conditions, rendered in sshd's documented order:
  conditions = {
    host = "*.corp.example.org";
    # all = true; final = true; localuser = "admin";
    # exec = "test -n \"$SSH_VPN\"";   # free-form escape, last resort
  };
  options = {
    # Reuse the SAME submodule as hosts.* (single source: one type, two
    # consumers). Only directives legal inside Match blocks are emitted.
    identityFile = "~/.ssh/corp_key";
    proxyJump = "bastion";
  };
};
```

- Type: `attrsOf (submodule { conditions = …; options = hosts.*.type; })`.
- `conditions` mirrors ssh_config(5) `Match` keywords (host, originalhost,
  user, localuser, exec, all, final) as `nullOr str` / bool fields, with
  the "at least one condition" assertion.
- The `options` submodule is reused from `hosts.*` by extracting the
  existing type into a named `let` binding in the module — no duplicate
  definition (split-brain guard).

## Rendering order (the dangerous part)

ssh_config is first-match-wins for most directives and `Match` blocks
evaluate in file order. The module therefore renders in a fixed,
documented order:

1. `Host *` global defaults (existing behavior)
2. `Host github.com` preset (existing behavior)
3. user `hosts.*` blocks (sorted, existing behavior)
4. user `matchBlocks.*` last — Match blocks must not shadow earlier
   Host blocks unintentionally; docs state that consumers get
   first-match-wins control through this fixed order.

If later demanded, an explicit `lib.hm.dag`-style ordering knob is the
escape hatch — NOT a v1 feature (YAGNI).

## Match keyword caveats (from ssh_config(5) / OpenSSH 9.8+)

- `Match final`/`Match canonical` are keywords, not host patterns — the
  renderer must emit them bare (`Match final`), never quoted/expanded.
- `Match exec` runs a shell command; the string is passed verbatim (no
  Nix escaping beyond the normal line render).
- Inside a Match block, `Hostname`/`ProxyJump` etc. behave as
  first-value-wins like everywhere else; but `Match` cannot nest —
  an assertion rejects `conditions` in `hosts.*` and vice versa.
- Older OpenSSH (before ~7.3?) lacks some keywords; the README
  compatibility matrix gains a footnote listing the minimum for each
  supported keyword.

## Testing plan

- Eval: rendered-config assertions (`hm-rendered-config`) pin `Match`
  line text and block placement (last).
- Eval: unknown-condition assertion red; empty-conditions assertion red.
- VM (after the HM-in-NixOS-VM design lands): a `Match host` block
  proves first-match-wins against a `Host` block.
- Kill-switch: flip the rendered block order → hm-rendered-config red.

## Non-goals (v1)

- `ProxyCommand`/`exec` escaping helpers.
- Per-match-block `Include` handling.
- Ordering knobs.
