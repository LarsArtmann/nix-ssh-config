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
    systems = ["aarch64-darwin" "x86_64-linux" "x86_64-darwin" "aarch64-linux"];

    forEachSystem = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
        });
  in {
    homeManagerModules.ssh = import ./modules/home-manager/ssh.nix;

    nixosModules.ssh = import ./modules/nixos/ssh.nix;

    sshKeys = {
      lars = builtins.readFile ./ssh-keys/lars-ed25519.pub;
    };

    checks = forEachSystem ({
      system,
      pkgs,
    }: let
      testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/uqxUhFQpJaBq+dDd+shObEjKm8YOPimFx7XHgqTFJ lars@Lars-MacBook-Air-2026-04";

      nixosEval = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          self.nixosModules.ssh
          {
            services.ssh-server = {
              enable = true;
              allowUsers = ["testuser"];
              authorizedKeys = [testKey];
            };
            boot.isContainer = true;
            fileSystems."/".device = "/dev/null";
          }
        ];
      };

      hmEval = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          self.homeManagerModules.ssh
          {
            ssh-config = {
              enable = true;
              hosts.test = {
                hostname = "example.com";
                user = "admin";
              };
            };
            home.username = "test";
            home.homeDirectory = "/home/test";
            home.stateVersion = "25.05";
          }
        ];
      };
    in {
      nixos-module-evaluates = pkgs.runCommand "nixos-module-evaluates" {} ''
        ${builtins.deepSeq nixosEval.config.environment.etc."ssh/authorized_keys".text ""}
        echo ok > $out
      '';

      home-manager-module-evaluates = pkgs.runCommand "home-manager-module-evaluates" {} ''
        ${builtins.deepSeq hmEval.config.programs.ssh.matchBlocks ""}
        echo ok > $out
      '';
    });

    devShells = forEachSystem ({pkgs, ...}: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          nil
        ];
      };
    });

    formatter = forEachSystem ({pkgs, ...}: treefmt-full-flake.formatter.${pkgs.stdenv.hostPlatform.system});
  };
}
