{
  config,
  lib,
  pkgs,
  ...
}: let
  pqKex = [
    "mlkem768x25519-sha256"
    "sntrup761x25519-sha512@openssh.com"
    "curve25519-sha256@libssh.org"
    "curve25519-sha256"
  ];
  aeadCiphers = [
    "chacha20-poly1305@openssh.com"
    "aes256-gcm@openssh.com"
    "aes128-gcm@openssh.com"
  ];
  etmMacs = [
    "hmac-sha2-512-etm@openssh.com"
    "hmac-sha2-256-etm@openssh.com"
    "umac-128-etm@openssh.com"
  ];
  modernHostKeys = [
    "ssh-ed25519"
    "sk-ssh-ed25519@openssh.com"
    "rsa-sha2-512"
    "rsa-sha2-256"
  ];
in {
  options.services.ssh-server = {
    enable = lib.mkEnableOption "SSH server with hardening";

    port = lib.mkOption {
      type = lib.types.int;
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
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Additional OpenSSH settings";
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

      settings =
        {
          # Basic hardening
          PasswordAuthentication = config.services.ssh-server.passwordAuthentication;
          PermitRootLogin =
            if config.services.ssh-server.allowRootLogin
            then "yes"
            else "no";
          PermitEmptyPasswords = false;

          # Key-based authentication
          PubkeyAuthentication = true;
          # Accept modern algorithms only (OpenSSH 10.2+ compatible)
          PubkeyAcceptedAlgorithms = lib.concatStringsSep "," modernHostKeys;
          AuthorizedKeysFile = lib.concatStringsSep " " config.services.ssh-server.authorizedKeysFiles;

          # Security settings
          Protocol = 2;
          X11Forwarding = false;
          AllowTcpForwarding = false;
          PermitTunnel = false;

          # Access control
          AllowUsers = lib.mkIf (config.services.ssh-server.allowUsers != []) config.services.ssh-server.allowUsers;

          # Connection limits
          MaxAuthTries = 3;
          MaxSessions = 2;
          ClientAliveInterval = 300;
          ClientAliveCountMax = 2;

          # Strong cryptographic settings
          Ciphers = aeadCiphers;

          MACs = lib.concatStringsSep "," etmMacs;

          HostKeyAlgorithms = lib.concatStringsSep "," modernHostKeys;

          KexAlgorithms = pqKex;

          # Logging
          LogLevel = "VERBOSE";

          # Banner
          Banner = lib.mkIf (config.services.ssh-server.bannerText != null) "/etc/ssh/banner";

          # Extra settings
        }
        // config.services.ssh-server.extraSettings;

      # Firewall
      openFirewall = true;
      ports = [config.services.ssh-server.port];
    };

    # Global authorized keys (from ssh-keys/*.pub)
    environment.etc."ssh/authorized_keys".text =
      lib.mkIf (config.services.ssh-server.authorizedKeys != [])
      (lib.concatStringsSep "\n" config.services.ssh-server.authorizedKeys);

    # Banner file
    environment.etc."ssh/banner".text =
      lib.mkIf (config.services.ssh-server.bannerText != null)
      config.services.ssh-server.bannerText;
  };
}
