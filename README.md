# nix-ssh-config

[![Check](https://github.com/LarsArtmann/nix-ssh-config/actions/workflows/check.yml/badge.svg)](https://github.com/LarsArtmann/nix-ssh-config/actions/workflows/check.yml)
[![Release](https://img.shields.io/github/v/release/LarsArtmann/nix-ssh-config)](https://github.com/LarsArtmann/nix-ssh-config/releases)

Modular, reusable SSH configuration for Nix-based systems. Provides hardened SSH client and server configurations as Nix modules.

## Features

- **Cross-platform**: Works on both macOS (nix-darwin) and NixOS. Supported
  systems: `aarch64-darwin`, `x86_64-linux`, `aarch64-linux` (`x86_64-darwin`
  is excluded — deprecated in Nixpkgs 26.05). The client module configures
  macOS SSH; the server module is NixOS-only.
- **Modular**: Use only what you need - client config, server config, or both
- **Hardened**: Secure-by-default settings following best practices
- **Post-quantum ready**: ML-KEM hybrid key exchange for future-proof security

## Quick Start

### As a Flake Input

```nix
{
  inputs.nix-ssh-config.url = "github:LarsArtmann/nix-ssh-config";

  outputs = { self, nixpkgs, nix-ssh-config, ... }: {
    # For NixOS
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nix-ssh-config.nixosModules.ssh
        {
          services.ssh-server = {
            enable = true;
            allowUsers = [ "youruser" ];
          };
        }
      ];
    };

    # For Home Manager (Darwin or NixOS)
    homeConfigurations.youruser = home-manager.lib.homeManagerConfiguration {
      modules = [
        nix-ssh-config.homeManagerModules.ssh
        {
          ssh-config = {
            enable = true;
            hosts = {
              myserver = {
                hostname = "192.168.1.100";
                user = "admin";
              };
            };
          };
        }
      ];
    };
  };
}
```

### Nixpkgs Pinning

This flake tracks `nixpkgs/nixos-unstable` internally, but its modules are
pure configuration — they consume no packages from it, so the pin only
affects this repo's own CI checks. Two strategies for consumers:

1. **Recommended: let it float.** Add the input without `follows`. The
   modules are version-independent Nix expressions; nothing you build
   depends on this flake's nixpkgs.
2. **Conservative: pin everything to your nixpkgs.**
   `inputs.nix-ssh-config.inputs.nixpkgs.follows = "nixpkgs";` — only
   matters if you want the flake's _test evals_ to run against your exact
   nixpkgs revision.

Since the modules render `services.openssh.settings` / `programs.ssh.settings`
values, the OpenSSH version that actually matters is the one in **your**
system's nixpkgs — see the compatibility matrix below (≥ 9.9 for
post-quantum KEX).

## Module Reference

### Home Manager Module (`homeManagerModules.ssh`)

Configures SSH client settings via Home Manager.

#### Options

| Option                      | Type      | Default                | Description                    |
| --------------------------- | --------- | ---------------------- | ------------------------------ |
| `ssh-config.enable`         | bool      | `false`                | Enable SSH client config       |
| `ssh-config.user`           | str       | `config.home.username` | Default username               |
| `ssh-config.identityFile`   | str\|null | `"~/.ssh/id_ed25519"`  | Default SSH identity file path |
| `ssh-config.hosts`          | attrs     | `{}`                   | Host configurations            |
| `ssh-config.extraIncludes`  | list      | `[]`                   | Additional SSH config includes |
| `ssh-config.enableOrbstack` | bool      | `isDarwin`             | Include OrbStack config        |
| `ssh-config.enableColima`   | bool      | `isDarwin`             | Include Colima config          |

#### Host Submodule Options

| Option                | Type      | Default | Description                                                                           |
| --------------------- | --------- | ------- | ------------------------------------------------------------------------------------- |
| `hostname`            | str       | —       | Host IP or hostname                                                                   |
| `user`                | str\|null | `null`  | Username (defaults to `ssh-config.user`)                                              |
| `port`                | int\|null | `null`  | SSH port                                                                              |
| `identityFile`        | str\|null | `null`  | Path to identity file                                                                 |
| `certificateFile`     | str\|null | `null`  | Certificate file for this host (`CertificateFile`)                                    |
| `controlMaster`       | str\|null | `null`  | Per-host connection multiplexing (`ControlMaster`: `yes`/`no`/`auto`/`ask`/`autoask`) |
| `updateHostKeys`      | str\|null | `null`  | Accept rotated host keys (`UpdateHostKeys`: `yes`/`no`/`ask`)                         |
| `serverAliveInterval` | int\|null | `null`  | Keepalive interval (s)                                                                |
| `serverAliveCountMax` | int\|null | `null`  | Max keepalive probes                                                                  |
| `proxyJump`           | str\|null | `null`  | Jump host to route through (`ProxyJump`)                                              |
| `forwardX11`          | bool      | `false` | Forward X11 for this host (`ForwardX11 yes`)                                          |
| `localForwards`       | [forward] | `[]`    | Local port forwardings (`LocalForward`)                                               |
| `remoteForwards`      | [forward] | `[]`    | Remote port forwardings (`RemoteForward`)                                             |
| `dynamicForwards`     | [address] | `[]`    | Dynamic SOCKS forwardings (`DynamicForward`)                                          |
| `extraOptions`        | attrs     | `{}`    | Additional SSH options                                                                |

A **forward** is `{ bind = { address ?, port }; host = { address ?, port }; }`
and an **address** is `{ address ? = "localhost", port }`. The structured
shapes are handed to Home Manager's renderer, which emits valid
`LocalForward [bind]:port [host]:port` lines and repeats the directive per
list element:

```nix
ssh-config.hosts.myserver = {
  hostname = "10.0.0.5";
  proxyJump = "bastion.example.com";
  localForwards = [
    {
      bind.port = 8080;
      host.address = "10.0.0.13";
      host.port = 80;
    }
  ];
  dynamicForwards = [ { port = 1080; } ];
};
```

#### Example

```nix
{
  ssh-config = {
    enable = true;
    hosts = {
      webserver = {
        hostname = "203.0.113.10";
        user = "deploy";
        serverAliveInterval = 60;
      };
      # user inherits from ssh-config.user (defaults to home.username)
      backup = {
        hostname = "192.168.1.50";
      };
    };
  };
}
```

### NixOS Module (`nixosModules.ssh`)

Configures OpenSSH server (sshd) with hardening.

#### Options

| Option                                             | Type       | Default                  | Description                                                                                                                                  |
| -------------------------------------------------- | ---------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `services.ssh-server.enable`                       | bool       | `false`                  | Enable SSH server                                                                                                                            |
| `services.ssh-server.port`                         | int        | `22`                     | Listen port                                                                                                                                  |
| `services.ssh-server.listenAddresses`              | list       | `[]`                     | `{ addr, port ? }` addresses to bind; empty listens on all interfaces at `port`; non-empty overrides the plain port binding                  |
| `services.ssh-server.usePam`                       | bool\|null | `null`                   | PAM authentication (`null` = NixOS default `true`; `false` = PAM-free host); only matters with `kbdInteractiveAuthentication = true` for 2FA |
| `services.ssh-server.authenticationMethods`        | str\|null  | `null`                   | `AuthenticationMethods` directive; commas chain methods in sequence, e.g. `publickey,keyboard-interactive` for two-factor auth               |
| `services.ssh-server.allowUsers`                   | list       | `[]`                     | Allowed users                                                                                                                                |
| `services.ssh-server.allowRootLogin`               | bool       | `false`                  | Allow root login                                                                                                                             |
| `services.ssh-server.passwordAuthentication`       | bool       | `false`                  | Allow passwords                                                                                                                              |
| `services.ssh-server.kbdInteractiveAuthentication` | bool       | `passwordAuthentication` | Allow keyboard-interactive (defaults to follow `passwordAuthentication`; set `true` explicitly for PAM-backed 2FA)                           |
| `services.ssh-server.authorizedKeys`               | list       | `[]`                     | SSH public keys to authorize (file is **copied** into `/etc`, not symlinked — sshd StrictModes rejects store symlinks)                       |
| `services.ssh-server.authorizedKeysFiles`          | list       | (see below)              | Key file paths                                                                                                                               |
| `services.ssh-server.extraSettings`                | attrs      | `{}`                     | Extra OpenSSH settings                                                                                                                       |
| `services.ssh-server.bannerText`                   | str\|null  | default banner           | SSH banner (null to disable; control characters are rejected at evaluation time)                                                             |

Default `authorizedKeysFiles`:

```
["%h/.ssh/authorized_keys" "/etc/ssh/authorized_keys.d/%u" "/etc/ssh/authorized_keys"]
```

#### Example

```nix
{
  services.ssh-server = {
    enable = true;
    port = 2222;
    allowUsers = [ "admin" "deploy" ];
    authorizedKeys = [
      "ssh-ed25519 AAAA... user@host"
    ];
    allowRootLogin = false;
    passwordAuthentication = false;
  };
}
```

Or use keys from the flake output:

```nix
{
  inputs.nix-ssh-config.url = "github:LarsArtmann/nix-ssh-config";

  outputs = { self, nixpkgs, nix-ssh-config, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        nix-ssh-config.nixosModules.ssh
        {
          services.ssh-server = {
            enable = true;
            authorizedKeys = builtins.attrValues nix-ssh-config.sshKeys;
          };
        }
      ];
    };
  };
}
```

## Security Defaults

### Server Hardening

- Password authentication disabled (keys only)
- Keyboard-interactive authentication disabled with passwords (defaults to
  `passwordAuthentication`): `PasswordAuthentication no` alone is not
  keys-only — NixOS defaults `KbdInteractiveAuthentication yes` (with
  `UsePAM yes`), which keeps a PAM-serviced prompt channel open (OTP/2FA
  modules, or Unix account passwords wherever the sshd PAM service permits
  them). Set `services.ssh-server.kbdInteractiveAuthentication = true`
  explicitly if you run PAM-backed two-factor authentication.
- Root login disabled
- **Post-quantum key exchange**: `mlkem768x25519-sha256` (ML-KEM hybrid, NIST FIPS 203)
- AEAD ciphers only: ChaCha20-Poly1305, AES-GCM
- Encrypt-then-MAC only (no encrypt-and-MAC)
- Ed25519 preferred host key algorithm
- Connection limits (MaxAuthTries=3, MaxSessions=2, LoginGraceTime=30)
- X11 and TCP forwarding disabled
- Verbose logging
- Legal banner displayed

### Client Defaults

- **Post-quantum key exchange**: `mlkem768x25519-sha256` prioritized
- **Ed25519 identity**: `~/.ssh/id_ed25519` as default key
- AEAD ciphers and encrypt-then-MAC MACs only
- Ed25519 preferred for host key verification
- Keepalive every 60s
- Control master disabled by default
- Agent forwarding disabled
- Compression disabled by default
- GitHub optimized settings with connection pooling

### OpenSSH Version Compatibility

Every row verified against the upstream release notes (openssh.com/txt/release-\*).

| Algorithm                       | Min OpenSSH | Upstream default behavior                                                                                                         |
| ------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `mlkem768x25519-sha256`         | 9.9         | Enabled by default since 9.9; the client's first preference since 10.0                                                            |
| `sntrup761x25519-sha512`        | 8.5         | Disabled by default upstream — this flake enables it explicitly (both the `@openssh.com` name and this IANA alias are configured) |
| `curve25519-sha256@libssh.org`  | 6.5         | Default KEX when both sides support it                                                                                            |
| `curve25519-sha256` (IANA name) | 7.4         | Identical method to the `@libssh.org` name                                                                                        |
| `chacha20-poly1305@openssh.com` | 6.5         | First-preference cipher since 6.5, still first in 10.0                                                                            |
| `ssh-ed25519`                   | 6.5         | First-preference host/user key type since 8.5                                                                                     |
| `rsa-sha2-256/512`              | 7.2         | Used automatically for RSA keys when both sides support                                                                           |

Sources: 6.5 (2014-01-30, curve25519/ed25519/chacha20), 7.2 (rsa-sha2), 7.4 (2016-12-19, `curve25519-sha256` name), 8.5 (2021-03-03, sntrup761 — "disabled by default"), 9.9 (2024-09-19, ML-KEM — "available by default"), 10.0 (2025-04-09, ML-KEM "used by default for key agreement").

Because this flake pins explicit `KexAlgorithms`/`Ciphers`/`MACs` lists, clients and servers configured by it negotiate the post-quantum algorithms first on any OpenSSH ≥ 9.9 regardless of upstream preference order. Servers running OpenSSH < 6.5 (released 2014) cannot connect.

### Post-Quantum Status

| Area                    | Status        | Timeline                                              |
| ----------------------- | ------------- | ----------------------------------------------------- |
| Key exchange (ML-KEM)   | Deployed      | Complete                                              |
| Authentication (ML-DSA) | Not available | IETF draft exists, no OpenSSH implementation timeline |

## Crypto Algorithm Rationale

All algorithm choices follow a **conservative + post-quantum** strategy:

- **Key Exchange**: ML-KEM hybrid (`mlkem768x25519-sha256`) as primary — NIST FIPS 203 standard, protects against "harvest now, decrypt later" attacks. Falls back to NTRU Prime hybrid, then pure Curve25519.
- **Ciphers**: AEAD-only (ChaCha20-Poly1305, AES-256/128-GCM) — authenticated encryption eliminates separate MAC vulnerabilities. No CBC mode.
- **MACs**: Encrypt-then-MAC only — prevents padding oracle attacks that are possible with encrypt-and-MAC. No HMAC-MD5 or HMAC-SHA1.
- **Host Keys**: Ed25519 preferred (128-bit security, small keys, constant-time). RSA-SHA2 accepted for compatibility. No DSA or RSA-SHA1.
- **Threat Model**: Passive network adversaries with future quantum computers (KEX), classical MITM and replay attacks (AEAD+ETM), weak legacy algorithm downgrade attacks (modern-only lists).

## Directory Structure

```
.
├── flake.nix                      # Flake entry point (flake-parts)
├── modules/
│   ├── shared/
│   │   ├── crypto.nix             # Shared cryptographic algorithm definitions
│   │   └── banner.nix             # Default legal banner constant
│   ├── home-manager/
│   │   └── ssh.nix                # Client configuration
│   └── nixos/
│       └── ssh.nix                # Server configuration
├── examples/                      # Copy-ready client/server modules (flake outputs)
├── tests/                         # Throwaway keypair for eval fixtures + VM test
├── ssh-keys/                      # Tracked public keys (private keys are gitignored)
│   ├── lars-ed25519.pub
│   └── lars-evo-x2-ed25519.pub
└── .github/workflows/check.yml    # CI
```

## License

MIT — See [LICENSE](LICENSE) file.
