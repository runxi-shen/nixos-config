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
      # homeModules.rshen-agents from here. There are deliberately no Linux `apps`:
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

      # Exported for runxi-shen/neusis, which manages the `rshen` account on the
      # shared lab machines oppy/spirit/karkinos.
      #
      # Deliberately NARROW. neusis already configures that account well -- git
      # identity and signing, editors, themes, browsers, tailscale, GPU tools --
      # from its own homes/common/, which is shared by fifteen users. This
      # exports only what neusis's nixpkgs pin (2026-04-04) genuinely cannot
      # supply, and nothing else. In particular it does NOT pull in
      # homes/rshen/core.nix: that sets `programs.git`, and so does neusis's
      # homes/common/dev/git.nix -- two plain definitions would collide at eval.
      #
      # Ownership can migrate here one module at a time later, deleting the
      # corresponding neusis import as each replacement lands, until
      # neusis/homes/rshen/machines/oppy.nix is a single import like
      # afermg's homes/amunoz/machines/oppy.nix. This is step one of that path,
      # not a one-shot replacement.
      homeModules.rshen-agents = {
        # Namespaced so a consumer's extraSpecialArgs cannot shadow our pins;
        # see the comment in homes/rshen/agents.nix.
        _module.args = {
          inherit inputs outputs;
          rshenInputs = inputs;
        };
        imports = [ ./homes/rshen/agents.nix ];
        # No `nixpkgs.config` or `nixpkgs.overlays` here on purpose: neusis sets
        # both in homes/common/home_manager.nix, and every package this module
        # installs comes from our own inputs rather than the consumer's pkgs.
      };
      # Evaluation gate for the exported module: it catches a Darwin-only
      # package, a missing attribute, or a module error on the servers' platform
      # BEFORE a PR touches machines that fifteen people share.
      #
      #   nix eval --raw '.#homeConfigurations."rshen@oppy".activationPackage.drvPath'
      #
      # EVALUATE, do not build. `nix build` of this cannot work on a Mac:
      # home-manager generates a handful of trivial x86_64-linux derivations
      # (dummy-xdg-mime-dirs, hm_home...keep) that exist in no binary cache and
      # must be built natively, so the build dies with "required system or
      # feature not available" no matter how healthy the config is. Forcing
      # .drvPath evaluates the entire module tree, which is where our class of
      # bug lives. Add `nix.linux-builder.enable = true` if a real cross-build
      # is ever wanted.
      #
      # NOT for `home-manager switch`. neusis applies rshen's home profile at
      # system rebuild, writing its generation under
      # /nix/var/nix/profiles/per-user; a standalone switch writes to
      # ~/.local/state/nix/profiles/home-manager. Both would claim ~/.config and
      # clobber each other's symlinks. Use this with `nix build` only.
      homeConfigurations."rshen@oppy" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          outputs.homeModules.rshen-agents
          {
            home = {
              username = "rshen";
              homeDirectory = "/home/rshen";
              stateVersion = "25.11"; # matches neusis homes/common/home_manager.nix
            };
          }
        ];
      };

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
            # `inputs` is passed as a whole attrset in addition to being spread,
            # so modules can forward it to home-manager's extraSpecialArgs --
            # homes/rshen/agents.nix needs it to pin agents to this flake.
            specialArgs = inputs // { inherit user host outputs inputs; };
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

          # The second MacBook Pro -- `rshen`, matching every Linux machine in
          # the fleet. `user` is the ONLY difference from runxi-mbp above:
          # homes/rshen names no username, so both Macs share it verbatim.
          rshen-mbp = mkDarwin { host = "rshen-mbp"; user = "rshen"; };
        in
        {
          inherit runxi-mbp rshen-mbp;

          # apps/aarch64-darwin/build-switch resolves the host at runtime with
          # `scutil --get LocalHostName`. This alias exists because runxi-mbp
          # still answers "Runxis-MacBook-Pro" -- the macOS default derived from
          # its ComputerName -- so a rebuild there needs no arguments and that
          # Mac needs no rename. Same derivation, two names.
          #
          # BOTH Macs shipped with that same default name. rshen-mbp was
          # therefore renamed once, at setup, with
          #     sudo scutil --set LocalHostName rshen-mbp
          # so that this alias stays unambiguously runxi-mbp's.
          #
          # That rename is now held in place declaratively: hosts/darwin/
          # rshen-mbp.nix pins networking.{computerName,localHostName} to its
          # `host`, which nix-darwin reasserts with `scutil --set` on every
          # activation. runxi-mbp is deliberately NOT pinned -- this alias is
          # what lets it rebuild with no argument and no rename.
          #
          # The alias is also why a drift on rshen-mbp is worth catching early.
          # An unknown name fails loudly; a drift back to THIS string does not,
          # because it resolves here, and a bare `build-switch` on the new Mac
          # would then silently build the old machine's config under the wrong
          # username.
          "Runxis-MacBook-Pro" = runxi-mbp;
        };
    };
}
