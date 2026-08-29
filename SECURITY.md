# Security Policy

## Reporting a vulnerability

Open a GitHub issue only for non-sensitive, already-public problems. For
anything that could expose a live system, email the maintainer directly or
use GitHub's private vulnerability reporting
(Security → Report a vulnerability) instead of a public issue.

## Threat model and security posture

The canonical threat model, crypto rationale and hardening defaults live in
[README.md](README.md) (section "Security" / "Why these algorithms"). This
file is a pointer, not a duplicate — single-home rule.

## Supported versions

Only the latest tagged release receives fixes: see
https://github.com/LarsArtmann/nix-ssh-config/releases
Older tags are kept for reproducibility; the CHANGELOG warns when a release
shipped with a known runtime defect.
