# Example NixOS SSH server configuration.
#
# Import this module into your NixOS configuration:
#
#   nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
#     modules = [
#       nix-ssh-config.nixosModules.ssh
#       nix-ssh-config.examples.server
#     ];
#   };
#
# Defaults you get without touching anything: password, keyboard-interactive
# and root login off, pubkey-only auth, modern crypto only (ML-KEM hybrid KEX
# first), X11/TCP/tunnel forwarding off, MaxAuthTries=3, MaxSessions=2,
# verbose logging and a legal banner.
{
  services.ssh-server = {
    enable = true;

    # Users permitted to connect at all (empty = no restriction beyond
    # authentication).
    allowUsers = [ "youruser" ];

    # Public keys authorized for every user account on the host.
    authorizedKeys = [
      # "ssh-ed25519 AAAA... you@machine"
    ];

    # Everything else is optional: defaults are hardened.
    # port = 22;
    # bannerText = null;  # disable the legal banner

    # PAM-backed two-factor auth? keyboard-interactive follows
    # passwordAuthentication by default; opt in explicitly:
    # kbdInteractiveAuthentication = true;
    # authenticationMethods = "publickey,keyboard-interactive";
    # (both factors required, in that order). The module also pins
    # security.pam.services.sshd.unixAuth = true for the explicit
    # prompt-path opt-in — upstream nixpkgs would otherwise pam_deny
    # every prompt on a keys-only host.

    # Escape hatch for any sshd_config directive not modeled above.
    # Merges last, so it can override module defaults (LoginGraceTime is
    # already pinned to a hardened 30s by the module itself):
    # extraSettings.MaxAuthTries = 2;
  };

  # Per-user keys: authorize specific keys for one account without adding
  # them to the global authorizedKeys above (evaluated, so this example
  # really builds; adjust user and key to your setup).
  users.users.youruser = {
    isNormalUser = true;
    description = "Your login user";
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... laptop"  (empty by default; add your keys)
    ];
  };
}
