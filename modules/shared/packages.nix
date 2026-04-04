{ pkgs, ... }:
let
  myPython = pkgs.python3.withPackages (ps: with ps; [
    pip
    virtualenv
    requests
    pyyaml
  ]);

  myFonts = import ./fonts.nix { inherit pkgs; };
in
with pkgs; [
  # Encryption & security
  age                    # File encryption tool (used by agenix)
  age-plugin-yubikey     # YubiKey plugin for age encryption
  gnupg                  # GNU Privacy Guard
  libfido2               # FIDO2 library
  openssh                # SSH client and server

  # CLI essentials
  bat                    # Cat clone with syntax highlighting
  btop                   # System monitor and process viewer
  coreutils              # Basic file/text/shell utilities
  curl                   # URL transfer tool
  difftastic             # Structural diff tool
  dust                   # Disk usage analyzer
  fd                     # Fast find alternative
  fzf                    # Fuzzy finder
  glow                   # Markdown renderer for terminal
  htop                   # Interactive process viewer
  jq                     # JSON processor
  killall                # Kill processes by name
  ncdu                   # Disk space utility
  ripgrep                # Fast text search tool
  tmux                   # Terminal multiplexer
  tree                   # Directory tree viewer
  wget                   # File downloader

  # Dev tools
  direnv                 # Environment variable management per directory
  gcc                    # GNU Compiler Collection
  gh                     # GitHub CLI
  git                    # Version control (also managed by home-manager)
  go                     # Go programming language
  gopls                  # Go language server
  nodejs_20              # Node.js JavaScript runtime
  myPython               # Python 3 with common packages
  sqlite                 # SQL database engine
  uv                     # Python package installer

  # Editors
  zed-editor             # Modern code editor

  # Archives
  unrar                  # RAR archive extractor
  unzip                  # ZIP archive extractor
  zip                    # ZIP archive creator

  # Shell
  bash-completion        # Bash completion scripts
  zsh-powerlevel10k      # Zsh theme
] ++ myFonts
