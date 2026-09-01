{ outputs, ... }:

{

  nixpkgs = {
    config = {
      allowUnfree = true;
      #cudaSupport = true;
      #cudaCapabilities = ["8.0"];
      allowBroken = true;
      allowInsecure = false;
      allowUnsupportedSystem = true;
    };

    # Every named overlay from overlays/default.nix. Named rather than
    # directory-scanned so that a single overlay stays addressable as
    # `outputs.overlays.<name>` for consumers of `homeModules.rshen`.
    overlays = builtins.attrValues outputs.overlays;
  };
}
