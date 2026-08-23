{ config, pkgs, lib, home-manager, ... }:

let
  user           = "runxishen";
  sharedFiles     = import ../shared/files.nix { inherit config pkgs; };
  additionalFiles = import ./files.nix { inherit user config pkgs; };
in
{
  imports = [
    ./dock
  ];

  users.users.${user} = {
    name     = "${user}";
    home     = "/Users/${user}";
    isHidden = false;
    shell    = pkgs.zsh;
  };

  homebrew = {
    # This is a module from nix-darwin
    # Homebrew is *installed* via the flake input nix-homebrew

    # These app IDs are from using the mas CLI app
    # mas = mac app store
    # https://github.com/mas-cli/mas
    #
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    #
    enable = true;
    casks  = pkgs.callPackage ./casks.nix {};

    # Both of these already default to false upstream; set explicitly so a
    # future default change can't silently start upgrading casks on rebuild.
    # VS Code in particular must stay pinned: Remote-SSH requires the remote
    # server to match the client's exact commit hash, and karkinos pulls that
    # 223MB server from Microsoft's CDN at ~150KB/s (~25 min per version bump).
    onActivation = {
      upgrade    = false;
      autoUpdate = false;
    };
    #masApps = {
    #  "hidden-bar"   = 1452453066;
    #  "wireguard"    = 1451685025;
    #};
  };

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "backup";
    users.${user} = { pkgs, config, lib, ... }:
      let
        # Clean-named shortcuts to cloud sync roots.
        #
        # mkOutOfStoreSymlink is essential here: a plain `source` would try to
        # copy the target into the nix store, which for a live cloud folder
        # would be catastrophic. This emits a direct symlink to the real path.
        #
        # The sync roots themselves are NEVER renamed — OneDrive's lives under
        # ~/Library/CloudStorage and is managed by the macOS File Provider API,
        # and Nutstore records its root path in ~/.nutstore/db/nutstore.db.
        # These are additive aliases only.
        cloudLinks = {
          "Purdue_OneDrive".source = config.lib.file.mkOutOfStoreSymlink
            "/Users/${user}/Library/CloudStorage/OneDrive-purdue.edu";

          "Nutstore".source = config.lib.file.mkOutOfStoreSymlink
            "/Users/${user}/NutstoreFiles/Nutstore";
        };
      in
      {
        home = {
          enableNixpkgsReleaseCheck = false;
          packages = pkgs.callPackage ./packages.nix {};
          file = lib.mkMerge [
            sharedFiles
            additionalFiles
            cloudLinks
          ];
          stateVersion = "23.11";

          # Squat the path OneDrive uses for its own home-folder shortcut, so
          # the space-laden "OneDrive - purdue.edu" cannot come back after an
          # app update. OneDrive exposes no preference to disable it.
          #
          # A 0-byte file with uchg makes OneDrive's unlink() fail with EPERM,
          # and its symlink() then fails with EEXIST. `hidden` keeps it out of
          # Finder. Use ~/Purdue_OneDrive (declared above) instead.
          #
          # To undo:  chflags nouchg ~/"OneDrive - purdue.edu" && rm ~/"OneDrive - purdue.edu"
          activation.onedriveShortcutTombstone =
            lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              p="$HOME/OneDrive - purdue.edu"
              # Only ever replace a symlink or nothing — never a real file.
              if [ -L "$p" ] || [ ! -e "$p" ]; then
                /usr/bin/chflags nouchg "$p" 2>/dev/null || true
                rm -f "$p" || true
                touch "$p" || true
              fi
              /usr/bin/chflags uchg,hidden "$p" 2>/dev/null || true
            '';
        };
        programs = {} // import ../shared/home-manager.nix { inherit config pkgs lib; };
        manual.manpages.enable = false;
      };
  };

  # Fully declarative dock using the latest from Nix Stor
  local.dock = {
    enable   = true;
    username = user;
    entries  = [
      { path = "/Applications/Slack.app/"; }
      { path = "/System/Applications/Messages.app/"; }
      { path = "${pkgs.alacritty}/Applications/Alacritty.app/"; }
      { path = "/System/Applications/Music.app/"; }
      { path = "/Applications/Google Chrome.app/"; }
      { path = "/Applications/Visual Studio Code.app/"; }
      { path = "/Applications/Claude.app/"; }
      { path = "/Applications/Discord.app/"; }
      {
        path    = "${config.users.users.${user}.home}/.local/share/";
        section = "others";
        options = "--sort name --view grid --display folder";
      }
      {
        path    = "${config.users.users.${user}.home}/.local/share/downloads";
        section = "others";
        options = "--sort name --view grid --display stack";
      }
    ];
  };
}
