{ pkgs, config, ... }:

let
  githubPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILTZMeibxIvdsdp2I4QUDS+58d1NB8fN75dCTV+r5v9i shenrunxi@gmail.com";
in

{
  ".ssh/id_github.pub" = {
    text = githubPublicKey;
  };

  ".config/wezterm/wezterm.lua" = {
    source = ./config/wezterm.lua;
  };
}
