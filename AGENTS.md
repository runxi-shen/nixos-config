# Repository agent guide

This is the canonical guidance for coding agents working in this repository. Tool-specific
entry points such as `CLAUDE.md` should be symlinks to this file so the instructions cannot
drift.

## Repository Overview

Nix flake configuring **Macs as full nix-darwin systems**, plus a **portable home-manager
profile** exported for Linux machines managed elsewhere.

### Standalone repo — no upstream

Originally a fork of `dustinlyons/nixos-config`. The previous owner's machines were removed
in the 2026-09 restructure, and the GitHub **fork network was left in 2026-09**: there is no
parent repo, no `upstream` remote, and no merge path from anywhere. `origin` is the only
remote and it is this repo.

Two repos are read as **REFERENCE ONLY**. Never merge from them, never add either as a
remote, never make either a flake input:

| Repo | Role |
|---|---|
| `afermg/nixos-config` | **Primary reference.** Structural patterns already followed here: named overlays, per-host `mkDarwin`, exporting a home profile for another flake to consume. Prefer its shape when a structural question comes up. It is also the pattern neusis already runs for another user. |
| `dustinlyons/nixos-config` | **Secondary.** Consult only for new nix-on-macOS technique — nix-darwin idioms, Homebrew/cask handling, activation tricks. Everything organisational there is superseded. |

Copy ideas, not commits. If something from either is worth having, reimplement it in this
repo's shape and explain why in the commit message.

BSD-3-Clause © Dustin Lyons is retained in `LICENSE`, and that obligation is permanent and
unrelated to the fork network: roughly 890 lines of the live config are still upstream-
authored — `homes/rshen/config/p10k.zsh`, `modules/darwin/dock/`, `apps/*-keys`, and parts
of `flake.nix` and `hosts/darwin/default.nix`.

This repo owns **no NixOS system configuration**. The Linux machines in the fleet —
`oppy`, `spirit`, `karkinos` — are shared lab servers (~15 users) owned by
`shntnu/neusis`. Their system config is not ours to touch; only the home half is.

## Downstream: the neusis contract

```
runxi-shen/nixos-config  ──homeModules.rshen-agents──>  shntnu/neusis
        (this repo)                                     (shared lab servers)
```

`neusis/homes/rshen/machines/oppy.nix` imports
`inputs.rshen-nixos-config.homeModules.rshen-agents`; `spirit` and `karkinos` inherit it
through `oppy.nix`. Everything else about the `rshen` account there — git identity and
signing, editors, themes, browsers, tailscale — comes from neusis's own `homes/common/`,
which is **shared by fifteen users and must never be edited**.

**Cadence:** land a change here → in neusis, `nix flake update rshen-nixos-config` → rebuild.

**Obligation:** `main` is a dependency of that shared infrastructure. Before pushing to
`main`, confirm the exported module still evaluates for Linux:

```bash
nix eval --raw '.#homeConfigurations."rshen@oppy".activationPackage.drvPath'
```

## Key commands

```bash
nix run .#build          # build this Mac's system; does NOT switch
nix run .#build-switch   # build and activate (needs sudo; Touch ID is enabled)
nix run .#rollback       # list generations and switch back to one
nix run .#clean          # garbage-collect generations older than 7 days

nix flake check          # validate all outputs
nix run nixpkgs#statix -- check .   # lint (the only CI job)
```

`build` and `build-switch` resolve the host at runtime via `scutil --get LocalHostName`,
and accept an explicit override: `nix run .#build-switch -- <host>`.

**Updating inputs.** `nixpkgs` is deliberately pinned to `241313f4e8e5` (2026-07-19) because
of a livekit-on-darwin breakage. Use `nix flake lock` to prune orphaned nodes — it preserves
pins. `nix flake update` (no argument) would silently un-pin nixpkgs. To bump one input:
`nix flake update claude-code`.

## Architecture

```
flake.nix              inputs; outputs: darwinConfigurations, homeModules,
                       homeConfigurations, overlays, apps, devShells
homes/rshen/           the portable home profile
  default.nix          imports core + packages + dev + agents + gui
  core.nix             zsh, git, vim, tmux, direnv, ssh; declares options.rshen.*
  packages.nix         portable CLI
  dev.nix              toolchain; PORTABLE -- see warning below
  agents.nix           claude-code, codex, pi-coding-agent; ALSO exported
  gui.nix              alacritty, fonts, zed-editor; Darwin-gated with mkIf
  config/p10k.zsh
hosts/darwin/
  default.nix          settings true of EVERY Mac
  runxi-mbp.nix        user runxishen: casks, dock, launchd agents, Nutstore link
  rshen-mbp.nix        user rshen: casks, dock
                       BOTH import modules/darwin/onedrive-purdue.nix
modules/darwin/        casks.nix (runxi-mbp), casks-rshen-mbp.nix, dock/,
                       home-manager.nix, onedrive-purdue.nix, packages.nix,
                       secrets.nix
modules/shared/        default.nix (nixpkgs config + overlays), files.nix, fonts.nix,
                       config/wezterm.lua
overlays/default.nix   NAMED overlays, exported as outputs.overlays
apps/aarch64-darwin/   build, build-switch, rollback, clean, *-keys
taps/zenkit/           local Homebrew tap
```

