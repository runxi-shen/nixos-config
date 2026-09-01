# Shared across every Mac. `user` comes from mkDarwin's specialArgs; per-host
# content (casks, dock entries, cloud links) lives in hosts/darwin/<host>.nix.
{ config, pkgs, lib, home-manager, user, ... }:

let
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
    # `casks` is per-host -- see hosts/darwin/<host>.nix.
    enable = true;

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
    users.${user} = { pkgs, lib, ... }: {
      # The portable profile. nix-darwin has already set home.username and
      # home.homeDirectory from `users.users.${user}` above, and a plain
      # definition outranks the mkDefault inside homes/rshen/core.nix, so
      # this Mac stays `runxishen` while the servers stay `rshen`.
      imports = [ ../../homes/rshen ];

      home = {
        enableNixpkgsReleaseCheck = false;
        packages = pkgs.callPackage ./packages.nix {};
        file = lib.mkMerge [
          sharedFiles
          additionalFiles
        ];
        stateVersion = "23.11";
      };
      manual.manpages.enable = false;
    };
  };

  # Fully declarative dock. `entries` is per-host and has no default -- each
  # host file must declare its own; see hosts/darwin/<host>.nix.
  local.dock = {
    enable   = true;
    username = user;
  };
}
