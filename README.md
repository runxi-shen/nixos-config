# nixos-config

[![Statix Lint](https://github.com/runxi-shen/nixos-config/actions/workflows/lint.yml/badge.svg)](https://github.com/runxi-shen/nixos-config/actions/workflows/lint.yml)

Runxi Shen's Nix flake. It configures **Macs as full nix-darwin systems** and exports a
**portable home-manager profile** for Linux machines whose system config lives elsewhere.

## What this owns, and what it doesn't

```
runxi-shen/nixos-config  ──homeModules.rshen-agents──>  shntnu/neusis
   Macs (nix-darwin)                                    oppy · spirit · karkinos
   the home profile                                     shared lab servers, ~15 users
```

The Linux machines are **shared lab servers**. Their system configuration belongs to
`shntnu/neusis` and is not managed here — only the home half is, and only the narrow slice
that neusis's own nixpkgs pin cannot supply. Everything else about that account (git
identity and signing, editors, themes, browsers, tailscale) comes from neusis's shared
`homes/common/`.

There is deliberately **no NixOS system configuration** in this repo.

## Usage

```bash
nix run .#build          # build this Mac's system; does NOT switch
nix run .#build-switch   # build and activate
nix run .#rollback       # list generations and switch back
nix run .#clean          # garbage-collect old generations
nix flake check
```

The apps resolve the target host at runtime from `scutil --get LocalHostName`, since
`darwinConfigurations` is keyed by hostname rather than by system. Override explicitly with
`nix run .#build-switch -- <host>`.

## Setting up a new Mac

1. **Install Nix.** Either [Determinate](https://determinate.systems/nix) or the upstream
   installer works — the choice decides `nix.enable` in step 3.

2. **Clone and name the machine.** `darwinConfigurations` is keyed by hostname, and the apps
   resolve it from `scutil --get LocalHostName`, so pick the key to match — or add an alias,
   as `hosts/darwin/default.nix` does for `Runxis-MacBook-Pro`.

   ```bash
   git clone git@github.com:runxi-shen/nixos-config.git ~/Projects/software/nixos-config
   cd ~/Projects/software/nixos-config
   scutil --get LocalHostName
   ```

3. **Write `hosts/darwin/<host>.nix`.** Copy `hosts/darwin/runxi-mbp.nix` and keep only what
   applies. Two things are mandatory:

   - **`local.dock.entries`** — every Mac enables the dock, and omitting `entries` evaluates
     cleanly and then *wipes* the dock. An assertion catches this, but you still have to
     decide: copy the block, or set `local.dock.enable = false;`.
   - **`nix.enable`** — `false` for Determinate Nix (it manages its own daemon), `true` for
     the upstream installer. Not shared, because it is a property of the install.

   Optional: casks, dock, launchd agents, cloud-storage symlinks — all per-machine.

4. **Register it** in `flake.nix`, inside the `darwinConfigurations` `let`:

   ```nix
   rshen-mbp = mkDarwin { host = "rshen-mbp"; user = "rshen"; };
   ```

   and add it to the returned attrset (`inherit runxi-mbp rshen-mbp;`).

   `user` is threaded per-host, which is what lets this machine stay `runxishen` while every
   other machine in the fleet is `rshen`. Because the home profile never names a user, that
   argument is the only difference between two Macs.

5. **`git add` everything** — flakes cannot see untracked files, and a new host file that
   isn't staged fails in a way that looks unrelated.

6. **Build, then switch.**

   ```bash
   nix run .#build -- rshen-mbp        # no changes to the machine
   nix run .#build-switch -- rshen-mbp
   ```

Homebrew is installed declaratively by `nix-homebrew`; casks download on first activation,
so the first switch is slow. If a cask fails to fetch, the activation aborts with the system
profile already advanced — re-run `build-switch` and it completes.

## Layout

```
flake.nix              darwinConfigurations, homeModules, homeConfigurations,
                       overlays, apps, devShells
homes/rshen/           the portable home profile (core, packages, dev, agents, gui)
hosts/darwin/          default.nix = every Mac; <host>.nix = one machine
modules/darwin/        casks, dock, home-manager wiring, Mac-only packages, agenix
modules/shared/        nixpkgs config, static files, fonts
overlays/default.nix   named overlays, exported as outputs.overlays
apps/aarch64-darwin/   build, build-switch, rollback, clean, key management
```

`CLAUDE.md` / `AGENTS.md` carry the working notes — invariants, footguns, and where a given
package belongs. `docs/multi-machine-migration.md` records the 2026-09 restructure phase by
phase, including what verification found.

## Credits

Forked from [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config), which
is where the nix-darwin scaffolding, the declarative dock module, and the app-runner pattern
originally came from. Upstream was detached in 2026-09 and the previous owner's machines
removed; BSD 3-Clause license and copyright retained in `LICENSE`.

Structural patterns — named overlays, per-host `mkDarwin`, and exporting a home profile for
another flake to consume — follow [afermg/nixos-config](https://github.com/afermg/nixos-config).
