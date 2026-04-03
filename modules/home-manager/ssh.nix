{
  config,
  lib,
  pkgs,
  ...
}: {
  options.ssh-config = {
    enable = lib.mkEnableOption "SSH client configuration";

    user = lib.mkOption {
      type = lib.types.str;
      default = "lars";
      description = "Username for SSH connections";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            description = "Host IP or hostname";
          };
          user = lib.mkOption {
            type = lib.types.str;
            description = "Username for this host";
          };
          port = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "SSH port";
          };
          identityFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Path to identity file";
          };
          serverAliveInterval = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Keepalive interval in seconds";
          };
          serverAliveCountMax = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Max keepalive probes";
          };
          extraOptions = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Additional SSH options";
          };
        };
      });
      default = {};
      description = "SSH host configurations";
    };

    extraIncludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional SSH config files to include";
    };

    enableOrbstack = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isDarwin;
      description = "Include OrbStack SSH config if available (Darwin only)";
    };

    enableColima = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isDarwin;
      description = "Include Colima SSH config if available (Darwin only)";
    };
  };

  config = lib.mkIf config.ssh-config.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      includes = lib.optionals pkgs.stdenv.isDarwin (
        (lib.optional (config.ssh-config.enableOrbstack &&
          builtins.pathExists "${config.home.homeDirectory}/.orbstack/ssh/config")
          "~/.orbstack/ssh/config")
        ++ (lib.optional (config.ssh-config.enableColima &&
          builtins.pathExists "${config.home.homeDirectory}/.colima/ssh_config")
          "~/.colima/ssh_config")
      ) ++ config.ssh-config.extraIncludes;

      matchBlocks = lib.mkMerge [
        # Default settings for all hosts
        {
          "*" = {
            forwardAgent = lib.mkDefault false;
            addKeysToAgent = lib.mkDefault "no";
            compression = lib.mkDefault false;
            serverAliveInterval = lib.mkDefault 60;
            serverAliveCountMax = lib.mkDefault 3;
            hashKnownHosts = lib.mkDefault false;
            userKnownHostsFile = lib.mkDefault "~/.ssh/known_hosts";
            controlMaster = lib.mkDefault "no";
            controlPath = lib.mkDefault "~/.ssh/master-%r@%n:%p";
            controlPersist = lib.mkDefault "no";
          };
        }

        # GitHub optimized config
        {
          "github.com" = {
            user = "git";
            compression = true;
            serverAliveInterval = 60;
            controlMaster = "auto";
            controlPath = "~/.ssh/sockets/%r@%h-%p";
            controlPersist = "600";
            extraOptions = {
              TCPKeepAlive = "yes";
            };
          };
        }

        # User-defined hosts
        (lib.mapAttrs (name: hostConfig: {
          inherit (hostConfig) hostname user;
          inherit (hostConfig) port identityFile serverAliveInterval serverAliveCountMax extraOptions;
        }) config.ssh-config.hosts)
      ];
    };

    # Ensure SSH directories exist
    home.file.".ssh/sockets".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.ssh/sockets";
  };
}
