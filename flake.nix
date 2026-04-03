{
  description = "Nix SSH configuration - Cross-platform SSH client and server configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  }: {
    # Home Manager module for SSH client configuration
    homeManagerModules.ssh = import ./modules/home-manager/ssh.nix;

    # NixOS module for SSH server (sshd) configuration
    nixosModules.ssh = import ./modules/nixos/ssh.nix;

    # Standalone module exports (for direct use)
    homeManagerModule = self.homeManagerModules.ssh;
    nixosModule = self.nixosModules.ssh;
  };
}
