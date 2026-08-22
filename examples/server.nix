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
# Defaults you get without touching anything: password and root login off,
# pubkey-only auth, modern crypto only (ML-KEM hybrid KEX first), X11/TCP/
# tunnel forwarding off, MaxAuthTries=3, MaxSessions=2, verbose logging and
# a legal banner.
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

    # Escape hatch for any sshd_config directive not modeled above.
    # Merges last, so it can override defaults:
    # extraSettings.LoginGraceTime = 30;
  };
}
