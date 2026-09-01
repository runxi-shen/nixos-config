# Development toolchain. Portable: the lab servers get exactly this set too,
# which is the point of exporting the profile rather than duplicating it in
# neusis.
{ pkgs, ... }:

let
  myPython = pkgs.python3.withPackages (ps: with ps; [
    pip
    virtualenv
    requests
    pyyaml
    markitdown # Convert files/office docs to Markdown (CLI + library)
  ]);
in
{
  home.packages = with pkgs; [
    claude-code # Anthropic Claude Code CLI (declarative via the claude-code overlay)
    codex # OpenAI Codex CLI coding agent
    direnv # Environment variable management per directory
    gcc # GNU Compiler Collection
    gh # GitHub CLI
    git # Version control (also managed by home-manager)
    glab # GitLab CLI
    go # Go programming language
    gopls # Go language server
    markitdown-mcp # MCP server exposing markitdown to AI tools
    nodejs_22 # Node.js JavaScript runtime (LTS)
    myPython # Python 3 with common packages
    pi-coding-agent # Pi coding agent CLI (read/bash/edit/write tools)
    pnpm # Fast npm alternative; `dsh plugin` forwards to it
    sqlite # SQL database engine
    uv # Python package installer
  ];
}
