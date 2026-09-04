_:

[
  # Development Tools
  "claude"
  "visual-studio-code"
  "wezterm"

  # Communication Tools
  "discord"
  "slack"
  "zoom"

  # Networking
  "tailscale-app"

  # Utility Tools
  "1password"
  # Cask rather than nixpkgs' bitwarden-desktop: a GUI password manager wants a
  # real /Applications bundle for Spotlight, browser integration and Touch ID
  # unlock. Nix-installed .app bundles reach ~/Applications as store symlinks,
  # which Spotlight does not index.
  "bitwarden"
  "appcleaner"
  "raycast"

  # Cloud Storage
  # Microsoft's macOS client, which nixpkgs does not carry -- its `onedrive` is
  # the unrelated abraunegg Linux CLI. The cask installs OneDrive.pkg and the
  # app self-updates, so nix-darwin never has to chase its version.
  #
  # The clean ~/Purdue_OneDrive alias, and the tombstone that suppresses the
  # space-laden "OneDrive - purdue.edu" shortcut, come from
  # modules/darwin/onedrive-purdue.nix -- installing the cask alone is not
  # enough to keep that folder from appearing.
  "onedrive"

  # AI Assistants
  "chatgpt"

  # Productivity
  "obsidian"
  "zotero"
  # From local tap (taps/zenkit)
  "runxishen/zenkit/zenkit-todo"

  # Graphics & Design
  "inkscape"

  # Entertainment
  "vlc"

  # Browsers
  "google-chrome"
]
