# Coding agents, deliberately sourced from THIS flake's inputs rather than from
# the ambient `pkgs`.
#
# Why: runxi-shen/neusis consumes this module for the lab servers, and neusis
# pins nixpkgs at 2026-04-04. That pin has NO `pi-coding-agent` at all and only
# `codex` 0.92.0. Taking these from the consumer's `pkgs` would therefore either
# fail to evaluate or silently install a stale agent -- and bumping neusis's
# nixpkgs is not an option, because that rebuilds shared machines for ~15 users.
#
# This is the pattern from afermg/nixos-config's homes/amunoz/packages.nix,
# which hit the identical problem with the identical package:
#
#     latestPiCodingAgent =
#       inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent;
#
# `rshenInputs` rather than plain `inputs` is what makes it hold: a consuming
# flake passes its own `inputs` through home-manager's extraSpecialArgs, which
# would shadow ours and quietly undo the pinning. homeModules.rshen-agents sets
# `_module.args.rshenInputs = inputs`, and that namespaced name cannot collide.
#
# Deliberately NOT in ./dev.nix or ./packages.nix: those are not exported, and
# this module must stay importable on its own by a consumer that already has its
# own git, shell and editor configuration.
{ pkgs, inputs, rshenInputs ? inputs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) system;

  # legacyPackages, not `import rshenInputs.nixpkgs { ... }`: it is the cached
  # instantiation, so this costs an attribute lookup rather than a second full
  # nixpkgs evaluation. None of these three are unfree today; if one ever
  # becomes unfree this must switch to an explicit import with allowUnfree,
  # because legacyPackages carries no nixpkgs.config.
  ourPkgs = rshenInputs.nixpkgs.legacyPackages.${system};
in
{
  home.packages = [
    # 0.144.4 here vs 0.92.0 in neusis's pin.
    ourPkgs.codex

    # Absent entirely from neusis's pin. Upstream is earendil-works/pi, which is
    # the same repository as the older badlogic/pi-mono path (GitHub repo id
    # 1035029907 -- the old path is a transfer redirect). Binary is `pi`.
    ourPkgs.pi-coding-agent

    # From the claude-code flake input rather than the overlay: an overlay would
    # have to be applied to the consumer's pkgs, and neusis already sets
    # nixpkgs.overlays itself in homes/common/home_manager.nix. Taking the
    # package straight from the input keeps this module free of any opinion
    # about how the consumer builds its pkgs.
    #
    # NOTE for the neusis side: its homes/rshen/home.nix installs claude-code
    # from its own `claude-code-rshen` input. Both provide bin/claude, so that
    # line must be removed when this module is imported or home.packages fails
    # with a collision.
    rshenInputs.claude-code.packages.${system}.default
  ];
}
