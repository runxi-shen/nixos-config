# Lab-server extras. These are the packages that live in
# runxi-shen/neusis `homes/rshen/home.nix` today; they move here so the server
# profile has a single source of truth.
#
# Deliberately NOT in ../packages.nix: they are server-shaped (a data warehouse,
# two Python environment managers, a secret scanner for pre-push hooks) and the
# Macs do not need them.
#
# `claude-code` is intentionally absent -- ../dev.nix already provides it via
# this flake's overlay, which replaces neusis's separate `claude-code-rshen`
# input.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cmake # C build system
    duckdb # In-process analytical database
    gitleaks # Secret scanner for local pre-commit/pre-push hooks
    pixi # Conda-compatible package manager
    poetry # Python dependency management
    procps # ps and friends
    rsync # Sync data between hosts
    screen # Detachable sessions for long-running SSH work
  ];
}
