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
  }: {
    # Home Manager module for SSH client configuration
    homeManagerModules.ssh = import ./modules/home-manager/ssh.nix;

    # NixOS module for SSH server (sshd) configuration
    nixosModules.ssh = import ./modules/nixos/ssh.nix;

    # Standalone module exports (for direct use)
    homeManagerModule = self.homeManagerModules.ssh;
    nixosModule = self.nixosModules.ssh;

    # Formatting via treefmt-full-flake
    formatter = treefmt-full-flake.outputs.formatter { inherit nixpkgs; };
  };
}
