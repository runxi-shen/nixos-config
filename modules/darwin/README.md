## Darwin

macOS-specific modules. Settings that hold for **every** Mac live in
`hosts/darwin/default.nix`; anything true of one machine only lives in that host's file,
e.g. `hosts/darwin/runxi-mbp.nix`.

## Layout

```
.
├── dock               # Declarative macOS dock (entries are per-host)
├── casks.nix          # Homebrew casks; imported by the host file, so effectively per-host
├── files.nix          # Static files placed into $HOME
├── home-manager.nix   # Wires home-manager and imports homes/rshen
├── onedrive-purdue.nix # ~/Purdue_OneDrive alias + tombstone; imported by BOTH hosts
├── packages.nix       # Mac-only packages (portable ones live in homes/rshen)
└── secrets.nix        # Age-encrypted secrets via agenix
```

There is no `default.nix` here — these modules are imported explicitly by
`hosts/darwin/default.nix`.
