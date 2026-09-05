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
   as `flake.nix` does for `Runxis-MacBook-Pro`.

   ```bash
   git clone git@github.com:runxi-shen/nixos-config.git ~/nixos-config
   cd ~/nixos-config
   scutil --get LocalHostName
   ```

   **Expect a collision.** macOS derives `LocalHostName` from the ComputerName you type in
   Setup Assistant, so a second Mac set up by the same person reports the *same* default —
   both of these machines answered `Runxis-MacBook-Pro` out of the box, and that string is
   already aliased to `runxi-mbp`. A bare `build-switch` on the new Mac would then silently
   build the *other* machine's config, under the wrong username. Rename it once:

   ```bash
   sudo scutil --set LocalHostName rshen-mbp
   ```

   This changes only the Bonjour/network name; `ComputerName` is untouched.

   Then **pin it in step 3's host file** so it cannot drift back:

   ```nix
   networking.computerName = host;
   networking.localHostName = host;
   ```

   `hosts/darwin/rshen-mbp.nix` does this. nix-darwin runs `scutil --set` on every
   activation, so each switch reasserts the name; pinning `ComputerName` too matters
   because macOS re-derives `LocalHostName` from it. The manual command above is still
   required first — the host has to resolve before any config can run.

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
profile already advanced — re-run `build-switch` and it completes. `dockutil` runs in that
same activation, so dock entries pointing at not-yet-installed casks are skipped on the
first pass and settle on the second.

**If you chose Determinate** (`nix.enable = false`), nix-darwin writes no `/etc/nix/nix.conf`
at all, which makes the `substituters`, `trusted-public-keys` and `trusted-users` in
`hosts/darwin/default.nix` inert on that host. Determinate's own `nix.conf` `!include`s
`/etc/nix/nix.custom.conf` and never overwrites it, so that file is where they go:

```
extra-substituters = https://nix-community.cachix.org
extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
trusted-users = root @admin <user>
```

Reload the daemon afterwards — `determinate-nixd` has no `restart` subcommand:

```bash
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

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

## Lineage

**This is a standalone repository.** It began as a fork of
[dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config), but the previous
owner's machines were removed in the 2026-09 restructure and the GitHub fork network was
left in 2026-09. There is no parent repo, no `upstream` remote, and no merge path from
anywhere — `origin` is the only remote.

Two repos are still read, as **reference only** — never merged, never added as a remote,
never a flake input:

- [afermg/nixos-config](https://github.com/afermg/nixos-config) — **primary.** The
  structural patterns here follow it: named overlays, per-host `mkDarwin`, and exporting a
  home profile for another flake to consume. It is also the pattern `neusis` already runs
  for another user, which is what makes it the right shape to copy.
- [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config) — **secondary,**
  for new nix-on-macOS technique only: nix-darwin idioms, Homebrew and cask handling,
  activation tricks. Its organisational choices are superseded here.

Ideas get reimplemented in this repo's shape; commits do not get merged.

## License

BSD 3-Clause, © 2021 Dustin Lyons, retained in `LICENSE`. Leaving the fork network changed
nothing about this: roughly 890 lines of the live configuration are still upstream-authored
— `homes/rshen/config/p10k.zsh`, `modules/darwin/dock/`, `apps/*-keys`, and parts of
`flake.nix` and `hosts/darwin/default.nix`. The nix-darwin scaffolding, the declarative dock
module and the app-runner pattern all originated there.
