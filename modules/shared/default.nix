{ config, pkgs, claude-code, ... }:

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

    overlays =
      # Apply each overlay found in the /overlays directory
      let
        path = ../../overlays;
        hostname = if config.networking.hostName or null == null then "" else config.networking.hostName;
        excludeForHost = {
          "garfield" = [ "cider-appimage.nix" ];
        };
        excludedFiles = excludeForHost.${hostname} or [];
      in with builtins;
      # Declarative Claude Code from the sadjow/claude-code-nix flake input.
      # Kept inline (not a file in /overlays) because the auto-loader below
      # imports overlay files as bare `final: prev:` functions with no access
      # to flake `inputs`; here `claude-code` is in scope via module args.
      [
        (final: prev: {
          claude-code = claude-code.packages.${final.stdenv.hostPlatform.system}.default;
        })
      ]
      ++
      map (n: import (path + ("/" + n)))
          (filter (n:
            (match ".*\\.nix" n != null ||
             pathExists (path + ("/" + n + "/default.nix")))
            && !(elem n excludedFiles))
                  (attrNames (readDir path)))

      ;
  };
}
