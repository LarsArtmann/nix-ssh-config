# Test fixtures

`test-key` / `test-key.pub` are a **throwaway** ed25519 keypair generated
solely for this repo's CI: the public half is the `testKey` used in eval
fixtures, the private half is injected into the QEMU client node so the VM
integration test can prove key-based login works end to end.

The key authorizes nothing real - it only ever appears in test VMs and test
evals. Regenerate at any time with:

    ssh-keygen -t ed25519 -f tests/test-key -N "" -C nix-ssh-config-ci-test

Committing a test-only private key is the standard nixpkgs pattern for SSH
VM tests (the key must exist at evaluation time on both nodes).
