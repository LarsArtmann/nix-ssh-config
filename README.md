# nix-ssh-config

Modular, reusable SSH configuration for Nix-based systems. Provides hardened SSH client and server configurations as Nix modules.

## Features

- **Cross-platform**: Works on both macOS (nix-darwin) and NixOS
- **Modular**: Use only what you need - client config, server config, or both
- **Hardened**: Secure-by-default settings following best practices
- **Post-quantum ready**: ML-KEM hybrid key exchange for future-proof security

## Quick Start

### As a Flake Input

```nix
{
  inputs.nix-ssh-config.url = "github:yourusername/nix-ssh-config";

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

## Module Reference

### Home Manager Module (`homeManagerModules.ssh`)

Configures SSH client settings via Home Manager.

#### Options

| Option                      | Type  | Default    | Description                    |
| --------------------------- | ----- | ---------- | ------------------------------ |
| `ssh-config.enable`         | bool  | `false`    | Enable SSH client config       |
| `ssh-config.user`           | str   | `"lars"`   | Default username               |
| `ssh-config.hosts`          | attrs | `{}`       | Host configurations            |
| `ssh-config.extraIncludes`  | list  | `[]`       | Additional SSH config includes |
| `ssh-config.enableOrbstack` | bool  | `isDarwin` | Include OrbStack config        |
| `ssh-config.enableColima`   | bool  | `isDarwin` | Include Colima config          |

#### Example

```nix
{
  ssh-config = {
    enable = true;
    user = "admin";
    hosts = {
      webserver = {
        hostname = "203.0.113.10";
        user = "deploy";
        serverAliveInterval = 60;
      };
      github = {
        hostname = "github.com";
        user = "git";
        compression = true;
      };
    };
  };
}
```

### NixOS Module (`nixosModules.ssh`)

Configures OpenSSH server (sshd) with hardening.

#### Options

| Option                                       | Type  | Default                       | Description                  |
| -------------------------------------------- | ----- | ----------------------------- | ---------------------------- |
| `services.ssh-server.enable`                 | bool  | `false`                       | Enable SSH server            |
| `services.ssh-server.port`                   | int   | `22`                          | Listen port                  |
| `services.ssh-server.allowUsers`             | list  | `[]`                          | Allowed users                |
| `services.ssh-server.allowRootLogin`         | bool  | `false`                       | Allow root login             |
| `services.ssh-server.passwordAuthentication` | bool  | `false`                       | Allow passwords              |
| `services.ssh-server.authorizedKeys`        | list  | `[]`                          | SSH public keys to authorize |
| `services.ssh-server.authorizedKeysFiles`    | list  | `["%h/.ssh/authorized_keys"]` | Key file paths               |
| `services.ssh-server.extraSettings`          | attrs | `{}`                          | Extra OpenSSH settings       |
| `services.ssh-server.bannerText`             | str   | default banner                | SSH banner (null to disable) |

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
  inputs.nix-ssh-config.url = "github:yourusername/nix-ssh-config";

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
- Root login disabled
- **Post-quantum key exchange**: `mlkem768x25519-sha256` (ML-KEM hybrid, NIST FIPS 203)
- AEAD ciphers only: ChaCha20-Poly1305, AES-GCM
- Encrypt-then-MAC only (no encrypt-and-MAC)
- Ed25519 preferred host key algorithm
- Connection limits (MaxAuthTries=3, MaxSessions=2)
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

## Directory Structure

```
.
├── flake.nix                 # Flake entry point
├── modules/
│   ├── home-manager/
│   │   └── ssh.nix          # Client configuration
│   └── nixos/
│       └── ssh.nix          # Server configuration
└── ssh-keys/
    └── lars-ed25519.pub     # Ed25519 public key
```

## License

MIT - See LICENSE file
