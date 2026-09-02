# Settings shared by EVERY Mac. Anything true of one machine but not the other
# belongs in that host's own file, hosts/darwin/<host>.nix.
#
# `user` arrives from mkDarwin's specialArgs -- it is per-host, which is what
# lets this Mac stay `runxishen` while every other machine is `rshen`.
{ agenix, config, pkgs, user, ... }:

{
  imports = [
    ../../modules/darwin/secrets.nix
    ../../modules/darwin/home-manager.nix
    ../../modules/shared
    agenix.darwinModules.default
  ];
  # Nix settings shared by every Mac. `nix.enable` is deliberately NOT set here:
  # whether nix-darwin manages the daemon depends on how Nix was installed on
  # that machine, so each host declares it. Determinate Nix manages its own
  # daemon and requires `enable = false`; a Mac installed with the upstream
  # installer wants `true`.
  #
  # Note that everything below is inert while `nix.enable = false` -- nix-darwin
  # writes no /etc/nix/nix.conf at all in that mode, so on such a host these
  # substituters and trusted-users must be configured in Determinate's own
  # config instead.
  nix = {
    package = pkgs.nix;
    settings = {
      trusted-users = [ "@admin" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      # Both substituters need their signing key here. Listing a substituter
      # without its key is worse than omitting it: Nix contacts the cache and
      # then rejects everything it serves as unsigned, so you pay the latency
      # and still build from source. The nix-community key was only ever in
      # modules/shared/cachix/, which nothing imported.
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    # Turn this on to make command line easier
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  # System-wide packages only. Everything else is user-level, supplied by the
  # portable profile in homes/rshen -- which is what lets the same set ship to
  # the lab servers, where we control no system config.
  environment.systemPackages = [
    agenix.packages."${pkgs.system}".default
  ];

  # Authenticate sudo with Touch ID. Every rebuild needs sudo (see
  # nix-darwin#1457), so this is the difference between typing a password on
  # every switch and touching the sensor.
  #
  # Writes /etc/pam.d/sudo_local rather than patching /etc/pam.d/sudo, which is
  # why it survives macOS updates -- Apple replaces sudo but leaves sudo_local.
  # Still requires an interactive session: it cannot rescue a rebuild driven
  # from a process with no TTY.
  security.pam.services.sudo_local.touchIdAuth = true;

  system = {
    # Turn off NIX_PATH warnings now that we're using flakes
    checks.verifyNixPath = false;
    primaryUser = user;
    stateVersion = 4;
    defaults = {
      LaunchServices = {
        LSQuarantine = false;
      };
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;

        # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2;

        # 120, 94, 68, 35, 25, 15
        InitialKeyRepeat = 15;
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };
      dock = {
        autohide = false;
        show-recents = false;
        launchanim = true;
        mouse-over-hilite-stack = true;
        orientation = "bottom";
        tilesize = 48;
      };
      finder = {
        _FXShowPosixPathInTitle = false;
      };
      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
    };
  };
}
