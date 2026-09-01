{
  description = "General Purpose Configuration for macOS";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    agenix.url = "github:ryantm/agenix";
    claude-code.url = "github:sadjow/claude-code-nix";
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    secrets = {
      url = "git+ssh://git@github.com/runxi-shen/nix-secrets.git";
      flake = false;
    };
  };
  outputs = { self, darwin, claude-code, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask, home-manager, nixpkgs, agenix, secrets } @inputs:
    let
      inherit (self) outputs;
      # Kept for devShells and the Linux home closures this flake exports for
      # the lab servers. This repo owns no NixOS *system* config --
      # oppy/spirit/karkinos belong to runxi-shen/neusis, which consumes
      # homeModules.rshen from here. There are deliberately no Linux `apps`:
      # every one of them drove the nixosConfigurations that Phase 1 removed.
      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      # Apple Silicon only. nixpkgs 26.11 dropped x86_64-darwin, so keeping it
      # here manufactures a darwinConfiguration that cannot evaluate -- for a
      # machine that does not exist.
      darwinSystems = [ "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs (linuxSystems ++ darwinSystems) f;
      devShell = system: let pkgs = nixpkgs.legacyPackages.${system}; in {
        default = with pkgs; mkShell {
          nativeBuildInputs = with pkgs; [ bashInteractive git age age-plugin-yubikey ];
          shellHook = with pkgs; ''
            export EDITOR=vim
          '';
        };
      };
      mkApp = scriptName: system: {
        type = "app";
        program = "${(nixpkgs.legacyPackages.${system}.writeScriptBin scriptName ''
          #!/usr/bin/env bash
          PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
          echo "Running ${scriptName} for ${system}"
          exec ${self}/apps/${system}/${scriptName} "$@"
        '')}/bin/${scriptName}";
      };
      mkDarwinApps = system: {
        # `apply` is deliberately gone: it was upstream's fresh-install
        # onboarding script. It sed-replaced %USER% tokens across every file in
        # the tree, spliced flake.nix against a `disko` anchor Phase 1 removed,
        # and opened the upstream repo to ask for a star. Running it on a
        # configured machine would corrupt the config.
        "build" = mkApp "build" system;
        "build-switch" = mkApp "build-switch" system;
        "clean" = mkApp "clean" system;
        "copy-keys" = mkApp "copy-keys" system;
        "create-keys" = mkApp "create-keys" system;
        "check-keys" = mkApp "check-keys" system;
        "rollback" = mkApp "rollback" system;
      };
    in
    {
      # Named overlays, so an individual one stays addressable by a consuming
      # flake. See overlays/default.nix.
      overlays = import ./overlays { inherit inputs outputs; };
      devShells = forAllSystems devShell;
      apps = nixpkgs.lib.genAttrs darwinSystems mkDarwinApps;

      # Keyed by HOSTNAME, not by system. Keying by system forced every Apple
      # Silicon Mac to an identical config and could not express a second
      # machine at all. `user` is threaded per-host, which is what lets
      # `runxishen` (this Mac, no account rename) and `rshen` (every other
      # machine in the fleet) coexist -- and because homes/rshen never names a
      # user, that argument is the ONLY difference between two Macs.
      #
      # The builder is an inline `let`, mirroring afermg/nixos-config, rather
      # than a lib/default.nix: at this size the indirection costs more than it
      # saves.
      darwinConfigurations =
        let
          mkDarwin = { host, user }: darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            specialArgs = inputs // { inherit user host outputs; };
            modules = [
              home-manager.darwinModules.home-manager
              nix-homebrew.darwinModules.nix-homebrew
              ({ pkgs, ... }: {
                nix-homebrew = {
                  inherit user;
                  enable = true;
                  taps = {
                    "homebrew/homebrew-core" = homebrew-core;
                    "homebrew/homebrew-cask" = homebrew-cask;
                    "homebrew/homebrew-bundle" = homebrew-bundle;
                    # Local tap for casks not in homebrew-cask (must be a package, not a bare path)
                    "runxishen/homebrew-zenkit" = pkgs.runCommandLocal "homebrew-zenkit" { } ''
                      cp -R ${./taps/zenkit} $out
                    '';
                  };
                  mutableTaps = false;
                  autoMigrate = true;
                };
              })
              # Settings shared by every Mac, then this host's own file.
              ./hosts/darwin
              (./hosts/darwin + "/${host}.nix")
            ];
          };

          runxi-mbp = mkDarwin { host = "runxi-mbp"; user = "runxishen"; };
        in
        {
          inherit runxi-mbp;

          # apps/aarch64-darwin/build-switch resolves the host at runtime with
          # `scutil --get LocalHostName`, which on this machine returns
          # "Runxis-MacBook-Pro". Aliased to the same system so a rebuild needs
          # no arguments and the Mac needs no rename. Same derivation, two
          # names -- it costs nothing.
          "Runxis-MacBook-Pro" = runxi-mbp;

          # New MacBook Pro -- `rshen`, matching every Linux machine. Add
          # hosts/darwin/rshen-mbp.nix and uncomment when it is in hand.
          # "rshen-mbp" = mkDarwin { host = "rshen-mbp"; user = "rshen"; };
        };
    };
}
