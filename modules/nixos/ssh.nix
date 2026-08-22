{
  config,
  lib,
  ...
}:
let
  crypto = import ../shared/crypto.nix { inherit lib; };
  banner = import ../shared/banner.nix;

  # sshd banners travel over a line-oriented protocol channel: control
  # characters other than newline and tab can corrupt or break the channel.
  invalidBannerChars =
    text:
    lib.filter (c: c != "\n" && c != "\t" && builtins.match "[[:print:]]" c == null) (
      lib.stringToCharacters text
    );
in
{
  options.services.ssh-server = {
    enable = lib.mkEnableOption "SSH server with hardening";

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "Port to listen on";
    };

    allowUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
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
      default = [ ];
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
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.int
          lib.types.bool
        ]
      );
      default = { };
      description = "Additional OpenSSH settings (string, int, or bool values)";
    };

    bannerText = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = banner.defaultBannerText;
      defaultText = "the legal banner defined in modules/shared/banner.nix";
      description = ''
        SSH banner text (null to disable). Only printable characters,
        newlines and tabs are allowed; control characters are rejected at
        evaluation time because they can break the sshd banner channel.
      '';
    };
  };

  config = lib.mkIf config.services.ssh-server.enable {
    assertions =
      let
        text = config.services.ssh-server.bannerText;
      in
      lib.optional (text != null) {
        assertion = invalidBannerChars text == [ ];
        message =
          "services.ssh-server.bannerText must not contain control characters "
          + "(printable characters, newline and tab are allowed); found: "
          + builtins.toJSON (invalidBannerChars text);
      };

    services.openssh = {
      enable = true;

      # NixOS services.openssh.settings rendering:
      #   Explicit options (Ciphers, Macs, KexAlgorithms) accept Nix lists —
      #   the module joins them with commas automatically.
      #   Freeform keys (HostKeyAlgorithms, PubkeyAcceptedAlgorithms) require
      #   pre-joined comma-separated strings.
      #   AuthorizedKeysFile uses space-separated paths (sshd_config format).
      settings = {
        PasswordAuthentication = config.services.ssh-server.passwordAuthentication;
        PermitRootLogin = if config.services.ssh-server.allowRootLogin then "yes" else "no";
        PermitEmptyPasswords = false;

        PubkeyAuthentication = true;
        PubkeyAcceptedAlgorithms = crypto.modernHostKeysString;
        AuthorizedKeysFile = lib.concatStringsSep " " config.services.ssh-server.authorizedKeysFiles;
        X11Forwarding = false;
        AllowTcpForwarding = false;
        PermitTunnel = false;

        AllowUsers = lib.mkIf (
          config.services.ssh-server.allowUsers != [ ]
        ) config.services.ssh-server.allowUsers;

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
      ports = [ config.services.ssh-server.port ];
    };

    environment.etc =
      (lib.optionalAttrs (config.services.ssh-server.authorizedKeys != [ ]) {
        # mode "0444" makes NixOS COPY this file into /etc instead of
        # symlinking it into /nix/store. This is load-bearing: sshd's
        # StrictModes rejects any AuthorizedKeysFile whose path crosses the
        # world-writable (1777) /nix/store, so a symlinked global keys file
        # is silently ignored at runtime. Upstream NixOS uses the same
        # copy trick for /etc/ssh/authorized_keys.d/*.
        "ssh/authorized_keys" = {
          mode = "0444";
          text = lib.concatStringsSep "\n" config.services.ssh-server.authorizedKeys;
        };
      })
      // (lib.optionalAttrs (config.services.ssh-server.bannerText != null) {
        "ssh/banner".text = config.services.ssh-server.bannerText;
      });
  };
}
