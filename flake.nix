{
  description = "Nix SSH configuration - Cross-platform SSH client and server configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-full-flake.url = "github:LarsArtmann/treefmt-full-flake";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    treefmt-full-flake,
    ...
  }: let
    # Supported systems
    systems = ["aarch64-darwin" "x86_64-linux" "x86_64-darwin" "aarch64-linux"];

    # Helper to generate per-system outputs
    forEachSystem = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
        });
  in {
    # Home Manager module for SSH client configuration
    homeManagerModules.ssh = import ./modules/home-manager/ssh.nix;

    # NixOS module for SSH server (sshd) configuration
    nixosModules.ssh = import ./modules/nixos/ssh.nix;

    # Public SSH keys (exposed as flake output for consumers)
    sshKeys = {
      lars = builtins.readFile ./ssh-keys/lars.pub;
      lars-ed25519 = builtins.readFile ./ssh-keys/lars-ed25519.pub;
    };

    # Formatting via treefmt-full-flake (per-system)
    formatter = forEachSystem ({pkgs, ...}: treefmt-full-flake.formatter.${pkgs.stdenv.hostPlatform.system});
  };
}
