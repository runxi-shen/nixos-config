# THE portable profile. Imported by:
#   - this flake's Macs, via modules/darwin/home-manager.nix
#   - `homeModules.rshen`, which runxi-shen/neusis consumes for the lab servers
#
# Invariant: nothing under homes/ may name a concrete username or an absolute
# home path. `home.username` and `home.homeDirectory` are supplied by the
# consumer; everything else derives from them. The invariant is enforced
# mechanically by a grep over this directory, so keep concrete usernames and
# absolute home paths out of comments here too, or the guard stops being one.
{ ... }:

{
  imports = [
    ./core.nix
    ./packages.nix
    ./dev.nix
    # Also exported on its own as homeModules.rshen-agents, which is what the
    # lab servers import. Kept as a separate file so this Mac and those servers
    # share one definition of "which coding agents I run".
    ./agents.nix
    # Imported unconditionally and gated internally with mkIf, NOT via
    # `lib.optional pkgs.stdenv.hostPlatform.isDarwin`. `pkgs` reaches a module
    # through `_module.args`, which is part of `config`, and `imports` is
    # resolved before `config` exists -- so branching on pkgs here is an
    # infinite recursion. Headless servers get nothing from it.
    ./gui.nix
  ];
}
