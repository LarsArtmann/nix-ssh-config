{
  config,
  lib,
  pkgs,
  ...
}:
let
  crypto = import ../shared/crypto.nix { inherit lib; };

  # Address/port pairs mirror the shapes Home Manager's settings renderer
  # understands natively (see its renderForward/renderDynamicForward), so the
  # forwarding values below pass through unrendered and HM handles IPv6
  # brackets, unix socket paths and plain ports itself.
  mkAddressPortModule =
    action:
    lib.types.submodule {
      options = {
        address = lib.mkOption {
          type = if action == "bind" then lib.types.str else lib.types.nullOr lib.types.str;
          default = if action == "bind" then "localhost" else null;
          example = "example.org";
          description = "The address to ${action} to.";
        };
        port = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          example = 8080;
          description = "The port to ${action} to.";
        };
      };
    };

  forwardModule = lib.types.submodule {
    options = {
      bind = lib.mkOption {
        type = mkAddressPortModule "bind";
        description = "Local side of the forwarding";
      };
      host = lib.mkOption {
        type = mkAddressPortModule "forward";
        description = "Remote side of the forwarding";
      };
    };
  };
in
{
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
      type = lib.types.attrsOf (
        lib.types.submodule {
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
            certificateFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Certificate file for this host (CertificateFile)";
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
              default = { };
              description = "Additional SSH options (merged directly into the host block using upstream directive names)";
            };
            proxyJump = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "bastion.example.com";
              description = "Jump host to route this connection through (ProxyJump)";
            };
            forwardX11 = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to forward X11 sessions for this host (ForwardX11)";
            };
            localForwards = lib.mkOption {
              type = lib.types.listOf forwardModule;
              default = [ ];
              example = lib.literalExpression ''
                [
                  {
                    bind.port = 8080;
                    host.address = "10.0.0.13";
                    host.port = 80;
                  }
                ]
              '';
              description = "Local port forwardings (LocalForward)";
            };
            remoteForwards = lib.mkOption {
              type = lib.types.listOf forwardModule;
              default = [ ];
              example = lib.literalExpression ''
                [
                  {
                    bind.port = 8080;
                    host.address = "10.0.0.13";
                    host.port = 80;
                  }
                ]
              '';
              description = "Remote port forwardings (RemoteForward)";
            };
            dynamicForwards = lib.mkOption {
              type = lib.types.listOf (mkAddressPortModule "bind");
              default = [ ];
              example = lib.literalExpression ''
                [ { port = 8080; } ]
              '';
              description = "Dynamic (SOCKS) port forwardings (DynamicForward)";
            };
          };
        }
      );
      default = { };
      description = "SSH host configurations";
    };

    extraIncludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional SSH config files to include";
    };

    enableOrbstack = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.hostPlatform.isDarwin;
      description = "Include OrbStack SSH config if available (Darwin only)";
    };

    enableColima = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.hostPlatform.isDarwin;
      description = "Include Colima SSH config if available (Darwin only)";
    };
  };

  config = lib.mkIf config.ssh-config.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      includes =
        lib.optionals pkgs.stdenv.hostPlatform.isDarwin (
          (lib.optional (
            config.ssh-config.enableOrbstack
            && builtins.pathExists "${config.home.homeDirectory}/.orbstack/ssh/config"
          ) "~/.orbstack/ssh/config")
          ++ (lib.optional (
            config.ssh-config.enableColima
            && builtins.pathExists "${config.home.homeDirectory}/.colima/ssh_config"
          ) "~/.colima/ssh_config")
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

        (lib.mapAttrs (
          _name: hostConfig:
          {
            HostName = hostConfig.hostname;
            User = if hostConfig.user != null then hostConfig.user else config.ssh-config.user;
          }
          // lib.optionalAttrs (hostConfig.port != null) { Port = hostConfig.port; }
          // lib.optionalAttrs (hostConfig.identityFile != null) { IdentityFile = hostConfig.identityFile; }
          // lib.optionalAttrs (hostConfig.certificateFile != null) {
            CertificateFile = hostConfig.certificateFile;
          }
          // lib.optionalAttrs (hostConfig.serverAliveInterval != null) {
            ServerAliveInterval = hostConfig.serverAliveInterval;
          }
          // lib.optionalAttrs (hostConfig.serverAliveCountMax != null) {
            ServerAliveCountMax = hostConfig.serverAliveCountMax;
          }
          // lib.optionalAttrs (hostConfig.proxyJump != null) {
            ProxyJump = hostConfig.proxyJump;
          }
          // lib.optionalAttrs hostConfig.forwardX11 { ForwardX11 = "yes"; }
          # Forwarding values keep their structured shape: Home Manager's
          # settings renderer accepts it natively and repeats the directive
          # per list element.
          // lib.optionalAttrs (hostConfig.localForwards != [ ]) {
            LocalForward = hostConfig.localForwards;
          }
          // lib.optionalAttrs (hostConfig.remoteForwards != [ ]) {
            RemoteForward = hostConfig.remoteForwards;
          }
          // lib.optionalAttrs (hostConfig.dynamicForwards != [ ]) {
            DynamicForward = hostConfig.dynamicForwards;
          }
          // lib.optionalAttrs (hostConfig.extraOptions != { }) hostConfig.extraOptions
        ) config.ssh-config.hosts)
      ];
    };

    home.activation.createSshSockets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "${config.home.homeDirectory}/.ssh/sockets"
      $DRY_RUN_CMD chmod 700 "${config.home.homeDirectory}/.ssh/sockets"
    '';
  };
}
