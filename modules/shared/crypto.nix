{lib}: let
  join = lib.concatStringsSep ",";

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
  inherit pqKex aeadCiphers etmMacs modernHostKeys;

  pqKexString = join pqKex;
  aeadCiphersString = join aeadCiphers;
  etmMacsString = join etmMacs;
  modernHostKeysString = join modernHostKeys;
}
