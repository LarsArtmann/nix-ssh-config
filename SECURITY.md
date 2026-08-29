# Security Policy

## Reporting a vulnerability

**Preferred (sensitive):** GitHub private vulnerability reporting — open
this repository, then **Security → Report a vulnerability**. It reaches
the maintainer privately, supports back-and-forth discussion, and can
publish a security advisory with the fix. No email or GPG setup needed.

**Only for non-sensitive, already-public problems:** open a regular
GitHub issue.

Please include: affected version/tag (or commit), the module and option
configuration involved, and what a minimal reproduction looks like. This
repo ships configuration, not a runtime daemon — reports about how the
_generated_ sshd config behaves on your host should say so explicitly.

## Threat model and security posture

The canonical threat model, crypto rationale and hardening defaults live in
[README.md](README.md) (section "Security" / "Why these algorithms"). This
file is a pointer, not a duplicate — single-home rule.

## Supported versions

Only the latest tagged release receives fixes: see
https://github.com/LarsArtmann/nix-ssh-config/releases
Older tags are kept for reproducibility; the CHANGELOG warns when a release
shipped with a known runtime defect.
