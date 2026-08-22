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
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.treefmt-nix.flakeModule ];

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
          crypto = import ./modules/shared/crypto.nix { inherit lib; };
          banner = import ./modules/shared/banner.nix;

          # Throwaway ed25519 key generated for CI test evals only - never used
          # anywhere real. Regenerate freely: ssh-keygen -t ed25519 -C <comment>
          testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIFVoGCZ+Xlywmk19S5Z9DKF9VvEBU9CWvvz74GrqIfa nix-ssh-config-ci-test";

          # Nix string escapes have no \xNN form; JSON \u escapes produce the
          # raw control characters this eval deliberately injects.
          bannerWithControlChars = builtins.fromJSON ''"ok line\n\u0007bell\u0001soh"'';

          mkNixosEval =
            extraModules:
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                self.nixosModules.ssh
                {
                  boot.isContainer = true;
                  system.stateVersion = lib.mkDefault "25.05";
                  fileSystems."/".device = "/dev/null";
                  fileSystems."/".fsType = "ext4";
                }
              ]
              ++ extraModules;
            };

          nixosEval = mkNixosEval [
            {
              services.ssh-server = {
                enable = true;
                allowUsers = [ "testuser" ];
                authorizedKeys = [ testKey ];
              };
            }
          ];

          nixosBadBannerEval = mkNixosEval [
            {
              services.ssh-server = {
                enable = true;
                bannerText = bannerWithControlChars;
              };
            }
          ];

          # Custom port + extraSettings override in one eval: proves the
          # passthrough wiring, not just the defaults.
          nixosCustomEval = mkNixosEval [
            {
              services.ssh-server = {
                enable = true;
                port = 2222;
                extraSettings.LoginGraceTime = 42;
              };
            }
          ];

          # mkEnableOption defaults to false, so a bare eval is the disabled
          # state: the module must contribute nothing to openssh or /etc.
          nixosDisabledEval = mkNixosEval [ ];

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

          # programs.ssh.settings wraps every block in Home Manager's internal
          # { before, after, data, header } structure (same as matchBlocks);
          # the actual SSH directives live under .data. HM-internal: if HM
          # changes its representation, this helper is what needs updating.
          hmBlock = block: hmEval.config.programs.ssh.settings.${block}.data;

          # Attribute-equality assertions: compares Nix values directly instead
          # of grepping serialized JSON, so checks never break on formatting
          # drift. The comparison itself happens at eval time; any mismatch in
          # the list produces a derivation whose build fails listing every
          # mismatched field with its expected/actual diff.
          assertEq =
            label: checks:
            pkgs.runCommand "assert-${label}" { } (
              let
                failures = lib.filter (c: c.actual != c.expected) checks;
              in
              if failures == [ ] then
                "echo ok > $out"
              else
                ''
                  echo "FAIL: ${label}"
                  ${lib.concatStringsSep "\n" (
                    map (
                      c: ''echo "  ${c.name}: expected ${builtins.toJSON c.expected}, got ${builtins.toJSON c.actual}"''
                    ) failures
                  )}
                  exit 1
                ''
            );
        in
        {
          treefmt.programs.nixfmt.enable = true;

          checks = {
            nixos-module-evaluates = pkgs.runCommand "nixos-module-evaluates" { } ''
              ${builtins.deepSeq nixosEval.config.services.openssh.settings ""}
              echo ok > $out
            '';

            home-manager-module-evaluates = pkgs.runCommand "home-manager-module-evaluates" { } ''
              ${builtins.deepSeq hmEval.config.programs.ssh.settings ""}
              echo ok > $out
            '';

            hm-global-defaults = assertEq "hm-global-defaults" [
              {
                name = "User";
                actual = (hmBlock "*").User;
                expected = "test";
              }
              {
                name = "ForwardAgent";
                actual = (hmBlock "*").ForwardAgent;
                expected = "no";
              }
              {
                name = "AddKeysToAgent";
                actual = (hmBlock "*").AddKeysToAgent;
                expected = "no";
              }
              {
                name = "Compression";
                actual = (hmBlock "*").Compression;
                expected = "no";
              }
              {
                name = "ServerAliveInterval";
                actual = (hmBlock "*").ServerAliveInterval;
                expected = 60;
              }
              {
                name = "ServerAliveCountMax";
                actual = (hmBlock "*").ServerAliveCountMax;
                expected = 3;
              }
              {
                name = "ControlMaster";
                actual = (hmBlock "*").ControlMaster;
                expected = "no";
              }
              {
                name = "ControlPersist";
                actual = (hmBlock "*").ControlPersist;
                expected = "no";
              }
              {
                name = "HashKnownHosts";
                actual = (hmBlock "*").HashKnownHosts;
                expected = "no";
              }
              {
                name = "IdentityFile";
                actual = (hmBlock "*").IdentityFile;
                expected = "~/.ssh/id_ed25519";
              }
              {
                name = "KexAlgorithms";
                actual = (hmBlock "*").KexAlgorithms;
                expected = crypto.pqKexString;
              }
              {
                name = "Ciphers";
                actual = (hmBlock "*").Ciphers;
                expected = crypto.aeadCiphersString;
              }
              {
                name = "MACs";
                actual = (hmBlock "*").MACs;
                expected = crypto.etmMacsString;
              }
              {
                name = "HostKeyAlgorithms";
                actual = (hmBlock "*").HostKeyAlgorithms;
                expected = crypto.modernHostKeysString;
              }
              {
                name = "PubkeyAcceptedAlgorithms";
                actual = (hmBlock "*").PubkeyAcceptedAlgorithms;
                expected = crypto.modernHostKeysString;
              }
            ];

            hm-github-preset = assertEq "hm-github-preset" [
              {
                name = "User";
                actual = (hmBlock "github.com").User;
                expected = "git";
              }
              {
                name = "Compression";
                actual = (hmBlock "github.com").Compression;
                expected = "yes";
              }
              {
                name = "ControlMaster";
                actual = (hmBlock "github.com").ControlMaster;
                expected = "auto";
              }
              {
                name = "ControlPersist";
                actual = (hmBlock "github.com").ControlPersist;
                expected = "600";
              }
              {
                name = "TCPKeepAlive";
                actual = (hmBlock "github.com").TCPKeepAlive;
                expected = "yes";
              }
            ];

            nixos-password-auth-disabled = assertEq "password-auth-disabled" [
              {
                name = "PasswordAuthentication";
                actual = sshdSettings.PasswordAuthentication;
                expected = false;
              }
            ];

            nixos-root-login-disabled = assertEq "root-login-disabled" [
              {
                name = "PermitRootLogin";
                actual = sshdSettings.PermitRootLogin;
                expected = "no";
              }
            ];

            nixos-banner = assertEq "nixos-banner" [
              {
                name = "Banner path";
                actual = sshdSettings.Banner;
                expected = "/etc/ssh/banner";
              }
              {
                name = "/etc/ssh/banner text (must equal modules/shared/banner.nix)";
                actual = nixosEval.config.environment.etc."ssh/banner".text;
                expected = banner.defaultBannerText;
              }
            ];

            # Guards the documented NixOS settings quirk: Ciphers/Macs/
            # KexAlgorithms must be Nix lists (NixOS joins them), while the
            # freeform HostKeyAlgorithms/PubkeyAcceptedAlgorithms must be
            # pre-joined strings. If crypto.nix drifts or the forms get
            # swapped, this fails.
            nixos-crypto = assertEq "nixos-crypto" [
              {
                name = "Ciphers (list form)";
                actual = sshdSettings.Ciphers;
                expected = crypto.aeadCiphers;
              }
              {
                name = "Macs (list form)";
                actual = sshdSettings.Macs;
                expected = crypto.etmMacs;
              }
              {
                name = "KexAlgorithms (list form)";
                actual = sshdSettings.KexAlgorithms;
                expected = crypto.pqKex;
              }
              {
                name = "HostKeyAlgorithms (string form)";
                actual = sshdSettings.HostKeyAlgorithms;
                expected = crypto.modernHostKeysString;
              }
              {
                name = "PubkeyAcceptedAlgorithms (string form)";
                actual = sshdSettings.PubkeyAcceptedAlgorithms;
                expected = crypto.modernHostKeysString;
              }
              {
                name = "AuthorizedKeysFile (space-separated)";
                actual = sshdSettings.AuthorizedKeysFile;
                expected = "%h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u /etc/ssh/authorized_keys";
              }
            ];

            nixos-authorized-keys = assertEq "nixos-authorized-keys" [
              {
                name = "/etc/ssh/authorized_keys text";
                actual = nixosEval.config.environment.etc."ssh/authorized_keys".text;
                expected = testKey;
              }
            ];

            nixos-custom-settings = assertEq "nixos-custom-settings" [
              {
                name = "custom port reaches services.openssh.ports";
                actual = nixosCustomEval.config.services.openssh.ports;
                expected = [ 2222 ];
              }
              {
                name = "extraSettings overrides a default (LoginGraceTime)";
                actual = nixosCustomEval.config.services.openssh.settings.LoginGraceTime;
                expected = 42;
              }
            ];

            nixos-disabled-noop = assertEq "nixos-disabled-noop" [
              {
                name = "openssh stays disabled";
                actual = nixosDisabledEval.config.services.openssh.enable;
                expected = false;
              }
              {
                name = "no /etc/ssh/banner generated";
                actual = nixosDisabledEval.config.environment.etc ? "ssh/banner";
                expected = false;
              }
              {
                name = "no /etc/ssh/authorized_keys generated";
                actual = nixosDisabledEval.config.environment.etc ? "ssh/authorized_keys";
                expected = false;
              }
            ];

            format = config.treefmt.build.check self;
          }
          # Forcing config.assertions pulls in unrelated NixOS assertion
          # machinery that does not evaluate on darwin host platforms
          # (shadow et al.), so assertion checks run on Linux only.
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            nixos-module-assertions = assertEq "nixos-module-assertions" [
              {
                name = "default config satisfies all module assertions";
                actual = builtins.all (a: a.assertion) nixosEval.config.assertions;
                expected = true;
              }
              {
                name = "control-char banner is rejected";
                actual = builtins.any (
                  a: !a.assertion && lib.hasInfix "bannerText" a.message
                ) nixosBadBannerEval.config.assertions;
                expected = true;
              }
            ];
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = [ pkgs.nil ];
          };
        };
    };
}
