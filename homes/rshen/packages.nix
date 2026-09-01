# Portable CLI. Everything here must build and be useful on both aarch64-darwin
# and x86_64-linux -- this list ships to the lab servers unchanged.
#
# Anything Mac- or desktop-only belongs in ./gui.nix; anything specific to one
# server belongs in ./machines/<host>.nix.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Encryption & security
    age # File encryption tool (used by agenix)
    gnupg # GNU Privacy Guard
    libfido2 # FIDO2 library
    openssh # SSH client and server

    # CLI essentials
    bat # Cat clone with syntax highlighting
    btop # System monitor and process viewer
    coreutils # Basic file/text/shell utilities
    curl # URL transfer tool
    difftastic # Structural diff tool
    dust # Disk usage analyzer
    fd # Fast find alternative
    fzf # Fuzzy finder
    glow # Markdown renderer for terminal
    htop # Interactive process viewer
    jq # JSON processor
    killall # Kill processes by name
    ncdu # Disk space utility
    ripgrep # Fast text search tool
    tmux # Terminal multiplexer
    tree # Directory tree viewer
    wget # File downloader

    # OCR & document processing
    ocrmypdf # Add a searchable text layer to scanned PDFs (uses tesseract + ghostscript)
    poppler-utils # pdftoppm / pdftotext / pdfinfo -- render and extract PDFs
    tesseract # OCR engine

    # Archives
    unrar # RAR archive extractor
    unzip # ZIP archive extractor
    zip # ZIP archive creator

    # Shell
    bash-completion # Bash completion scripts
    zsh-powerlevel10k # Zsh theme
  ];
}
