# Desktop-only: fonts, a terminal emulator, a GUI editor. The lab servers are
# headless and get none of it.
#
# Always imported by ./default.nix and gated here instead, because `imports`
# cannot branch on `pkgs` -- see the comment there.
{ pkgs, lib, ... }:

let
  myFonts = import ../../modules/shared/fonts.nix { inherit pkgs; };
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.packages = with pkgs; [
      age-plugin-yubikey # YubiKey plugin for age encryption
      ngrok # Secure tunnels to localhost
      zed-editor # Modern code editor
    ] ++ myFonts;

    programs.alacritty = {
      enable = true;
      settings = {
        cursor = {
          style = "Block";
        };

        window = {
          opacity = 1.0;
          padding = {
            x = 24;
            y = 24;
          };
        };

        # Fix for shell path when launching from desktop
        # When launching from desktop, $SHELL may point to /bin/zsh instead of
        # the Nix-managed shell, causing environment issues
        terminal.shell = {
          program = "${pkgs.zsh}/bin/zsh";
        };

        font = {
          normal = {
            family = "MesloLGS NF";
            style = "Regular";
          };
          # Was an isLinux-10 / isDarwin-14 mkMerge. This module only
          # evaluates on Darwin now, so the Linux branch was dead.
          size = 14;
        };

        colors = {
          primary = {
            background = "0x1f2528";
            foreground = "0xc0c5ce";
          };

          normal = {
            black = "0x1f2528";
            red = "0xec5f67";
            green = "0x99c794";
            yellow = "0xfac863";
            blue = "0x6699cc";
            magenta = "0xc594c5";
            cyan = "0x5fb3b3";
            white = "0xc0c5ce";
          };

          bright = {
            black = "0x65737e";
            red = "0xec5f67";
            green = "0x99c794";
            yellow = "0xfac863";
            blue = "0x6699cc";
            magenta = "0xc594c5";
            cyan = "0x5fb3b3";
            white = "0xd8dee9";
          };
        };
      };
    };
  };
}
