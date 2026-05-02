{
  description = "Modular, hardened SSH client & server configurations for NixOS and nix-darwin — secure by default, post-quantum ready";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-full-flake.url = "github:LarsArtmann/treefmt-full-flake";
  };

  # Architecture decisions:
  #   - home-manager input kept for checks (homeManagerConfiguration in test evals)
  #   - x86_64-darwin dropped (deprecated in Nixpkgs 26.05)
  #   - systems: aarch64-darwin, x86_64-linux, aarch64-linux

  outputs = {
    self,
    nixpkgs,
    home-manager,
    treefmt-full-flake,
    ...
  }: let
    systems = ["aarch64-darwin" "x86_64-linux" "aarch64-linux"];

    forEachSystem = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs = nixpkgs.legacyPackages.${system};
        });

    testKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/uqxUhFQpJaBq+dDd+shObEjKm8YOPimFx7XHgqTFJ lars@Lars-MacBook-Air-2026-04";
  in {
    homeManagerModules.ssh = import ./modules/home-manager/ssh.nix;

    nixosModules.ssh = import ./modules/nixos/ssh.nix;

    sshKeys = {
      lars = builtins.readFile ./ssh-keys/lars-ed25519.pub;
    };

    checks =
      forEachSystem ({
        system,
        pkgs,
      }: let
        lib = nixpkgs.lib;

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
              system.stateVersion = lib.mkDefault "25.05";
              fileSystems."/".device = "/dev/null";
            }
          ];
        };

        nixosEvalCustomPort = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.ssh
            {
              services.ssh-server = {
                enable = true;
                port = 2222;
                allowUsers = ["admin"];
                authorizedKeys = [testKey];
                extraSettings.LoginGraceTime = 30;
              };
              boot.isContainer = true;
              system.stateVersion = lib.mkDefault "25.05";
              fileSystems."/".device = "/dev/null";
            }
          ];
        };

        nixosEvalDisabled = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.ssh
            {
              services.ssh-server.enable = false;
              boot.isContainer = true;
              system.stateVersion = lib.mkDefault "25.05";
              fileSystems."/".device = "/dev/null";
            }
          ];
        };

        mkHmEval = extraModules:
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules =
              [
                self.homeManagerModules.ssh
              ]
              ++ extraModules;
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

        hmEvalNoUser = mkHmEval [
          {
            ssh-config = {
              enable = true;
              hosts.myhost.hostname = "192.168.1.100";
            };
            home.username = "defaultuser";
            home.homeDirectory = "/home/defaultuser";
            home.stateVersion = "25.05";
          }
        ];

        hmEvalFullHost = mkHmEval [
          {
            ssh-config = {
              enable = true;
              hosts.webserver = {
                hostname = "203.0.113.10";
                user = "deploy";
                port = 2222;
                serverAliveInterval = 60;
                extraOptions.StrictHostKeyChecking = "no";
              };
            };
            home.username = "test";
            home.homeDirectory = "/home/test";
            home.stateVersion = "25.05";
          }
        ];

        sshdSettings = nixosEval.config.services.openssh.settings;

        getBlock = eval: name: eval.config.programs.ssh.matchBlocks.${name}.data;

        assertContains = label: text: substr:
          pkgs.runCommand "assert-${label}" {} ''
            printf '%s' ${lib.escapeShellArg text} | grep -qF ${lib.escapeShellArg substr} || (
              echo "FAIL: ${label}"
              echo "Expected to find: ${substr}"
              exit 1
            )
            echo ok > $out
          '';
      in {
        nixos-module-evaluates = pkgs.runCommand "nixos-module-evaluates" {} ''
          ${builtins.deepSeq nixosEval.config.services.openssh.settings ""}
          ${builtins.deepSeq nixosEval.config.environment.etc."ssh/authorized_keys".text ""}
          echo ok > $out
        '';

        home-manager-module-evaluates = pkgs.runCommand "home-manager-module-evaluates" {} ''
          ${builtins.deepSeq hmEval.config.programs.ssh.matchBlocks ""}
          echo ok > $out
        '';

        nixos-password-auth-disabled =
          assertContains
          "password-auth-disabled"
          (builtins.toJSON sshdSettings)
          ''"PasswordAuthentication":false'';

        nixos-root-login-disabled =
          assertContains
          "root-login-disabled"
          (builtins.toJSON sshdSettings)
          ''"PermitRootLogin":"no"'';

        nixos-custom-port = pkgs.runCommand "assert-custom-port" {} ''
          printf '%s' ${lib.escapeShellArg (builtins.toJSON nixosEvalCustomPort.config.services.openssh.ports)} \
            | grep -qF '2222' || (echo "FAIL: port should be 2222"; exit 1)
          echo ok > $out
        '';

        nixos-authorized-keys =
          assertContains
          "authorized-keys"
          nixosEval.config.environment.etc."ssh/authorized_keys".text
          testKey;

        nixos-banner-rendered =
          assertContains
          "banner-rendered"
          nixosEval.config.environment.etc."ssh/banner".text
          "AUTHORIZED ACCESS ONLY";

        nixos-crypto-algorithms = let
          json = builtins.toJSON sshdSettings;
        in
          pkgs.runCommand "assert-crypto-algorithms" {} ''
            printf '%s' ${lib.escapeShellArg json} | grep -qF 'chacha20-poly1305' || (echo "FAIL: missing chacha20 cipher"; exit 1)
            printf '%s' ${lib.escapeShellArg json} | grep -qF 'mlkem768x25519-sha256' || (echo "FAIL: missing ML-KEM KEX"; exit 1)
            printf '%s' ${lib.escapeShellArg json} | grep -qF 'hmac-sha2-512-etm' || (echo "FAIL: missing ETM MAC"; exit 1)
            printf '%s' ${lib.escapeShellArg json} | grep -qF 'ssh-ed25519' || (echo "FAIL: missing ed25519 host key"; exit 1)
            echo ok > $out
          '';

        nixos-extra-settings-merge =
          assertContains
          "extra-settings-merge"
          (builtins.toJSON nixosEvalCustomPort.config.services.openssh.settings)
          ''"LoginGraceTime":30'';

        nixos-disabled-no-sshd = pkgs.runCommand "nixos-disabled-no-sshd" {} (
          let
            cfg = nixosEvalDisabled.config.services.openssh;
          in ''
            ${lib.optionalString cfg.enable "echo 'FAIL: openssh should be disabled'; exit 1"}
            echo ok > $out
          ''
        );

        hm-host-block-user = let
          block = getBlock hmEval "test";
        in
          pkgs.runCommand "hm-host-block-user" {} ''
            test "${block.user or ""}" = "admin" || (echo "FAIL: expected user 'admin', got '${block.user or ""}'"; exit 1)
            echo ok > $out
          '';

        hm-host-inherits-default-user = let
          block = getBlock hmEvalNoUser "myhost";
        in
          pkgs.runCommand "hm-host-inherits-default-user" {} ''
            test "${block.user or ""}" = "defaultuser" || (echo "FAIL: expected 'defaultuser', got '${block.user or ""}'"; exit 1)
            echo ok > $out
          '';

        hm-full-host-config = let
          ws = getBlock hmEvalFullHost "webserver";
        in
          pkgs.runCommand "hm-full-host-config" {} ''
            test "${ws.hostname or ""}" = "203.0.113.10" || (echo "FAIL: hostname"; exit 1)
            test "${ws.user or ""}" = "deploy" || (echo "FAIL: user"; exit 1)
            test "${toString (ws.port or 0)}" = "2222" || (echo "FAIL: port"; exit 1)
            test "${toString (ws.serverAliveInterval or 0)}" = "60" || (echo "FAIL: alive interval"; exit 1)
            echo ok > $out
          '';

        hm-crypto-in-config = let
          starBlock = getBlock hmEval "*";
          kex = starBlock.extraOptions.KexAlgorithms or "";
          ciphers = starBlock.extraOptions.Ciphers or "";
        in
          pkgs.runCommand "hm-crypto-in-config" {} ''
            printf '%s' ${lib.escapeShellArg kex} | grep -qF 'mlkem768x25519-sha256' || (echo "FAIL: no ML-KEM in KEX, got: ${kex}"; exit 1)
            printf '%s' ${lib.escapeShellArg ciphers} | grep -qF 'chacha20-poly1305' || (echo "FAIL: no chacha20 cipher"; exit 1)
            echo ok > $out
          '';
      })
      // {
        x86_64-linux.nixos-vm-sshd = nixpkgs.legacyPackages.x86_64-linux.testers.nixosTest {
          name = "sshd-hardened-config";

          nodes.server = {config, ...}: {
            imports = [self.nixosModules.ssh];
            services.ssh-server = {
              enable = true;
              allowUsers = ["root"];
              authorizedKeys = [testKey];
            };
            system.stateVersion = "25.05";
          };

          nodes.client = {pkgs, ...}: {
            environment.systemPackages = [pkgs.openssh];
            system.stateVersion = "25.05";
          };

          testScript = ''
            server.start()
            server.wait_for_unit("sshd.service")
            server.wait_for_open_port(22)

            with subtest("password auth disabled"):
                server.succeed("sshd -T | grep 'passwordauthentication no'")

            with subtest("root login disabled"):
                server.succeed("sshd -T | grep 'permitrootlogin no'")

            with subtest("banner configured"):
                server.succeed("sshd -T | grep -F 'banner /etc/ssh/banner'")
                server.succeed("grep -q 'AUTHORIZED ACCESS ONLY' /etc/ssh/banner")

            with subtest("authorized keys present"):
                server.succeed("grep -q 'ssh-ed25519' /etc/ssh/authorized_keys")

            with subtest("modern ciphers only"):
                output = server.succeed("sshd -T")
                assert "chacha20-poly1305" in output, f"missing chacha20 cipher in: {output}"

            with subtest("post-quantum kex configured"):
                output = server.succeed("sshd -T")
                assert "mlkem768x25519-sha256" in output, f"missing ML-KEM KEX in: {output}"

            with subtest("etm macs only"):
                output = server.succeed("sshd -T")
                assert "hmac-sha2-512-etm" in output, f"missing ETM MAC in: {output}"
          '';
        };
      };

    devShells = forEachSystem ({pkgs, ...}: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          nixfmt
          nil
        ];
      };
    });

    apps = forEachSystem ({system, ...}: {
      fmt-check = {
        type = "app";
        program = toString (nixpkgs.legacyPackages.${system}.writeShellScript "fmt-check" ''
          exec ${self.formatter.${system}}/bin/treefmt --fail-on-change "$@"
        '');
        meta.description = "Check formatting without modifying files";
      };
    });

    formatter = forEachSystem ({pkgs, ...}: treefmt-full-flake.formatter.${pkgs.stdenv.hostPlatform.system});
  };
}
