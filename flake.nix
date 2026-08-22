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
        examples = {
          client = import ./examples/client.nix;
          server = import ./examples/server.nix;
        };
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
              modules = [
                self.homeManagerModules.ssh
                {
                  home.stateVersion = lib.mkDefault "25.05";
                  home.username = lib.mkDefault "test";
                  home.homeDirectory = lib.mkDefault "/home/test";
                }
              ]
              ++ extraModules;
            };

          hmEval = mkHmEval [
            {
              ssh-config = {
                enable = true;
                hosts = {
                  test = {
                    hostname = "example.com";
                    user = "admin";
                  };
                  # No user set: must inherit ssh-config.user ("test" via
                  # home.username).
                  inherit-user.hostname = "inherit.example.com";
                  # Every per-host option exercised at once.
                  full = {
                    hostname = "full.example.com";
                    port = 2222;
                    identityFile = "~/.ssh/full_key";
                    serverAliveInterval = 30;
                    serverAliveCountMax = 2;
                    proxyJump = "bastion.example.com";
                    forwardX11 = true;
                    localForwards = [
                      {
                        bind.port = 8080;
                        host.address = "10.0.0.13";
                        host.port = 80;
                      }
                    ];
                    remoteForwards = [
                      {
                        bind.port = 9090;
                        host.address = "db.internal";
                        host.port = 5432;
                      }
                    ];
                    dynamicForwards = [ { port = 1080; } ];
                    extraOptions = {
                      Compression = "yes";
                      StrictHostKeyChecking = "accept-new";
                    };
                  };
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

            hm-host-blocks = assertEq "hm-host-blocks" [
              {
                name = "HostName rendered from hostname";
                actual = (hmBlock "test").HostName;
                expected = "example.com";
              }
              {
                name = "explicit per-host user";
                actual = (hmBlock "test").User;
                expected = "admin";
              }
              {
                name = "null user inherits ssh-config.user";
                actual = (hmBlock "inherit-user").User;
                expected = "test";
              }
            ];

            hm-host-options = assertEq "hm-host-options" [
              {
                name = "Port";
                actual = (hmBlock "full").Port;
                expected = 2222;
              }
              {
                name = "IdentityFile";
                actual = (hmBlock "full").IdentityFile;
                expected = "~/.ssh/full_key";
              }
              {
                name = "ServerAliveInterval";
                actual = (hmBlock "full").ServerAliveInterval;
                expected = 30;
              }
              {
                name = "ServerAliveCountMax";
                actual = (hmBlock "full").ServerAliveCountMax;
                expected = 2;
              }
              {
                name = "extraOptions.Compression";
                actual = (hmBlock "full").Compression;
                expected = "yes";
              }
              {
                name = "extraOptions.StrictHostKeyChecking";
                actual = (hmBlock "full").StrictHostKeyChecking;
                expected = "accept-new";
              }
            ];

            hm-host-advanced = assertEq "hm-host-advanced" [
              {
                name = "ProxyJump";
                actual = (hmBlock "full").ProxyJump;
                expected = "bastion.example.com";
              }
              {
                name = "ForwardX11";
                actual = (hmBlock "full").ForwardX11;
                expected = "yes";
              }
              {
                name = "LocalForward (structured, defaults applied)";
                actual = (hmBlock "full").LocalForward;
                expected = [
                  {
                    bind = {
                      address = "localhost";
                      port = 8080;
                    };
                    host = {
                      address = "10.0.0.13";
                      port = 80;
                    };
                  }
                ];
              }
              {
                name = "RemoteForward (structured, defaults applied)";
                actual = (hmBlock "full").RemoteForward;
                expected = [
                  {
                    bind = {
                      address = "localhost";
                      port = 9090;
                    };
                    host = {
                      address = "db.internal";
                      port = 5432;
                    };
                  }
                ];
              }
              {
                name = "DynamicForward (structured, defaults applied)";
                actual = (hmBlock "full").DynamicForward;
                expected = [
                  {
                    address = "localhost";
                    port = 1080;
                  }
                ];
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

            # The examples are part of the public surface: import them as real
            # modules and force the resulting config so drift breaks CI, not a
            # user's build.
            examples-evaluate = pkgs.runCommand "examples-evaluate" { } ''
              ${builtins.deepSeq (mkNixosEval [ self.examples.server ]).config.services.openssh.settings ""}
              ${builtins.deepSeq (mkHmEval [ self.examples.client ]).config.programs.ssh.settings ""}
              echo ok > $out
            '';

            format = config.treefmt.build.check self;
          }
          # Forcing config.assertions pulls in unrelated NixOS assertion
          # machinery that does not evaluate on darwin host platforms
          # (shadow et al.), so assertion checks run on Linux only.
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
