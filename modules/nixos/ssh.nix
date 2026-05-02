{
  config,
  lib,
  pkgs,
  ...
}: let
  crypto = import ../shared/crypto.nix {inherit lib;};
in {
  options.services.ssh-server = {
    enable = lib.mkEnableOption "SSH server with hardening";

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "Port to listen on";
    };

    allowUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of users allowed to SSH";
    };

    allowRootLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to allow root login";
    };

    passwordAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to allow password authentication";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of SSH public keys to authorize globally";
    };

    authorizedKeysFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "%h/.ssh/authorized_keys"
        "/etc/ssh/authorized_keys.d/%u"
        "/etc/ssh/authorized_keys"
      ];
      description = "Paths to authorized keys files";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [lib.types.str lib.types.int lib.types.bool]);
      default = {};
      description = "Additional OpenSSH settings (string, int, or bool values)";
    };

    bannerText = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = ''
        **************************************************************************
                                    AUTHORIZED ACCESS ONLY
        **************************************************************************

        This system is for authorized users only. Individual use of this system
        and/or network without authority, or in excess of your authority, is
        strictly prohibited and may be subject to criminal and civil penalties.

        All activities on this system are logged and monitored. Unauthorized access
        or attempts to access this system may be reported to law enforcement.

        If you are not an authorized user, disconnect immediately.

        **************************************************************************
      '';
      description = "SSH banner text (null to disable)";
    };
  };

  config = lib.mkIf config.services.ssh-server.enable {
    services.openssh = {
      enable = true;

      # NixOS services.openssh.settings rendering:
      #   Explicit options (Ciphers, Macs, KexAlgorithms) accept Nix lists —
      #   the module joins them with commas automatically.
      #   Freeform keys (HostKeyAlgorithms, PubkeyAcceptedAlgorithms) require
      #   pre-joined comma-separated strings.
      #   AuthorizedKeysFile uses space-separated paths (sshd_config format).
      settings =
        {
          PasswordAuthentication = config.services.ssh-server.passwordAuthentication;
          PermitRootLogin =
            if config.services.ssh-server.allowRootLogin
            then "yes"
            else "no";
          PermitEmptyPasswords = false;

          PubkeyAuthentication = true;
          PubkeyAcceptedAlgorithms = crypto.modernHostKeysString;
          AuthorizedKeysFile = lib.concatStringsSep " " config.services.ssh-server.authorizedKeysFiles;
          X11Forwarding = false;
          AllowTcpForwarding = false;
          PermitTunnel = false;

          AllowUsers = lib.mkIf (config.services.ssh-server.allowUsers != []) config.services.ssh-server.allowUsers;

          MaxAuthTries = 3;
          MaxSessions = 2;
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;

          Ciphers = crypto.aeadCiphers;
          Macs = crypto.etmMacs;
          HostKeyAlgorithms = crypto.modernHostKeysString;
          KexAlgorithms = crypto.pqKex;

          LogLevel = "VERBOSE";

          Banner = lib.mkIf (config.services.ssh-server.bannerText != null) (lib.mkDefault "/etc/ssh/banner");
        }
        // config.services.ssh-server.extraSettings;

      openFirewall = true;
      ports = [config.services.ssh-server.port];
    };

    environment.etc =
      (lib.optionalAttrs (config.services.ssh-server.authorizedKeys != []) {
        "ssh/authorized_keys".text =
          lib.concatStringsSep "\n" config.services.ssh-server.authorizedKeys;
      })
      // (lib.optionalAttrs (config.services.ssh-server.bannerText != null) {
        "ssh/banner".text = config.services.ssh-server.bannerText;
      });
  };
}
