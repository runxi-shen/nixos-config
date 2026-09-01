# Named overlays, exported as the flake output `outputs.overlays`.
#
# Deliberately NOT the directory-scanning auto-loader this repo used to carry.
# That loader mapped every *.nix in this directory into an anonymous list, so an
# individual overlay could not be referenced from anywhere else -- and
# `homeModules.rshen` has to hand one specific overlay to a *consuming* flake
# (neusis), which requires it to have a name.
#
# Pattern taken from afermg/nixos-config's overlays/default.nix.
{ inputs, ... }:
{
  # Declarative Claude Code from the sadjow/claude-code-nix flake input.
  # Previously inlined in modules/shared/default.nix, because the old
  # auto-loader imported overlay files as bare `final: prev:` functions with no
  # access to flake inputs. Taking `inputs` as an argument here removes that
  # constraint, so the overlay can live with its siblings.
  claude-code = final: _prev: {
    claude-code = inputs.claude-code.packages.${final.stdenv.hostPlatform.system}.default;
  };

  # Kept in its own file: the comment explaining the upstream breakage is the
  # thing that tells us when it is safe to delete.
  pandas-stubs = import ./pandas-stubs-skip-tests.nix;
}
