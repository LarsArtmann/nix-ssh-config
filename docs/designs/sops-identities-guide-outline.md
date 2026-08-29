# Guide outline v1: age / sops-nix identity files

**Status:** outline (guide not started) · **Theme:** 2 "Ecosystem integration" ·
**Refined:** 2026-08-29 (plan 3 M9)

Scope decided 2026-08-29 (unchanged): this flake ships a **guide + example
wiring**, never private keys and never a new module option. The public
flake output stays public; identities are the consumer's job.

## Outline

1. **Why this guide exists**
   - The flake configures the _server side_ and the _client defaults_;
     the client's private identity file is the one artifact left to the
     consumer.
   - Threat: identity files in plain text on disk; sops-nix/age encrypt
     them at rest and decrypt into a tmpfs/ramfs location at activation.

2. **Components**
   - `age` + `rage` (one is the reference, one is the Go reimplementation)
   - `sops-nix` (home-manager module or NixOS module — both exist)
   - identity/keys: `age-keygen`, master key placement, `.sops.yaml`
     creation rules

3. **Identity paths — the two placements** (the open question, made
   concrete):
   - **(a) NixOS-side:** `sops.secrets."id_ed25519".path` +
     `age.identityPaths = [ "/run/secrets/id_ed25519" ]` — right answer
     when the _host_ (deploy keys, root services) consumes the identity.
   - **(b) HM-side:** `sops.secrets."ssh/id_ed25519" = { path =
"${config.home.homeDirectory}/.ssh/id_ed25519"; };` in the HM module
     — right answer when the _user session_ consumes it; matches the
     `ssh-config.identityFile` default path.
   - Decision tree: does anything outside the user session need the key?
     yes → (a) with an explicit `ssh-config.identityFile` override; no →
     (b).

4. **Example wiring** (the guide's centerpiece)
   - `.sops.yaml` creation rules per host
   - HM module snippet: sops secret → `~/.ssh/id_ed25519` (0600), plus
     `ssh-config.enable = true` and `identityFile` pointing at the
     decrypted path
   - server side: authorizedKeys stays public — no sops needed there
     (this flake's `/etc/ssh/authorized_keys` is world-readable by
     design, mode 0444, see the StrictModes gotcha)

5. **Pitfalls**
   - sops secret path and `ssh-config` activation script ordering
     (`~/.ssh/sockets` creation) — both run at activation; no conflict
     observed, but re-verify with the first consumer
   - never point `identityFile` at the encrypted `.age`/`.sops` file
   - ramfs-backed decryption means the key is re-encrypted to disk on
     every boot — fine for clients, wrong for headless servers that
     must SSH out before login

6. **Acceptance criteria for the guide**
   - A consumer VM (downstream repo) boots with an sops-decrypted
     identity and completes a key login through the flake's client
     config.
   - No private material committed anywhere in this repo (gitleaks in
     CI already enforces).

## Open questions

- Name: guide lives in `docs/guide-sops-identities.md`?
- Version sops-nix input in the example (follows nixpkgs vs pinned)?
