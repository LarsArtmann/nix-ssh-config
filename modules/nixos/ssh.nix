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

    listenAddresses = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            addr = lib.mkOption {
              type = lib.types.str;
              example = "0.0.0.0";
              description = "Address to bind (IPv6 without brackets)";
            };
            port = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = "Port for this address (defaults to `port`)";
            };
          };
        }
      );
      default = [ ];
      description = ''
        Specific addresses to listen on. Empty (the default) listens on all
        interfaces at `port`. Non-empty values emit ListenAddress directives,
        which take precedence over the plain Port directive.
      '';
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

    kbdInteractiveAuthentication = lib.mkOption {
      type = lib.types.bool;
      default = config.services.ssh-server.passwordAuthentication;
      defaultText = lib.literalExpression "config.services.ssh-server.passwordAuthentication";
      description = ''
        Whether to allow keyboard-interactive authentication. Defaults to
        the value of passwordAuthentication: NixOS otherwise defaults it
        to yes (with UsePAM also yes), which leaves a PAM-serviced prompt
        channel open (OTP/2FA modules, or Unix account passwords wherever
        the sshd PAM service permits them) even when PasswordAuthentication
        is no, breaking keys-only. Enable it explicitly only for PAM-backed
        two-factor authentication.

        When explicitly enabled, this module also sets
        `security.pam.services.sshd.unixAuth = true`: upstream ties that
        flag to `PasswordAuthentication`, which otherwise leaves the sshd
        PAM auth stack as plain `pam_deny` — every keyboard-interactive
        prompt would be refused before any module could question the
        user. Requires `usePam` not set to `false`.
      '';
    };

    usePam = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether to enable PAM authentication (settings.UsePAM). `null` (the
        default) leaves NixOS's own default (true, which also creates the
        sshd PAM service). Set `false` for a PAM-free host. Password and
        keyboard-interactive stay off regardless; PAM only matters if you
        enable `kbdInteractiveAuthentication` for two-factor auth.
      '';
    };

    authenticationMethods = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "publickey,keyboard-interactive";
      description = ''
        AuthenticationMethods directive (`null` to not emit it). Space-
        separates alternative method lists; commas within a list mean the
        methods are required in sequence. For two-factor auth combine with
        `kbdInteractiveAuthentication = true` and `passwordAuthentication =
        false`.
      '';
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
      #   Explicit options (Ciphers, Macs, KexAlgorithms) accept Nix lists;
      #   the module joins them with commas automatically.
      #   Freeform keys (HostKeyAlgorithms, PubkeyAcceptedAlgorithms) require
      #   pre-joined comma-separated strings.
      #   AuthorizedKeysFile uses space-separated paths (sshd_config format).
      settings = {
        PasswordAuthentication = config.services.ssh-server.passwordAuthentication;
        KbdInteractiveAuthentication = config.services.ssh-server.kbdInteractiveAuthentication;
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
        # Hardened explicit default: upstream sshd's is 120s (plus random
        # jitter since OpenSSH 9.9). 30s limits unauthenticated connection
        # hold time; auth must complete within this window.
        LoginGraceTime = 30;

        Ciphers = crypto.aeadCiphers;
        Macs = crypto.etmMacs;
        HostKeyAlgorithms = crypto.modernHostKeysString;
        KexAlgorithms = crypto.pqKex;

        LogLevel = "VERBOSE";

        # Upstream default (10:30:100 since OpenSSH 9.8-era) tightened to a
        # lower full-backlog cap; overridable via extraSettings.
        MaxStartups = "10:30:60";

        # Explicit rather than implicit: per-source rate-limit penalties are
        # on by default since OpenSSH 9.8 and we want that guaranteed
        # regardless of upstream flips (overridable via extraSettings).
        PerSourcePenalties = true;

        Banner = lib.mkIf (config.services.ssh-server.bannerText != null) (lib.mkDefault "/etc/ssh/banner");
      }
      // lib.optionalAttrs (config.services.ssh-server.usePam != null) {
        UsePAM = config.services.ssh-server.usePam;
      }
      // lib.optionalAttrs (config.services.ssh-server.authenticationMethods != null) {
        AuthenticationMethods = config.services.ssh-server.authenticationMethods;
      }
      // config.services.ssh-server.extraSettings;

      openFirewall = true;
      ports = [ config.services.ssh-server.port ];
      listenAddresses = map (l: {
        inherit (l) addr;
        port = if l.port != null then l.port else config.services.ssh-server.port;
      }) config.services.ssh-server.listenAddresses;
    };

    # Explicit prompt-path opt-in must be able to actually prompt. Upstream
    # nixpkgs couples security.pam.services.sshd.unixAuth to
    # PasswordAuthentication, so on a keys-only host (the point of this
    # module) the sshd PAM auth stack degrades to pam_deny and EVERY
    # keyboard-interactive prompt is refused before PAM can question the
    # user — found by the VM positive-control subtest (prompt-path proof).
    # mkForce because upstream defines a bare (priority-100) `false`; our
    # gate still respects `usePam = false` (no sshd PAM service wanted).
    security.pam.services.sshd.unixAuth = lib.mkIf (
      config.services.ssh-server.kbdInteractiveAuthentication
      && config.services.ssh-server.usePam != false
    ) (lib.mkForce true);

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
