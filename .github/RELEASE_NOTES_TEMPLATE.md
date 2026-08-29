# Release notes template

Copy this skeleton into the annotated tag message when cutting a release
(`scripts/release.sh` fills the tag with the dated CHANGELOG section by
default; use this template instead when the release needs a hand-written
headline or migration warning). The GitHub Release object is created with
`--notes-from-tag`, so whatever the tag says is what ships.

```markdown
nix-ssh-config v<x.y.z> — <one-line headline>

<Optional migration warning first: "if you pin vX, ...">

## Highlights

- <user-visible change>
- <user-visible change>

## Upgrade notes

- <pin this tag: github:LarsArtmann/nix-ssh-config/v<x.y.z>>
```

Checklist before tagging:

- [ ] full local gate green (see CONTRIBUTING "Gate discipline")
- [ ] CHANGELOG section dated, compare link added
- [ ] `DRY_RUN=1 ./scripts/release.sh <x.y.z>` prints the expected plan
- [ ] known runtime defects called out (see v0.1.0/v0.1.1 precedent)
