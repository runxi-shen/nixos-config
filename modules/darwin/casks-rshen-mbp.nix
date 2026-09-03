# Casks for rshen-mbp. Per-host by nature -- see modules/darwin/casks.nix for
# the other Mac's list. Deliberately a trimmed subset of that one: discord,
# 1password, raycast and appcleaner are on runxi-mbp but not wanted here.
#
# Everything portable (CLI, coding agents, fonts, alacritty, zed) arrives from
# homes/rshen instead and needs no entry here.
_:

[
  # Development Tools
  "claude"
  "visual-studio-code"
  "wezterm"

  # Communication Tools
  "slack"
  "zoom"

  # Networking
  # How this Mac reaches oppy/spirit/karkinos off-campus; those machines get
  # their half of tailscale from neusis.
  "tailscale-app"

  # Utility Tools
  # Cask rather than nixpkgs' bitwarden-desktop: a GUI password manager wants a
  # real /Applications bundle for Spotlight, browser integration and Touch ID
  # unlock. Nix-installed .app bundles reach ~/Applications as store symlinks,
  # which Spotlight does not index.
  "bitwarden"

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
