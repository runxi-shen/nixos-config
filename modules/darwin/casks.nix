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
