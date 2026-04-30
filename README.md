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

| Option                | Type      | Default | Description            |
| --------------------- | --------- | ------- | ---------------------- |
| `hostname`            | str       | —       | Host IP or hostname    |
| `user`                | str       | —       | Username for this host |
| `port`                | int\|null | `null`  | SSH port               |
| `identityFile`        | str\|null | `null`  | Path to identity file  |
| `serverAliveInterval` | int\|null | `null`  | Keepalive interval (s) |
| `serverAliveCountMax` | int\|null | `null`  | Max keepalive probes   |
| `extraOptions`        | attrs     | `{}`    | Additional SSH options |

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
    };
  };
}
```

### NixOS Module (`nixosModules.ssh`)

Configures OpenSSH server (sshd) with hardening.

#### Options

| Option                                       | Type      | Default        | Description                  |
| -------------------------------------------- | --------- | -------------- | ---------------------------- |
| `services.ssh-server.enable`                 | bool      | `false`        | Enable SSH server            |
| `services.ssh-server.port`                   | int       | `22`           | Listen port                  |
| `services.ssh-server.allowUsers`             | list      | `[]`           | Allowed users                |
| `services.ssh-server.allowRootLogin`         | bool      | `false`        | Allow root login             |
| `services.ssh-server.passwordAuthentication` | bool      | `false`        | Allow passwords              |
| `services.ssh-server.authorizedKeys`         | list      | `[]`           | SSH public keys to authorize |
| `services.ssh-server.authorizedKeysFiles`    | list      | (see below)    | Key file paths               |
| `services.ssh-server.extraSettings`          | attrs     | `{}`           | Extra OpenSSH settings       |
| `services.ssh-server.bannerText`             | str\|null | default banner | SSH banner (null to disable) |

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

### OpenSSH Version Compatibility

| Algorithm                | Min OpenSSH | Status             |
| ------------------------ | ----------- | ------------------ |
| `mlkem768x25519-sha256`  | 9.9         | Default since 10.0 |
| `sntrup761x25519-sha512` | 8.5         | Widely available   |
| `curve25519-sha256`      | 6.5         | Universal          |
| `chacha20-poly1305`      | 6.5         | Universal          |

Servers running OpenSSH < 6.5 (released 2014) will not be able to connect.

### Post-Quantum Status

| Area                    | Status        | Timeline                                              |
| ----------------------- | ------------- | ----------------------------------------------------- |
| Key exchange (ML-KEM)   | Deployed      | Complete                                              |
| Authentication (ML-DSA) | Not available | IETF draft exists, no OpenSSH implementation timeline |

## Directory Structure

```
.
├── flake.nix                 # Flake entry point
├── modules/
│   ├── shared/
│   │   └── crypto.nix        # Shared cryptographic algorithm definitions
│   ├── home-manager/
│   │   └── ssh.nix           # Client configuration
│   └── nixos/
│       └── ssh.nix           # Server configuration
└── ssh-keys/
    └── lars-ed25519.pub      # Ed25519 public key
```

## License

MIT — See [LICENSE](LICENSE) file.
