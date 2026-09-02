## Shared

Cross-platform pieces that are **not** part of the home profile. The home profile itself
lives in `homes/rshen/` — `programs`, packages, and everything user-level moved there when
it was made exportable.

## Layout

```
.
├── config             # Non-Nix config assets (wezterm.lua)
├── default.nix        # nixpkgs config + applies outputs.overlays
├── files.nix          # Static files placed into $HOME
└── fonts.nix          # Font package list, consumed by homes/rshen/gui.nix
```
