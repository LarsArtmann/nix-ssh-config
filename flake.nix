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
      imports = [
        inputs.treefmt-nix.flakeModule
        ./tests/checks.nix
      ];

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
          config,
          ...
        }:
        {
          treefmt = {
            # This repo publishes the treefmt check as checks.<system>.format
            # (tests/checks.nix). treefmt-nix's own flakeModule would add a
            # duplicate `treefmt` attr for the same derivation, which broke
            # the derived content-check count — so its auto-check is off and
            # the check lives under exactly one documented name.
            flakeCheck = false;
            programs.nixfmt.enable = true;
            programs.prettier = {
              enable = true;
              settings = {
                proseWrap = "preserve";
              };
            };
            # Keep-a-changelog file stays byte-stable; append-only by policy.
            settings.excludes = [ "CHANGELOG.md" ];
          };

          devShells.default = pkgs.mkShellNoCC {
            packages = [ pkgs.nil ];
            # Installs (once, non-destructively) a pre-push hook that runs
            # the full gate. Skip a single push with `git push --no-verify`.
            shellHook = ''
                            hook=".git/hooks/pre-push"
                            if [ ! -f "$hook" ] || ! grep -q "nix fmt" "$hook" 2>/dev/null; then
                              mkdir -p .git/hooks
                              cat > "$hook" <<'HOOK'
              #!/usr/bin/env bash
              # Pre-push gate (installed by nix develop). Skip with --no-verify.
              set -euo pipefail
              nix fmt -- --fail-on-change
              nix run nixpkgs#statix -- check
              nix flake check --all-systems --no-build
              nix flake check
              HOOK
                              chmod +x "$hook"
                              echo "pre-push gate hook installed (.git/hooks/pre-push)"
                            fi
            '';
          };
        };
    };
}
