{
  config,
  lib,
  pkgs,
  ...
}: let
  crypto = import ../shared/crypto.nix {inherit lib;};
in {
  options.ssh-config = {
    enable = lib.mkEnableOption "SSH client configuration";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.home.username;
      defaultText = "config.home.username";
      description = "Default username for SSH connections";
    };

    identityFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "~/.ssh/id_ed25519";
      description = "Default SSH identity file path";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            description = "Host IP or hostname";
          };
          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Username for this host (defaults to ssh-config.user)";
          };
          port = lib.mkOption {
            type = lib.types.nullOr lib.types.port;
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
            description = "Additional SSH options (merged directly into the host block using upstream directive names)";
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

      includes =
        lib.optionals pkgs.stdenv.isDarwin (
          (lib.optional (config.ssh-config.enableOrbstack
            && builtins.pathExists "${config.home.homeDirectory}/.orbstack/ssh/config")
          "~/.orbstack/ssh/config")
          ++ (lib.optional (config.ssh-config.enableColima
            && builtins.pathExists "${config.home.homeDirectory}/.colima/ssh_config")
          "~/.colima/ssh_config")
        )
        ++ config.ssh-config.extraIncludes;

      # Global defaults applied to all hosts via "*" block.
      # Uses upstream SSH directive names (PascalCase) per Home Manager
      # programs.ssh.settings freeform type.
      settings = lib.mkMerge [
        {
          "*" = {
            User = config.ssh-config.user;
            ForwardAgent = "no";
            AddKeysToAgent = "no";
            Compression = "no";
            ServerAliveInterval = 60;
            ServerAliveCountMax = 3;
            HashKnownHosts = "no";
            UserKnownHostsFile = "~/.ssh/known_hosts";
            ControlMaster = "no";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "no";
            KexAlgorithms = crypto.pqKexString;
            Ciphers = crypto.aeadCiphersString;
            MACs = crypto.etmMacsString;
            HostKeyAlgorithms = crypto.modernHostKeysString;
            PubkeyAcceptedAlgorithms = crypto.modernHostKeysString;
          }
          // lib.optionalAttrs (config.ssh-config.identityFile != null) {
            IdentityFile = config.ssh-config.identityFile;
          };
        }

        {
          "github.com" = {
            User = "git";
            Compression = "yes";
            ServerAliveInterval = 60;
            ControlMaster = "auto";
            ControlPath = "~/.ssh/sockets/%r@%h-%p";
            ControlPersist = "600";
            TCPKeepAlive = "yes";
          };
        }

        (lib.mapAttrs (name: hostConfig:
          {
            HostName = hostConfig.hostname;
            User =
              if hostConfig.user != null
              then hostConfig.user
              else config.ssh-config.user;
          }
          // lib.optionalAttrs (hostConfig.port != null) {Port = hostConfig.port;}
          // lib.optionalAttrs (hostConfig.identityFile != null) {IdentityFile = hostConfig.identityFile;}
          // lib.optionalAttrs (hostConfig.serverAliveInterval != null) {ServerAliveInterval = hostConfig.serverAliveInterval;}
          // lib.optionalAttrs (hostConfig.serverAliveCountMax != null) {ServerAliveCountMax = hostConfig.serverAliveCountMax;}
          // lib.optionalAttrs (hostConfig.extraOptions != {}) hostConfig.extraOptions)
        config.ssh-config.hosts)
      ];
    };

    home.activation.createSshSockets = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${config.home.homeDirectory}/.ssh/sockets"
      $DRY_RUN_CMD chmod 700 "${config.home.homeDirectory}/.ssh/sockets"
    '';
  };
}
