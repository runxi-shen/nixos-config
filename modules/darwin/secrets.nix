{ config, pkgs, agenix, secrets, ... }:

let user = "runxishen"; in
{
  age = {
    identityPaths = [
      "/Users/${user}/.ssh/id_ed25519"
    ];

    # Secrets will be added here as .age files are created in the nix-secrets repo
    # Example:
    # secrets = {
    #   "github-ssh-key" = {
    #     symlink = true;
    #     path = "/Users/${user}/.ssh/id_github";
    #     file = "${secrets}/github-ssh-key.age";
    #     mode = "600";
    #     owner = "${user}";
    #     group = "staff";
    #   };
    # };
    secrets = {};
  };
}
