{ agenix, config, pkgs, ... }:
let 
  user = "runxishen";
in
{
  imports = [
    ../../modules/darwin/secrets.nix
    ../../modules/darwin/home-manager.nix
    ../../modules/shared
    agenix.darwinModules.default
  ];
  # Setup user, packages, programs
  nix = {
    enable = false;
    package = pkgs.nix;
    settings = {
      trusted-users = [ "@admin" "${user}" ];
      substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    };
    # Turn this on to make command line easier
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
  # Load configuration that is shared across systems
  environment.systemPackages = with pkgs; [
    agenix.packages."${pkgs.system}".default
  ] ++ (import ../../modules/shared/packages.nix { inherit pkgs; });

  # Codex (Rust/rustls) trusts the Obsidian Local REST API's self-signed cert.
  # It reads CODEX_CA_CERTIFICATE, which is ADDITIVE to the native root store,
  # so this cannot affect trust for any other connection. Set via launchd so
  # the ChatGPT.app GUI inherits it -- it is not started from a shell, and
  # `launchctl setenv` does not survive a reboot.
  # NB: the cert expires 2027-06-14; ~/.codex/scripts/obsidian_ca_env.sh
  # re-exports it from the Obsidian plugin config when it rotates.
  launchd.user.envVariables.CODEX_CA_CERTIFICATE =
    "/Users/${user}/.claude/obsidian-local-rest-api.pem";

  # dsh (DeepSeek Harness) web UI. Owned by launchd rather than a shell so it
  # survives terminal exits and logouts, and KeepAlive restarts it if it dies.
  # ThrottleInterval stops a missing/broken npm tree from hot-looping.
  # WorkingDirectory is the agent's workspace root -- deliberately a dedicated
  # empty dir, since the harness ships bash and filesystem tools and would
  # otherwise take whatever directory it was launched from.
  # See modules/darwin/packages.nix for why node needs --expose-internals.
  launchd.user.agents.dsh-web = {
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      WorkingDirectory = "/Users/${user}/dsh-workspace";
      StandardOutPath = "/tmp/dsh-web.out.log";
      StandardErrorPath = "/tmp/dsh-web.err.log";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "exec ${pkgs.nodejs_22}/bin/node --expose-internals \"$HOME/.local/share/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js\" web --no-open --port 3080"
      ];
    };
  };

  #launchd.user.agents = {
  #  emacs = {
  #    path = [ config.environment.systemPath ];
  #    serviceConfig = {
  #      KeepAlive = true;
  #      ProgramArguments = [
  #        "/bin/sh"
  #        "-c"
  #        "{ osascript -e 'display notification \"Attempting to start Emacs...\" with title \"Emacs Launch\"'; /bin/wait4path ${pkgs.emacs}/bin/emacs && { ${pkgs.emacs}/bin/emacs --fg-daemon; if [ $? -eq 0 ]; then osascript -e 'display notification \"Emacs has started.\" with title \"Emacs Launch\"'; else osascript -e 'display notification \"Failed to start Emacs.\" with title \"Emacs Launch\"' >&2; fi; } } &> /tmp/emacs_launch.log"
  #      ];
  #      StandardErrorPath = "/tmp/emacs.err.log";
  #      StandardOutPath = "/tmp/emacs.out.log";
  #    };
  #  };
  #};

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