`darwinConfigurations` is keyed by **hostname**, not system. `mkDarwin { host, user }` is an
inline `let` in `flake.nix` — there is no `lib/`. `user` is threaded per-host, which is what
lets `runxi-mbp` stay `runxishen` while `rshen-mbp` and every Linux machine are `rshen`.
That argument is the *only* difference between the two Macs' `mkDarwin` calls, because
nothing under `homes/` names a user.
`"Runxis-MacBook-Pro"` is aliased to `"runxi-mbp"` because that is what `scutil` returns
there. **Both Macs shipped with that same default name** -- macOS derives it from the
ComputerName -- so `rshen-mbp` was renamed once at setup with
`sudo scutil --set LocalHostName rshen-mbp`.

That rename is **no longer imperative-only.** `hosts/darwin/rshen-mbp.nix` sets
`networking.computerName` and `networking.localHostName` from the threaded `host`, and
nix-darwin's networking module runs `scutil --set` unconditionally on every activation, so
each switch reasserts the name. ComputerName is pinned alongside LocalHostName because
macOS re-derives the latter from the former. `runxi-mbp` is **not** pinned and still leans
on the alias.

Two things this does *not* fix:

- **Bootstrap.** The name must already be right before the *first* switch on a new Mac,
  since `build-switch` resolves the host with `scutil --get LocalHostName` before any
  config can run. The manual `scutil --set` in the README's new-Mac section stays.
- **Drift between switches.** macOS can still move the name; activation only puts it back.
  A drift to an unknown string fails loudly (`No darwinConfiguration named ...`) -- recover
  with `nix run .#build-switch -- rshen-mbp`, which restores both names. A drift to
  `Runxis-MacBook-Pro` is the dangerous one: that string *is* a valid key, so a bare
  `build-switch` would silently build the other Mac's config under the wrong username.

`rshen-mbp` runs Determinate Nix (`nix.enable = false`), so nix-darwin writes no
`/etc/nix/nix.conf` and the `nix.settings` in `hosts/darwin/default.nix` are inert there;
its substituters and `trusted-users` live in `/etc/nix/nix.custom.conf` instead. See the
README's new-Mac section.

## Working with this repository

### CRITICAL: git tracking

Flakes only see files tracked by git. `git add` ANY new file before building, or it will
appear not to exist. This is the single most common failure mode here.

### Where a package goes

| Scope | Location |
|---|---|
| Portable CLI (Macs **and** lab servers) | `homes/rshen/packages.nix` |
| Portable dev toolchain | `homes/rshen/dev.nix` |
| Coding agents (shared with the servers via the export) | `homes/rshen/agents.nix` |
| Mac-only CLI | `modules/darwin/packages.nix` |
| Mac-only GUI / fonts | `homes/rshen/gui.nix` |
| macOS apps | per-host: `modules/darwin/casks.nix` (runxi-mbp) or `casks-rshen-mbp.nix`. Adding an app to one Mac does NOT add it to the other. |

**`homes/rshen/dev.nix` and `agents.nix` reach the shared lab servers.** Adding a line there
installs software on machines fifteen people use. The bar is "I want this on
oppy/spirit/karkinos too."

### Constraints inside `homes/`

- Never write a concrete username or an absolute home path. Enforced by
  `grep -rn "runxishen\|/Users/" homes/` returning nothing — keep those literals out of
  comments too, or the guard stops guarding.
- `imports` cannot branch on `pkgs`. `pkgs` arrives via `_module.args`, which is part of
  `config`, and `imports` resolves first — so `lib.optional pkgs.stdenv.…` there is an
  infinite recursion. Import unconditionally and gate with `lib.mkIf` (see `gui.nix`).
- `agents.nix` sources packages from `rshenInputs.nixpkgs.legacyPackages`, not ambient
  `pkgs`, so the servers get our pins rather than neusis's older ones. `legacyPackages`
  carries no `nixpkgs.config`, so nothing unfree may come from it — that is why
  `claude-code` comes from its flake input instead.

### Overlays

`overlays/default.nix` returns a **named attrset**, exported as `outputs.overlays` and
applied via `builtins.attrValues outputs.overlays` in `modules/shared/default.nix`. It is
**not** the auto-loading directory scanner this repo used to have; names are required so an
individual overlay stays addressable by a consuming flake.

### Secrets

`agenix`, wired at `modules/darwin/secrets.nix` against the private `secrets` input. The
secrets set is currently empty — the plumbing exists, nothing uses it yet. Consumers of
`homeModules.rshen-agents` never fetch that input.

## Testing changes

1. `nix flake check`
2. `nix run .#build` — builds without switching
3. `nix eval --raw '.#homeConfigurations."rshen@oppy".activationPackage.drvPath'` if you
   touched anything under `homes/`. **Evaluate, do not build**: home-manager generates
   trivial x86_64-linux derivations that exist in no cache, so a Mac cannot build the Linux
   closure at all. Add `nix.linux-builder.enable = true` if that is ever needed.
4. `nix run .#build-switch`

## CI

One workflow: `statix` lint. The three upstream workflows that built
`dustinlyons/nixos-config` templates were removed — one was scheduled weekly and would have
auto-PR'd an unpinned `flake.lock` over the deliberate nixpkgs pin.

Upstream's `.github/dependabot.yml` was dropped for the same reason: nothing should open a
PR here that nobody asked for. The cost is that action versions are now a **manual** bump,
so both are pinned to release tags (`actions/checkout@v4`,
`DeterminateSystems/nix-installer-action@v22`) rather than `@main`, which re-resolved on
every run and could break CI from a third party's push.

`lint.yml` sets `paths-ignore: ['.github/**', 'README.md']`, so a commit touching only CI or
the README does **not** trigger it — a workflow change is first exercised on the next push
that touches a `.nix` file.

## History

`docs/multi-machine-migration.md` is the record of the 2026-09 restructure, phase by phase,
including deviations and what verification found. Read it before making structural changes.
