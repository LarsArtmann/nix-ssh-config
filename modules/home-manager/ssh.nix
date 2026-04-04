{
  config,
  lib,
  pkgs,
  ...
}: let
  pqKex = "mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org";
  aeadCiphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com";
  etmMacs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com";
  modernHostKeys = "ssh-ed25519,sk-ssh-ed25519@openssh.com,rsa-sha2-512,rsa-sha2-256";
in {
  options.ssh-config = {
    enable = lib.mkEnableOption "SSH client configuration";

    user = lib.mkOption {
      type = lib.types.str;
      default = "lars";
      description = "Username for SSH connections";
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

      matchBlocks = lib.mkMerge [
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
            extraOptions = lib.mkDefault (
              {
                KexAlgorithms = pqKex;
                Ciphers = aeadCiphers;
                MACs = etmMacs;
                HostKeyAlgorithms = modernHostKeys;
                PubkeyAcceptedAlgorithms = modernHostKeys;
              }
              // lib.optionalAttrs (config.ssh-config.identityFile != null) {
                IdentityFile = config.ssh-config.identityFile;
              }
            );
          };
        }

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

        (lib.mapAttrs (name: hostConfig: {
            inherit (hostConfig) hostname user;
            inherit (hostConfig) port identityFile serverAliveInterval serverAliveCountMax extraOptions;
          })
          config.ssh-config.hosts)
      ];
    };

    # Ensure SSH sockets directory exists as a real directory
    # (not a symlink — mkOutOfStoreSymlink creates a circular reference here)
    home.activation.createSshSockets = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${config.home.homeDirectory}/.ssh/sockets"
      $DRY_RUN_CMD chmod 700 "${config.home.homeDirectory}/.ssh/sockets"
    '';
  };
}
