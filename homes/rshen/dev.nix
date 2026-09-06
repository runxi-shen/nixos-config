# Development toolchain for the full profile. Keep it portable so individual
# pieces can move into the exported Linux module later, but today the lab
# servers import only agents.nix.
#
# Mac-only dev tools go in modules/darwin/packages.nix instead. The bar for this
# file is "this is appropriate on every platform using the full profile".
{ pkgs, ... }:

let
  myPython = pkgs.python3.withPackages (ps: with ps; [
    pip
    virtualenv
    requests
    pyyaml
  ]);
in
{
  home.packages = with pkgs; [
    # claude-code, codex and pi-coding-agent live in ./agents.nix -- they are
    # pinned to this flake's own inputs so the export stays version-stable.
    direnv # Environment variable management per directory
    gcc # GNU Compiler Collection
    gh # GitHub CLI
    git # Version control (also managed by home-manager)
    glab # GitLab CLI
    go # Go programming language
    gopls # Go language server
    nodejs_22 # Node.js JavaScript runtime (LTS)
    myPython # Python 3 with common packages
    pnpm # Fast npm alternative; `dsh plugin` forwards to it
    sqlite # SQL database engine
    uv # Python package installer
  ];
}
