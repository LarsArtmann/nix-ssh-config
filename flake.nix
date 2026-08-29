{
  description = "Modular, hardened SSH client & server configurations for NixOS and nix-darwin, secure by default, post-quantum ready";

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

          # Throwaway ed25519 keypair (tests/test-key{,.pub}) generated for CI
          # only - never used anywhere real. See tests/README.md.
          testKey = builtins.readFile ./tests/test-key.pub;

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
                extraSettings.KbdInteractiveAuthentication = true;
              };
            }
          ];

          # Issue #1: keyboard-interactive must follow passwordAuthentication
          # by default (NixOS would otherwise leave it on, and PAM-serviced
          # prompts break keys-only) while staying independently overridable
          # for PAM-backed two-factor auth. Note: both evals MUST set
          # enable = true: without it mkIf disables the module and the
          # nixpkgs default (yes) silently answers the assertions, making
          # them vacuous (found via kill-switch testing).
          nixosKbdCoupledEval = mkNixosEval [
            {
              services.ssh-server = {
                enable = true;
                passwordAuthentication = true;
              };
            }
          ];

          # Guards the dedicated option's existence: if kbd were merely
          # mirrored from passwordAuthentication (no option), this eval
          # fails to evaluate with an unknown-option error.
          nixosKbdIndependentEval = mkNixosEval [
            {
              services.ssh-server = {
                enable = true;
                passwordAuthentication = false;
                kbdInteractiveAuthentication = true;
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
                  home = {
                    stateVersion = lib.mkDefault "25.05";
                    username = lib.mkDefault "test";
                    homeDirectory = lib.mkDefault "/home/test";
                  };
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
              home = {
                username = "test";
                homeDirectory = "/home/test";
                stateVersion = "25.05";
              };
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

          # Docs-drift guard: README's option tables must match the modules'
          # real option inventories exactly (both directions — a documented
          # option that does not exist, and an option nobody documented, are
          # both drift). Rows are matched at line starts like "| `name` |"
          # so prose and code blocks never false-positive.
          readme = builtins.readFile (self + "/README.md");

          readmeTableOptions =
            pattern: lines:
            lib.concatMap (
              line:
              let
                m = builtins.match pattern line;
              in
              lib.optional (m != null) (lib.head m)
            ) lines;

          readmeServerOptions = lib.sort lib.lessThan (
            readmeTableOptions ''[| ]*`services\.ssh-server\.([A-Za-z0-9]+)`.*'' (lib.splitString "\n" readme)
          );

          readmeClientOptions = lib.sort lib.lessThan (
            readmeTableOptions ''[| ]*`ssh-config\.([A-Za-z0-9]+)`.*'' (lib.splitString "\n" readme)
          );

          # Host rows use bare names; restrict parsing to the host-submodule
          # table by slicing between its heading and the paragraph after it.
          readmeHostOptions = lib.sort lib.lessThan (
            readmeTableOptions "[| ]*`([A-Za-z0-9]+)`.*" (
              lib.splitString "\n" (
                lib.head (
                  lib.splitString "A **forward** is" (lib.last (lib.splitString "#### Host Submodule Options" readme))
                )
              )
            )
          );

          nixosOptionNames = lib.sort lib.lessThan (lib.attrNames nixosEval.options.services.ssh-server);

          hmOptionNames = lib.sort lib.lessThan (lib.attrNames hmEval.options.ssh-config);

          hmHostOptionNames = lib.sort lib.lessThan (
            lib.filter (n: n != "_module") (
              lib.attrNames (hmEval.options.ssh-config.hosts.type.getSubOptions [ ])
            )
          );

          # FEATURES.md claims per-system content-check counts; the counts must
          # track the actual number of content checks (formatters excluded, VM
          # separate). Parsing fails eval if the line is reworded beyond the
          # pattern — exactly the drift class this guard exists for.
          featuresClaimedCounts =
            let
              matches = map (
                line: builtins.match ''.*[^0-9]([0-9]+) eval/content checks per system \(Linux: ([0-9]+).*'' line
              ) (lib.splitString "\n" (builtins.readFile (self + "/FEATURES.md")));
              found = lib.filter (m: m != null) matches;
            in
            {
              darwin = lib.toInt (lib.head (lib.head found));
              linux = lib.toInt (lib.last (lib.head found));
            };

          # Reality side of the count guard: everything in checks except the
          # two formatter entries (format, treefmt) and, on x86_64-linux, the
          # VM test. attrNames only forces the attrset's keys, so this does
          # not recurse into the count check that uses it.
          contentCheckCount =
            lib.length (lib.attrNames config.checks) - 2 - (if system == "x86_64-linux" then 1 else 0);
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
              {
                name = "KbdInteractiveAuthentication (must default off with passwords, or PAM prompts break keys-only)";
                actual = sshdSettings.KbdInteractiveAuthentication;
                expected = false;
              }
            ];

            nixos-kbd-interactive = assertEq "kbd-interactive" [
              {
                name = "follows passwordAuthentication by default (passwords on => kbd on)";
                actual = nixosKbdCoupledEval.config.services.openssh.settings.KbdInteractiveAuthentication;
                expected = true;
              }
              {
                name = "can be enabled independently for PAM-backed 2FA (passwords off)";
                actual = nixosKbdIndependentEval.config.services.openssh.settings.KbdInteractiveAuthentication;
                expected = true;
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
              {
                name = "etc mode forces a copy (a symlink would be rejected by sshd StrictModes)";
                actual = nixosEval.config.environment.etc."ssh/authorized_keys".mode;
                expected = "0444";
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
              {
                name = "extraSettings overrides a default (KbdInteractiveAuthentication)";
                actual = nixosCustomEval.config.services.openssh.settings.KbdInteractiveAuthentication;
                expected = true;
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

            docs-option-inventory = assertEq "docs-option-inventory" [
              {
                name = "README server option table matches services.ssh-server";
                actual = readmeServerOptions;
                expected = nixosOptionNames;
              }
              {
                name = "README client option table matches ssh-config";
                actual = readmeClientOptions;
                expected = hmOptionNames;
              }
              {
                name = "README host option table matches the hosts submodule";
                actual = readmeHostOptions;
                expected = hmHostOptionNames;
              }
            ];

            docs-check-count = assertEq "docs-check-count" [
              {
                name = "FEATURES.md content-check counts match the actual checks";
                actual = {
                  claimed-darwin = featuresClaimedCounts.darwin;
                  claimed-linux = featuresClaimedCounts.linux;
                  actual-content-checks = contentCheckCount;
                  this-system = system;
                };
                expected = {
                  claimed-darwin = featuresClaimedCounts.darwin;
                  claimed-linux = featuresClaimedCounts.linux;
                  actual-content-checks =
                    if pkgs.stdenv.hostPlatform.isDarwin then
                      featuresClaimedCounts.darwin
                    else
                      featuresClaimedCounts.linux;
                  this-system = system;
                };
              }
            ];
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
          }
          # Formatting gate: treefmt check on the whole repo (nixfmt).
          // {
            format = config.treefmt.build.check self;
          }
          # QEMU integration test: boots a real VM, starts sshd, and proves
          # the hardened config holds at runtime (sshd -T) plus actual
          # key-based login and non-publickey auth denial. Restored from the
          # pre-flake-parts test (removed at e910e78), now with a working
          # key-auth subtest.
          // lib.optionalAttrs (system == "x86_64-linux") {
            nixos-vm-sshd = pkgs.testers.nixosTest {
              name = "sshd-hardened-config";

              nodes.server =
                { pkgs, ... }:
                {
                  imports = [ self.nixosModules.ssh ];
                  services.ssh-server = {
                    enable = true;
                    allowUsers = [ "testuser" ];
                    authorizedKeys = [ testKey ];
                  };
                  users.users.testuser = {
                    isNormalUser = true;
                    description = "VM test login user";
                  };
                  environment.systemPackages = [ pkgs.openssh ];
                  system.stateVersion = "25.05";
                };

              nodes.client =
                { pkgs, ... }:
                {
                  environment.systemPackages = [ pkgs.openssh ];
                  system.stateVersion = "25.05";
                };

              testScript = ''
                start_all()
                server.wait_for_unit("sshd.service")
                server.wait_for_open_port(22)

                with subtest("password auth disabled"):
                    server.succeed("sshd -T | grep -i 'passwordauthentication no'")

                with subtest("keyboard-interactive disabled"):
                    server.succeed("sshd -T | grep -i 'kbdinteractiveauthentication no'")

                # End-to-end: the server must not even advertise
                # keyboard-interactive/password. If either were offered,
                # the failure message would list it in the parentheses
                # (issue #1 regression guard).
                with subtest("only publickey auth is offered"):
                    status, output = client.execute(
                        "ssh"
                        + " -o StrictHostKeyChecking=accept-new"
                        + " -o UserKnownHostsFile=/root/known_hosts"
                        + " -o BatchMode=yes"
                        + " -o PreferredAuthentications=keyboard-interactive,password"
                        + " testuser@server -- true 2>&1"
                    )
                    assert status != 0, "non-publickey auth unexpectedly succeeded"
                    assert "Permission denied (publickey)" in output, (
                        f"server offered more than publickey: {output}"
                    )

                with subtest("root login disabled"):
                    server.succeed("sshd -T | grep -i 'permitrootlogin no'")

                with subtest("banner configured"):
                    server.succeed("sshd -T | grep -i 'banner /etc/ssh/banner'")
                    server.succeed("grep -q 'AUTHORIZED ACCESS ONLY' /etc/ssh/banner")


                with subtest("modern ciphers only"):
                    output = server.succeed("sshd -T")
                    assert "chacha20-poly1305" in output, f"missing chacha20 cipher in: {output}"

                with subtest("post-quantum kex configured"):
                    output = server.succeed("sshd -T")
                    assert "mlkem768x25519-sha256" in output, f"missing ML-KEM KEX in: {output}"

                with subtest("etm macs only"):
                    output = server.succeed("sshd -T")
                    assert "hmac-sha2-512-etm" in output, f"missing ETM MAC in: {output}"

                with subtest("authorized keys present and not a symlink"):
                    server.succeed("grep -q 'ssh-ed25519' /etc/ssh/authorized_keys")
                    server.succeed("test -f /etc/ssh/authorized_keys && ! test -L /etc/ssh/authorized_keys")

                with subtest("key auth succeeds"):
                    client.succeed("install -m 600 ${self}/tests/test-key /root/test-key")
                    client.succeed(
                        "ssh -i /root/test-key"
                        + " -o StrictHostKeyChecking=accept-new"
                        + " -o UserKnownHostsFile=/root/known_hosts"
                        + " -o BatchMode=yes"
                        + " testuser@server -- true"
                    )

                # Runtime support proof: every algorithm we configure must be
                # compiled into the installed OpenSSH (guards against the
                # nixpkgs pin dropping, renaming, or disabling an algorithm).
                with subtest("ssh -Q supports every configured algorithm"):
                    for family, algs in [
                        ("kex", ${builtins.toJSON crypto.pqKex}),
                        ("cipher", ${builtins.toJSON crypto.aeadCiphers}),
                        ("mac", ${builtins.toJSON crypto.etmMacs}),
                    ]:
                        status, output = client.execute(f"ssh -Q {family}")
                        assert status == 0, f"ssh -Q {family} failed: {output}"
                        missing = [a for a in algs if a not in output]
                        assert missing == [], f"client lacks {family} support: {missing}"

                # The PQ headline as runtime fact: assert the algorithm the
                # client actually negotiated (not just what sshd -T offers).
                with subtest("negotiated kex is post-quantum"):
                    status, output = client.execute(
                        "ssh -vv -i /root/test-key"
                        + " -o StrictHostKeyChecking=accept-new"
                        + " -o UserKnownHostsFile=/root/known_hosts"
                        + " -o BatchMode=yes"
                        + " testuser@server -- true 2>&1"
                    )
                    assert status == 0, f"key login failed: {output}"
                    assert "kex: algorithm: mlkem768x25519-sha256" in output, (
                        f"client did not negotiate ML-KEM: {output}"
                    )

                # An unauthorized key must fail, and the failure mode must be
                # the publickey-only method list (issue #1 regression guard).
                with subtest("wrong key is rejected"):
                    client.succeed("ssh-keygen -t ed25519 -N ''' -f /root/wrong-key -q")
                    status, output = client.execute(
                        "ssh -i /root/wrong-key"
                        + " -o StrictHostKeyChecking=accept-new"
                        + " -o UserKnownHostsFile=/root/known_hosts"
                        + " -o BatchMode=yes"
                        + " testuser@server -- true 2>&1"
                    )
                    assert status != 0, "unauthorized key was accepted"
                    assert "Permission denied (publickey)" in output, (
                        f"unexpected rejection mode: {output}"
                    )

                # The banner is not just configured, it is actually delivered
                # to connecting clients (pre-auth, printed on stderr).
                with subtest("client observes the pre-auth banner"):
                    status, output = client.execute(
                        "ssh -i /root/test-key"
                        + " -o StrictHostKeyChecking=accept-new"
                        + " -o UserKnownHostsFile=/root/known_hosts"
                        + " -o BatchMode=yes"
                        + " testuser@server -- true 2>&1"
                    )
                    assert status == 0, f"key login failed: {output}"
                    assert "AUTHORIZED ACCESS ONLY" in output, (
                        f"banner not delivered to client: {output}"
                    )
              '';
            };
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = [ pkgs.nil ];
          };
        };
    };
}
