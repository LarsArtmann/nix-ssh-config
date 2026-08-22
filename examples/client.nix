# Example Home Manager SSH client configuration.
#
# Import this module into your Home Manager configuration:
#
#   homeConfigurations.you = home-manager.lib.homeManagerConfiguration {
#     modules = [
#       nix-ssh-config.homeManagerModules.ssh
#       nix-ssh-config.examples.client
#     ];
#   };
{
  ssh-config = {
    enable = true;

    # Falls back to ~/.ssh/id_ed25519; override for unusual setups.
    # identityFile = "~/.ssh/id_ed25519";

    hosts = {
      bastion = {
        hostname = "203.0.113.10";
        user = "admin";
        port = 2222;
      };

      # user omitted: inherits ssh-config.user
      webserver = {
        hostname = "198.51.100.42";
        serverAliveInterval = 30;
      };

      # Advanced: jump host, X11 and port forwarding.
      workstation = {
        hostname = "192.168.1.50";
        forwardX11 = true;
        proxyJump = "bastion";
        localForwards = [
          {
            bind.port = 8080;
            host.address = "10.0.0.13";
            host.port = 80;
          }
        ];
        dynamicForwards = [ { port = 1080; } ];
      };

      # Anything else, using upstream directive names.
      legacy-appliance = {
        hostname = "192.168.1.99";
        extraOptions = {
          KexAlgorithms = "+diffie-hellman-group14-sha256";
          HostKeyAlgorithms = "+ssh-rsa";
        };
      };
    };

    # extraIncludes = [ "~/.ssh/work-config" ];
  };
}
