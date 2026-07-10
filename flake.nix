{
  description = "Modular, hardened SSH client & server configurations for NixOS and nix-darwin — secure by default, post-quantum ready";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } [
      inputs.treefmt-nix.flakeModule
      {
        systems = builtins.filter (s: s != "x86_64-darwin") (import inputs.nix-systems);

        flake = {
          homeManagerModules.ssh = import ./modules/home-manager/ssh.nix;
          nixosModules.ssh = import ./modules/nixos/ssh.nix;
          sshKeys = {
            lars = builtins.readFile ./ssh-keys/lars-ed25519.pub;
            lars-evo-x2 = builtins.readFile ./ssh-keys/lars-evo-x2-ed25519.pub;
          };
        };

        perSystem =
          {
            pkgs,
            system,
            config,
            lib,
            ...
          }:
          let
            testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/uqxUhFQpJaBq+dDd+shObEjKm8YOPimFx7XHgqTFJ lars@Lars-MacBook-Air-2026-04";

            nixosEval = nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.ssh
                {
                  services.ssh-server = {
                    enable = true;
                    allowUsers = [ "testuser" ];
                    authorizedKeys = [ testKey ];
                  };
                  boot.isContainer = true;
                  system.stateVersion = lib.mkDefault "25.05";
                  fileSystems."/".device = "/dev/null";
                }
              ];
            };

            mkHmEval =
              extraModules:
              home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                modules = [ self.homeManagerModules.ssh ] ++ extraModules;
              };

            hmEval = mkHmEval [
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

            sshdSettings = nixosEval.config.services.openssh.settings;

            assertContains =
              label: text: substr:
              pkgs.runCommand "assert-${label}" { } ''
                printf '%s' ${lib.escapeShellArg text} | grep -qF ${lib.escapeShellArg substr} || (
                  echo "FAIL: ${label}"
                  echo "Expected to find: ${substr}"
                  exit 1
                )
                echo ok > $out
              '';
          in
          {
            treefmt.programs.nixfmt.enable = true;

            checks = {
              nixos-module-evaluates = pkgs.runCommand "nixos-module-evaluates" { } ''
                ${builtins.deepSeq nixosEval.config.services.openssh.settings ""}
                echo ok > $out
              '';

              home-manager-module-evaluates = pkgs.runCommand "home-manager-module-evaluates" { } ''
                ${builtins.deepSeq hmEval.config.programs.ssh.matchBlocks ""}
                echo ok > $out
              '';

              nixos-password-auth-disabled = assertContains
                "password-auth-disabled"
                (builtins.toJSON sshdSettings)
                ''"PasswordAuthentication":false'';

              nixos-root-login-disabled = assertContains
                "root-login-disabled"
                (builtins.toJSON sshdSettings)
                ''"PermitRootLogin":"no"'';

              format = config.treefmt.build.check self;
            };

            devShells.default = pkgs.mkShellNoCC {
              packages = [ pkgs.nil ];
            };
          };
      }
    ];
}
