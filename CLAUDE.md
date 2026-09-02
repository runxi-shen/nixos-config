# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Nix flake configuring **Macs as full nix-darwin systems**, plus a **portable home-manager
profile** exported for Linux machines managed elsewhere. Originally a fork of
`dustinlyons/nixos-config`; upstream was detached in 2026-09 and the previous owner's
machines removed.

This repo owns **no NixOS system configuration**. The Linux machines in the fleet —
`oppy`, `spirit`, `karkinos` — are shared lab servers (~15 users) owned by
`shntnu/neusis`. Their system config is not ours to touch; only the home half is.

## The two-repo relationship

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
  runxi-mbp.nix        this machine only: casks, dock, launchd agents, cloud links
modules/darwin/        casks.nix, dock/, files.nix, home-manager.nix, packages.nix, secrets.nix
modules/shared/        default.nix (nixpkgs config + overlays), files.nix, fonts.nix, cachix/
overlays/default.nix   NAMED overlays, exported as outputs.overlays
apps/aarch64-darwin/   build, build-switch, rollback, clean, *-keys
taps/zenkit/           local Homebrew tap
```

`darwinConfigurations` is keyed by **hostname**, not system. `mkDarwin { host, user }` is an
inline `let` in `flake.nix` — there is no `lib/`. `user` is threaded per-host, which is what
lets this Mac stay `runxishen` while every Linux machine is `rshen`.
`"Runxis-MacBook-Pro"` is aliased to `"runxi-mbp"` because that is what `scutil` returns.

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
| macOS apps | `modules/darwin/casks.nix` (per-host; imported by `hosts/darwin/runxi-mbp.nix`) |

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

## History

`docs/multi-machine-migration.md` is the record of the 2026-09 restructure, phase by phase,
including deviations and what verification found. Read it before making structural changes.
