# Examples

Ready-to-use module snippets. Copy them or import them directly — both are
exposed as flake outputs (`nix-ssh-config.examples.client`,
`nix-ssh-config.examples.server`) and are exercised by CI on every push.

| File         | Target       | Shows                                                                      |
| ------------ | ------------ | -------------------------------------------------------------------------- |
| `client.nix` | Home Manager | Hosts with user inheritance, jump host, X11, port forwarding, escape hatch |
| `server.nix` | NixOS        | Hardened-by-default server, allow-list, authorized keys, escape hatch      |

## Using an example directly

```nix
{
  inputs.nix-ssh-config.url = "github:LarsArtmann/nix-ssh-config";

  outputs = { self, nixpkgs, home-manager, nix-ssh-config }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-ssh-config.nixosModules.ssh
        nix-ssh-config.examples.server
      ];
    };

    homeConfigurations.you = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        nix-ssh-config.homeManagerModules.ssh
        nix-ssh-config.examples.client
      ];
    };
  };
}
```

See the [main README](../README.md) for the full option reference and the
crypto rationale.
