# Multi-machine migration plan

Living document. Execution is **one phase per session** — see [Execution
protocol](#execution-protocol). Phase status lines in this file are the source of truth for
where the migration stands.

---

## Context

`runxi-shen/nixos-config` is a fork of `dustinlyons/nixos-config`, currently shaped for
exactly one Mac. Three things block "one declarative config across all my machines":

1. **It cannot describe a second Mac.** `darwinConfigurations` is keyed by *system*
   (`aarch64-darwin`, `x86_64-darwin`), not hostname — every Apple Silicon Mac would be
   forced to an identical config. `apps/*/build-switch` hardcodes `.#aarch64-darwin`.
2. **Its home config cannot leave this repo.** `modules/shared/home-manager.nix` is not a
   home-manager module — it's a bare function returning a `programs`-shaped attrset,
   spliced in at `modules/darwin/home-manager.nix:98`. Nothing is exportable.
3. **It carries a previous owner's machines.** `hosts/nixos/garfield`, `home-assistant.nix`,
   `n8n.nix`, `github-runner.nix`, `kde-config.nix`, and World-of-Warcraft addon overlays
   (`curseforge-appimage.nix`, `wowup-appimage.nix`) are all Dustin Lyons's.

The server half of the fleet already exists elsewhere: `oppy`, `spirit`, `karkinos` are
**shared lab machines** owned by `runxi-shen/neusis` (fork of `shntnu/neusis`), ~15 users,
and `homes/rshen/` already lives there. Their *system* config cannot move into a personal
repo — but the *home* half can, and neusis already supports exactly that.

**Outcome:** this repo owns (a) every Mac as a full nix-darwin system, and (b) one portable,
username-agnostic home profile exported as `homeModules.rshen`, which neusis consumes for
the lab servers. `runxi-shen/nix-configs` then becomes redundant and is retired.

### Decisions taken

- **Servers:** export `homeModules.rshen` + `homeConfigurations."rshen@<host>"`.
- **Upstream:** cut the cord from `dustinlyons`; stop merging, delete his machines.
- **Username:** `rshen` is standard — all Linux machines *and* the new MacBook Pro. This
  existing Mac stays `runxishen` (no account rename). Usernames are therefore **per-host**;
  `user` is threaded through `mkDarwin`, not a flake-level constant.
- **New Mac:** restructure to hostname-keyed now; register the new Mac when it's in hand.

### The pattern being copied (already working in neusis, for Alan)

```nix
# neusis/flake.nix
amunoz-nixos-config = { url = "github:afermg/nixos-config"; flake = true; };

# neusis/homes/amunoz/machines/oppy.nix — the entire file
{ inputs, ... }: { imports = [ inputs.amunoz-nixos-config.homeModules."amunoz-oppy" ]; }
```

`neusis/users/cslab.nix` shows three precedented patterns: `ank` (home lives in neusis),
`amunoz` (home sourced from personal repo, applied at system rebuild), `shsingh`
(`oppy = null` — neusis makes account + SSH key only, owner applies standalone). We use
the **amunoz pattern** as system-of-record.

### Verified facts this plan relies on

- This Mac: single account `runxishen`, uid 501, `/Users/runxishen`, `aarch64-darwin`,
  hostname `Runxis-MacBook-Pro`. No `rshen` account exists or ever did.
- `personalize` is **26 ahead of `main`, 0 behind** → `main` fast-forwards.
  **No force-push anywhere in this plan.**
- Only 8 occurrences of `runxishen` in non-template `.nix`; 6 are `let user = …`.
- **Re-verified on the live remote** (`runxi-shen/neusis` @ `fa3dded` = current
  `origin/main`; one branch, zero PRs): `claude-code-rshen` is **still present** at
  `flake.nix:139` and `homes/rshen/home.nix:27`, and also in upstream `shntnu/neusis`.
  Not cleaned up. Referenced by that one file only.
- `neusis/homes/rshen/home.nix:4-5` hardcodes `username`/`homeDirectory`. These must move
  to the *consumer*, never into the exported module, or they collide at eval.

---

## Target structure

```
flake.nix                  # inputs; outputs: darwinConfigurations, homeModules,
                           #   homeConfigurations, overlays, devShells
lib/default.nix            # mkDarwin / mkHome builders

homes/rshen/               # THE portable profile — no username appears anywhere
  default.nix              #   real HM module: core + dev
  core.nix                 #   zsh, git, vim, tmux, direnv, ssh  (from shared/home-manager.nix)
  packages.nix             #   portable CLI only
  dev.nix                  #   claude-code, codex, gh/glab, node, python, uv
  gui.nix                  #   alacritty, zed-editor, fonts — Macs only
  machines/{oppy,spirit,karkinos}.nix   # server extras: poetry, pixi, duckdb, gitleaks

hosts/darwin/
  default.nix              # shared macOS system config: defaults, homebrew, nix settings
  runxi-mbp.nix            # per-host: casks, dock, host-only launchd (dsh)
modules/darwin/            # dock/, casks.nix, secrets.nix, packages.nix
overlays/                  # trimmed to what's used
apps/                      # trimmed; build-switch resolves hostname at runtime
```

**Invariant for `homes/rshen/`:** never hardcode a username or an absolute `/Users/…`
path; derive from `config.home.homeDirectory`. `home.username` / `home.homeDirectory` are
set by the builder (`mkHome`) or the consumer (neusis) — never by the module.

---

## Execution protocol

**One phase per session.** Do not run ahead.

At the start of a phase: read this file, find the first phase whose status is `TODO`,
and execute only that phase.

At the end of a phase, in order:

1. Re-read the phase's **Exit criteria** and confirm each one literally.
2. Run the phase's **Verify** commands. All must pass. If any fails, fix it inside this
   phase — do not defer to the next.
3. Flip the phase's status line in this document to `DONE (<short-sha>)`.
4. Commit, using the phase's stated commit message.
5. **Stop. Compact context.** The next phase starts fresh.

If a verify step fails in a way that invalidates the plan, stop and report rather than
improvising a redesign — the phase boundaries are what keep this recoverable.

---

## Phase 0 — Land current work, cut the cord — status: DONE (ab3f0266, 8c075190)

**Goal:** clean tree, `main` carries everything, upstream detached. No structural changes.

**Changes**

1. Commit the 3 dirty files as-is (`hosts/darwin/default.nix` dsh launchd agent,
   `modules/darwin/packages.nix` dsh wrapper, `modules/shared/packages.nix` pnpm).
   They get *relocated* in Phase 3, not rewritten — do not touch their content here.
2. `git checkout main && git merge --ff-only personalize`
3. `git push origin main`; confirm GitHub default branch is `main`.
4. Do **not** merge the 5 pending `upstream/main` commits (all concern `garfield`).
5. `git remote remove upstream`; delete branch `personalize`. Keep
   `backup/personalize-pre-rebase-2026-08-22` until Phase 6 passes.
6. Create and switch to `restructure/multi-machine` for Phases 1–4.

**Verify**

```bash
git status --porcelain              # empty
git rev-list --count main..personalize 2>/dev/null || true   # 0 / branch gone
git remote -v                       # origin only
nix flake check
nix run .#build                     # builds this Mac, does not switch
```

**Exit criteria:** clean tree; `main == personalize` content; no `upstream` remote;
`nix run .#build` passes; on branch `restructure/multi-machine`.

**Commit:** `darwin: add dsh web harness via launchd` (for step 1; steps 2–6 are branch ops)

**Deviations at execution time**

- `nix flake check` was **already red before this phase**: `genAttrs darwinSystems`
  manufactured a `darwinConfigurations.x86_64-darwin` that cannot evaluate, because
  nixpkgs 26.11 dropped x86_64-darwin. Fixed in-phase (`8c075190`) by reducing
  `darwinSystems` to `[ "aarch64-darwin" ]` — the same reduction Phase 3 implies. Deferring
  it would have left a red baseline that hides new breakage in Phases 1–4.
- `origin/personalize` still exists on GitHub (remote deletion was blocked locally). It is
  fully contained in `main`, so it holds nothing unique — delete at leisure.

---

## Phase 1 — Prune inherited cruft — status: DONE (2d2c07f6)

**Goal:** delete the previous owner's machines and dead overlays. Nothing else.

**Changes**

- Delete `hosts/nixos/garfield/`, `templates/`, `systemd/`.
- Delete `modules/nixos/{home-assistant,n8n,github-runner,atlas,kde-config,appimage-host,
  hooks-proxy,garfield-packages,garfield-secrets,systemd}.nix`.
- Delete `overlays/{curseforge,wowup,cider,obsidian,tableplus}-appimage.nix` and
  `overlays/{phpstorm,newrelic-cli,linear-cli,sentry-cli}.nix`.
- Drop the `excludeForHost."garfield"` branch in `modules/shared/default.nix:20-24`.
- Strip `/Users/dustin/` paths from `modules/shared/config/emacs/config.org` **and** the
  tangled `config.el`.
- Prune now-unused `flake.nix` inputs: `claude-desktop`, `plasma-manager`, `chaotic`,
  `disko`, `flake-utils`. **`grep` each before removing.** Keep `agenix` and `secrets` —
  agenix is wired at `modules/darwin/secrets.nix`.

**Verify**

```bash
grep -rn "garfield\|plasma\|chaotic\|claude-desktop" --include='*.nix' . # only intended hits
grep -rn "/Users/dustin" .                                              # none
nix flake check
nix run .#build
```

**Exit criteria:** `nix run .#build` passes; no references to deleted files; `flake.lock`
regenerated with the pruned input set.

**Commit:** `Remove upstream machines, templates, and unused overlays`

**Deviations at execution time**

The phase as written was **not self-consistent**: `plasma-manager`, `chaotic` and `disko`
are consumed at `flake.nix:149-153`, inside the `nixosConfigurations` block that builds
**felix** — not garfield. `modules/nixos/systemd.nix` was imported by
`hosts/nixos/default.nix:16` and `modules/nixos/kde-config.nix` by
`modules/nixos/home-manager.nix:8`, both reachable only via felix. So neither the stated
input-pruning nor those two deletions could succeed while felix existed, yet Phase 1 never
mentioned felix and the Target structure has no `hosts/nixos` at all.

Resolved by confirming ownership and widening the deletion, with the owner's approval:

- **felix is the upstream owner's machine.** Every commit touching
  `hosts/nixos/default.nix` is authored by Dustin Lyons, from `86813254` (2023-11-17) to
  `235b5cc0` (2026-06-26). `time.timeZone = "America/Kentucky/Louisville"`, an
  `amdgpu` RX 9070, and a `PG278Q.bin` EDID blob for his ASUS ROG Swift. Same category as
  garfield; the plan simply failed to name it.
- **Rule adopted from `afermg/nixos-config`:** `homes/` may carry other people's profiles,
  but `machines/` carries only hardware you own — Alan keeps `nixosConfigurations` solely
  for `moby`, his own server. This repo owns no personal Linux machine, so all NixOS
  *system* config goes. Re-add a host directory if that ever changes.
- Also deleted `tests/`, `overlays/playwright.nix` (only consumer was
  `modules/nixos/packages.nix`), and `.github/workflows/{build,build-template,
  update-flake-lock}.yml` — all three run `nix flake init -t
  github:dustinlyons/nixos-config#starter`, i.e. they test *upstream's* templates. They are
  the CI half of the cord Phase 0 cut, and `update-flake-lock.yml` was scheduled weekly and
  would have auto-PR'd an unpinned `flake.lock` over the deliberate nixpkgs pin.
  `lint.yml` (statix) is kept.

**Reference alignment brought forward from Phase 4**

`overlays/` was a directory scan mapping every `*.nix` into an **anonymous list**, so no
individual overlay was addressable. Phase 4's `overlays = [ outputs.overlays.claude-code ]`
therefore could not have worked — this flake had no `overlays` output at all. Replaced with
`overlays/default.nix` returning a **named attrset** exported as `outputs.overlays`, copying
`afermg/nixos-config`. `modules/shared/default.nix` now consumes
`builtins.attrValues outputs.overlays`, preserving prior behaviour exactly, and the
previously inlined `claude-code` overlay moved into the file with its siblings.
`nix flake check` now reports `overlays.claude-code` and `overlays.pandas-stubs` as
first-class checked outputs.

**`nix flake lock`, never `nix flake update`.** `flake.nix:4` says `nixos-unstable`, but the
lock deliberately pins root nixpkgs to `241313f4e8e5` (2026-07-19) for the
livekit-on-darwin breakage. `lock` drops orphaned nodes and keeps existing pins; `update`
would silently un-pin. 15 nodes dropped, 10 root inputs remain, pin intact.

---

## Phase 2 — Make the home profile portable — status: TODO

**Goal:** convert the shared config into a real, username-agnostic home-manager module.
This is the phase the whole plan turns on.

**Changes**

- Convert `modules/shared/home-manager.nix` (bare attrset of `direnv`, `zsh`, `git`, `vim`,
  `alacritty`, `ssh`, `tmux`) into a real HM module at `homes/rshen/core.nix` returning
  `{ programs = { … }; }`. Drop its `let user = "runxishen"`.
- **Fix the portability bug** at `modules/shared/home-manager.nix:328`:
  `'/Users/runxishen/.cache/tmux/resurrect'` →
  `"${config.home.homeDirectory}/.cache/tmux/resurrect"`.
  An absolute macOS path inside the cross-platform module; blocks Linux today.
- Same for the `ssh` block (`:284`, `:300`), which uses `/Users/${user}/.ssh/…`.
- Move `alacritty` into `homes/rshen/gui.nix` (Macs only).
- Split `modules/shared/packages.nix`: portable CLI → `homes/rshen/packages.nix`;
  Mac/desktop-only (`myFonts`, `zed-editor`, `ngrok`, `age-plugin-yubikey`) → `gui.nix`.
  Servers get no fonts and no GUI editor.
- Create `homes/rshen/machines/{oppy,spirit,karkinos}.nix` carrying the packages currently
  in `neusis/homes/rshen/home.nix`: duckdb, poetry, pixi, gitleaks, btop, screen, cmake,
  rsync. `spirit`/`karkinos` may just import `oppy.nix`, as neusis does today.

**Verify**

```bash
grep -rn "runxishen\|/Users/" homes/           # ZERO hits — the core invariant
nix flake check
nix run .#build                                # this Mac still builds
```

**Exit criteria:** `homes/` contains no username and no `/Users/` path; this Mac still
builds. (Cross-building the Linux closure is gated on Phase 4's outputs existing.)

**Commit:** `Extract portable, username-agnostic home profile under homes/rshen`

---

## Phase 3 — Hostname-keyed Macs — status: TODO

**Goal:** one Mac becomes N Macs.

**Changes**

- Add `lib/default.nix` with `mkDarwin { host, user, system }`, threading `host` and `user`
  through `specialArgs`.
- De-hardcode `user` in `hosts/darwin/default.nix:3`, `modules/darwin/home-manager.nix:4`,
  `modules/darwin/secrets.nix:3`.

```nix
darwinConfigurations = {
  # This Mac — the one host that is not `rshen`.
  "runxi-mbp" = mkDarwin { host = "runxi-mbp"; user = "runxishen"; system = "aarch64-darwin"; };

  # New MacBook Pro — `rshen`, matching every Linux machine. 4 lines when it's in hand.
  # "rshen-mbp" = mkDarwin { host = "rshen-mbp"; user = "rshen"; system = "aarch64-darwin"; };
};
```

Threading `user` per-host is what lets `runxishen` and `rshen` coexist. Because the home
profile never names a user, the *only* difference between the two Macs is this one
argument — so renaming this machine to `rshen` later is editing that string.

- Move host-specific config out of `hosts/darwin/default.nix` into
  `hosts/darwin/runxi-mbp.nix`: the `dsh-web` launchd agent (hardcodes `~/dsh-workspace` +
  an imperative npm tree at `~/.local/share/dsh`), the OneDrive/Nutstore `cloudLinks`, and
  the OneDrive tombstone activation script. All specific to *this machine*, not to "a Mac".
- Keep `system.defaults` (dock, trackpad, key-repeat) in `hosts/darwin/default.nix` — that
  *is* the "same settings on all Macs" requirement.
- Rewrite `apps/*/build-switch` to resolve at runtime:
  `HOST=$(scutil --get LocalHostName)` → `.#darwinConfigurations.$HOST.system`.

**Verify**

```bash
nix flake check
nix eval .#darwinConfigurations --apply builtins.attrNames   # hostname keys, not systems
nix run .#build
nix run .#build-switch      # the real test
dockutil --list             # dock unchanged
ls -ld ~/Purdue_OneDrive ~/Nutstore    # symlinks still resolve
launchctl list | grep dsh              # agent still loaded
claude --version
```

**Exit criteria:** `darwinConfigurations` keyed by hostname; `build-switch` works with no
hardcoded system; post-switch checks above all pass.

**Commit:** `Key darwinConfigurations by hostname with per-host user`

---

## Phase 4 — Export for the servers — status: TODO

**Goal:** make the profile consumable by another flake.

**Changes**

```nix
# mirrors afermg/nixos-config's homeModules.amunoz
homeModules.rshen = {
  _module.args = { inherit inputs outputs; };   # so a consumer's specialArgs can't shadow ours
  imports = [ agenix.homeManagerModules.default ./homes/rshen ];
  nixpkgs = { config.allowUnfree = true; overlays = [ outputs.overlays.claude-code ]; };
};
homeModules.rshen-oppy = { imports = [ homeModules.rshen ./homes/rshen/machines/oppy.nix ]; };
# …-spirit, …-karkinos

homeConfigurations."rshen@oppy" = lib.homeManagerConfiguration {
  pkgs = pkgsFor.x86_64-linux;
  modules = [ outputs.homeModules.rshen-oppy
              { home.username = "rshen"; home.homeDirectory = "/home/rshen"; } ];
};
```

Baking `_module.args` and `nixpkgs` *into* the module is deliberate, copied from Alan's
comment in `afermg/nixos-config`: a consumer's `extraSpecialArgs` would otherwise shadow
this flake's `outputs`.

**Prerequisite already landed in Phase 1.** `outputs.overlays.claude-code` did not exist
when this phase was written — `overlays/` was an anonymous directory scan. Phase 1 replaced
it with named overlays exported as `outputs.overlays`, so the snippet above now resolves.
Note also that afermg goes further than `_module.args` alone: `homes/amunoz/home.nix` takes
a **namespaced** `amunozInputs ? inputs` argument so a consumer's generic `inputs` cannot
shadow this flake's package pins. Consider `rshenInputs` here.

**Verify**

```bash
nix flake check
# THE key gate — cross-build the Linux home closure locally, no server involved.
# Fails loudly on any surviving /Users/… path or Darwin-only package.
nix build .#homeConfigurations."rshen@oppy".activationPackage
nix build .#homeConfigurations."rshen@spirit".activationPackage
nix build .#homeConfigurations."rshen@karkinos".activationPackage
nix run .#build     # Mac unaffected
```

**Exit criteria:** all three Linux activation packages build on this Mac; `nix run .#build`
still passes.

**Commit:** `Export homeModules.rshen and per-host homeConfigurations`

---

## Phase 5 — Wire up neusis — status: TODO

**Separate repo. Land as a PR — this rebuilds machines other people use.**

**Changes in `runxi-shen/neusis`**

1. Add input `rshen-nixos-config = { url = "github:runxi-shen/nixos-config"; };`
2. Shrink each `homes/rshen/machines/<host>.nix` to one import of
   `inputs.rshen-nixos-config.homeModules."rshen-<host>"`.
3. Delete `homes/rshen/home.nix` and the `claude-code-rshen` input (verified live at
   `fa3dded`; referenced only by that file; this repo's `claude-code` input replaces it).
   Its packages — duckdb, poetry, pixi, gitleaks, btop, screen, cmake, rsync — move to
   `homes/rshen/machines/*.nix` here in Phase 2. The input also exists in upstream
   `shntnu/neusis`, so expect a conflict on the next upstream merge.
4. Leave `users/cslab*.nix` alone. Account, shell, and SSH key stay in neusis — correct for
   a shared machine.

**Verify**

```bash
nix flake check
nix build .#nixosConfigurations.oppy.config.system.build.toplevel   # composes before anyone rebuilds
nix build .#nixosConfigurations.spirit.config.system.build.toplevel
nix build .#nixosConfigurations.karkinos.config.system.build.toplevel
```

**Exit criteria:** all three system closures build; PR opened; no changes outside
`homes/rshen/**` and the two `flake.nix` input lines.

**Ongoing cadence after this:** change lands here → in neusis,
`nix flake update rshen-nixos-config` → rebuild. `homeConfigurations."rshen@oppy"` is for
`nix build` iteration only — **do not routinely `home-manager switch` it alongside neusis's
system-applied profile.** System-applied home-manager writes its generation to
`/nix/var/nix/profiles/per-user/…`, standalone to
`~/.local/state/nix/profiles/home-manager`; both claiming `~/.config` will clobber each
other's symlinks.

**Commit:** `Source rshen home profile from runxi-shen/nixos-config`

---

## Phase 6 — Retire nix-configs, update docs — status: TODO

Only after Phases 0–5 verify.

**Changes**

- `runxi-shen/nix-configs` is an unmodified fork of `afermg/nixos-config` kept as a
  reference bookmark; nothing references it (neusis mentions `afermg/nix-configs` in two
  comments only). **Archive rather than delete** — same effect, reversible. Needs explicit
  confirmation at execution time.
- Update `CLAUDE.md`: remove the "Syncing with Upstream" section (no longer true); document
  the two-repo relationship and the `nix flake update rshen-nixos-config` cadence.
- Delete `backup/personalize-pre-rebase-2026-08-22`.

**Verify**

```bash
grep -rn "nix-configs" ~/.claude/CLAUDE.md CLAUDE.md AGENTS.md   # no stale pointers
```

**Exit criteria:** `nix-configs` archived; `CLAUDE.md` describes the real workflow.

**Commit:** `Document multi-machine layout; drop upstream sync workflow`

---

## Deferred deliberately

**`nix flake update`.** `nixpkgs` sits at 2026-07-19 with a known livekit-on-darwin
breakage and a temporary `pandas-stubs` overlay. Restructure on a known-good lock; update
as its own commit afterwards so any regression is bisectable.

## Risks

- **Shared machines.** Phases 0–4 touch nothing on oppy/spirit/karkinos. Phase 5 does —
  hence the PR and the pre-merge closure builds.
- **Phase 1 deletions.** Recoverable from git history and from
  `backup/personalize-pre-rebase-2026-08-22`, which survives until Phase 6.
- **Phase 6 archival.** Reversible; deletion would not be. Confirm before acting.
