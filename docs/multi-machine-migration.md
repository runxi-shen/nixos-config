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
would silently un-pin. **8 orphaned lock nodes dropped** (28 → 20), root inputs 15 → 10,
pin intact. (`2d2c07f6`'s commit message says "15 orphaned nodes"; that is wrong — 15 was
the *old root-input count*, transposed. Left uncorrected rather than rewrite history.)

---

## Phase 2 — Make the home profile portable — status: DONE (8d72fb0d)

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

**Carried forward from Phase 1 verification**

- **Orphaned Emacs stack.** `modules/shared/emacs.nix` and `config/emacs/{config.org,
  config.el}` now have **no importer** — their only consumers were the deleted
  `hosts/nixos/*`. No `.nix` deploys `config.el` either. Decide here: delete it, or wire it
  for Darwin. `CLAUDE.md` documents an Emacs workflow and a `build-switch-emacs` app, so
  this needs an explicit call rather than silent drift. `modules/shared/cachix/` is
  likewise unreferenced (pre-existing, not caused by Phase 1).
- **Git identity is per-host.** This repo hardcodes `shenrunxi@gmail.com`
  (`modules/shared/home-manager.nix:5`); neusis's `common/dev/git.nix` sets
  `shenrunxi@broadinstitute.org` for the lab servers. A portable profile cannot hardcode
  one. Make it an option with the gmail default, overridden per-host.
- **Username handling.** Adopt afermg's shape (`homes/amunoz/home.nix:1-9`): a
  `username ? null` argument with a Linux default, rather than refusing to set
  `home.username` at all. Set it via `lib.mkDefault` so a consumer — nix-darwin on the
  Macs, neusis on the servers — always wins and can never collide at eval.

**Exit criteria:** `homes/` contains no username and no `/Users/` path; this Mac still
builds. (Cross-building the Linux closure is gated on Phase 4's outputs existing.)

**Commit:** `Extract portable, username-agnostic home profile under homes/rshen`

**Deviations and decisions at execution time**

- **`imports` cannot branch on `pkgs`.** The first attempt used
  `imports = [ … ] ++ lib.optional pkgs.stdenv.hostPlatform.isDarwin ./gui.nix`, which is an
  **infinite recursion**: `pkgs` reaches a module through `_module.args`, which is part of
  `config`, and `imports` is resolved before `config` exists. `gui.nix` is therefore
  imported unconditionally and gated internally with `lib.mkIf`. Same trap applies to
  anything else added under `homes/`.
- **Username via `lib.mkDefault "rshen"`, not "never set it".** The stricter original
  invariant and afermg's `username ? null` default reconcile here: a plain definition
  outranks `mkDefault`, so nix-darwin (`runxishen`) and neusis (`rshen`) both win silently,
  and the literal `runxishen` still never appears under `homes/`. `home.stateVersion` gets
  the same treatment so the module works standalone.
- **Git identity is an option**, `rshen.gitUserEmail` / `rshen.gitUserName`, rather than a
  constant or a function argument. neusis sets the Broad address per host from its own tree
  without this repo knowing anything about it.
- **Packages moved from `environment.systemPackages` to `home.packages`.** That is what
  makes them shippable to machines where we control no system config. Note they were
  previously installed *twice* on this Mac — once system-wide via
  `hosts/darwin/default.nix` and again in `home.packages` via `modules/darwin/packages.nix`.
  Verified package-neutral by evaluating the union of both option sets before and after:
  **77 derivations → 77, zero lost, zero gained.**

  **That claim covers PATH and closure contents only — not `/Applications` placement.**
  Emptying `environment.systemPackages` also empties `system.build.applications`
  (`f4yasiyp…` contained `Zed.app`; `k60ncfwy…` is empty), and nix-darwin's activate script
  rsyncs that into `/Applications/Nix Apps` with `--archive --delete`. See the Phase 3
  carry-forward.
- **Emacs stack deleted** (`modules/shared/emacs.nix`, `config/emacs/{config.org,config.el,
  init.el}`), resolving the Phase 1 carry-forward. No importer survived Phase 1, no `.nix`
  deployed `config.el`, and emacs is in no package list. **Authorship, corrected:** 58
  commits touch it, not 55 — 55 Dustin Lyons, 2 from this migration itself (`2d2c07f6`,
  `8d72fb0d`), and 1 from an outside upstream PR (`58db206b`, Kristian Hartikainen).
  `8d72fb0d`'s commit message says "all 55 commits … are the upstream owner's", which
  undercounts and misattributes; the conclusion is unaffected — none of the deleted content
  is this repo owner's own work. `modules/shared/cachix/` is still unreferenced — Phase 6.
- **Two small departures from the phase's stated package split**, both deliberate: `btop`
  went to the portable `homes/rshen/packages.nix` rather than `machines/*.nix` (it is useful
  everywhere), and `procps` was added to `machines/oppy.nix` to supply the `ps` that neusis
  lists — `ps` is not a nixpkgs attribute.
- **The grep guard must stay literal.** Comments in `homes/` that quoted the forbidden
  strings tripped the invariant check. Reworded; do not reintroduce them, or the guard
  stops guarding.

**Verified beyond the stated checks:** the built home generation resolves
`@resurrect-dir '/Users/runxishen/.cache/tmux/resurrect'` and
`Include /Users/runxishen/.ssh/config_external` — byte-identical to the pre-refactor
hardcodes, now derived rather than written.

---

## Phase 3 — Hostname-keyed Macs — status: DONE (d485bdca)

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

**Carried forward from Phase 2 verification — decide BEFORE running `build-switch`**

Phase 2 reduced `environment.systemPackages` to agenix alone, which empties
`system.build.applications`. nix-darwin's activate script rsyncs that into
`/Applications/Nix Apps` with `--archive --delete`, so **the first `build-switch` after
Phase 2 deletes the live `/Applications/Nix Apps/Zed.app`** (310 MB, present now).

Narrow but user-visible. Zed stays installed, on PATH, and at
`~/Applications/Home Manager Apps/Zed.app` — but that is a symlink into `/nix/store`, which
Spotlight does not index (`mdfind -name Alacritty.app` returns nothing, same mechanism), so
`mdfind kMDItemCFBundleIdentifier == 'dev.zed.Zed'` currently returns **only** the doomed
path. No dock entry references it. Either accept explicitly, or add `pkgs.zed-editor` back
to Darwin `environment.systemPackages`.

Add an app-bundle check to the Verify list below — `ls '/Applications/Nix Apps'` plus an
`mdfind` for the editor bundle id. None of the existing post-switch checks would notice a
GUI bundle disappearing.

**Carried forward from Phase 1 verification — widen the `apps/` scope**

Deleting `nixosConfigurations` orphaned more than `build-switch`. Delete
`apps/{x86_64-linux,aarch64-linux,x86_64-darwin}` and `mkLinuxApps` wholesale:

- `apps/*-linux/build-switch` (`:39,42,55`), `build-switch-emacs`, `clean:16`, `install`
  and `install-with-secrets` all target the dropped `nixosConfigurations`.
- `apps/*/apply` splices `insert_secrets_input` against a **`disko` anchor** that no longer
  exists in `flake.nix` — running it would now *truncate* the flake.
- `apps/x86_64-darwin/` has been unreachable since Phase 0 reduced `darwinSystems`.

Also consider afermg's position here: he has **no `apps/` at all**, driving
`darwin-rebuild --flake .#<host>` directly. Keeping `apps/` is a deliberate divergence —
`CLAUDE.md` documents `nix run .#build-switch` as *the* rebuild command.

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

**Deviations and decisions at execution time**

- **Hostname mismatch, solved by aliasing.** `scutil --get LocalHostName` returns
  `Runxis-MacBook-Pro`, not the plan's clean `runxi-mbp` key. Rather than rename the Mac or
  adopt an ugly key, both names bind to the same `mkDarwin` result — verified identical
  `drvPath`. `nix eval .#darwinConfigurations --apply builtins.attrNames` →
  `[ "Runxis-MacBook-Pro" "runxi-mbp" ]`.
- **No `lib/default.nix`.** `mkDarwin { host, user }` is an inline `let` inside
  `darwinConfigurations`, per `afermg/nixos-config`. `system` is not a parameter —
  aarch64-darwin is the only Darwin target.
- **More moved to the host file than the phase listed.** Beyond dsh-web, the cloud links and
  the tombstone, `hosts/darwin/runxi-mbp.nix` also takes the casks, the dock entries (per the
  Target structure), and the `CODEX_CA_CERTIFICATE` launchd variable — that pem is generated
  by *this* machine's Obsidian install, so leaving it shared would point a second Mac at a
  nonexistent file.
- **`apps/aarch64-darwin/apply` deleted too.** Upstream's fresh-install onboarding script:
  it `sed`-replaced `%USER%` tokens across *every file in the tree*, spliced `flake.nix`
  against the `disko` anchor Phase 1 removed (so it would now truncate the flake), and opened
  the upstream repo to ask for a star. Running it on a configured machine would corrupt the
  config. `build` and `build-switch` now resolve the host at runtime and accept an explicit
  override; `build-switch` fails with the known-host list *before* reaching sudo.
- **`rollback` was broken and is now fixed** (found by verification, pre-existing upstream).
  It called `darwin-rebuild --list-generations` unprivileged, which dies on the root-owned
  system-profile lock — and under `sh -e` the script exited before even reaching the prompt.
  Both calls now use `sudo`. The `--flake .#<host>` it used to pass was inert: a generation
  switch reads `systemConfig` back out of the profile. This matters because `CLAUDE.md`
  names `nix run .#rollback` as *the* recovery path for a bad rebuild.
- **`build-switch`'s host precheck was a regression**, also found by verification. It ran a
  full closure evaluation with `>/dev/null 2>&1` and reported *any* failure as "unknown
  host" — including this repo's most-documented footgun, a new file not yet `git add`ed.
  Replaced with a membership test over `builtins.attrNames`; real errors now propagate
  verbatim, and `set -e` still guarantees the abort-before-sudo property.

**Proof it was a pure refactor:** the new system derivation has byte-identical `inputDrvs`
to the pre-phase one and an identical `home-files` list. The sole textual delta in the whole
closure was one em-dash normalized to `--` inside an activation-script comment.

**Post-switch verification (all passed).** `/run/current-system` matched the expected
toplevel; all 10 dock entries intact; `~/Purdue_OneDrive` and `~/Nutstore` resolve through
the store hop to the real cloud directories; the OneDrive tombstone is still 0-byte
`uchg,hidden`; `dsh-web` loaded; `claude --version` = 2.1.220. As predicted,
`/Applications/Nix Apps/` is now empty and `mdfind` finds no Zed — the owner accepted this
before the switch.

**Notes for when the second Mac is registered** (from verification):

- `hosts/darwin/runxi-mbp.nix` calls `modules/darwin/casks.nix`, which is therefore now
  effectively *this host's* cask list despite living under `modules/`. A second host should
  get its own list rather than share it.
- **`local.dock.entries` silently defaults to `[]`.** `types.listOf` supplies an
  `emptyValue`, so a host file that omits the dock block does **not** fail to evaluate — and
  because `modules/darwin/home-manager.nix` sets `local.dock.enable = true`
  unconditionally, the new Mac's dock would be *emptied* by `dockutil --remove all`. Copy
  the dock block from `runxi-mbp.nix`, or add an assertion. (An earlier note here claimed
  the missing default would error; that was wrong.)
- `nix.enable = false` sits in the shared `hosts/darwin/default.nix` but is a fact about
  *this* Mac running Determinate Nix, and it silently voids the `nix.settings` block beside
  it — `/run/current-system/etc` has no `nix.conf`. Misleading for a Mac installed with the
  upstream installer.
- The `dsh` wrapper stayed in the Mac-shared `modules/darwin/packages.nix` even though the
  `dsh-web` agent it pairs with moved host-side. It degrades gracefully (exit 1 with a
  reinstall hint), but the pair should end up on the same side.
- Nothing declaratively sets the machine name, so the flake key stays coupled to imperative
  `scutil` state. `networking.localHostName = host;` would make the canonical key
  self-enforcing and retire the alias — declined here only because the plan chose not to
  rename this Mac.

**Activation ordering caveat:** the nix-darwin activate script is `set -e` and `brew bundle`
runs *before* home-manager activation. A failed cask download aborts the switch with the
system profile already advanced and HM not yet activated. Re-running `build-switch` on a
working network completes it.

---

## Phase 4 — Export the agents module — status: DONE (pending commit)

**Scope changed at execution time.** This phase originally exported the *whole* home
profile (`homeModules.rshen` = all of `homes/rshen`) and Phase 5 shrank neusis's
`homes/rshen/machines/<host>.nix` to a single import of it. The owner rejected that:

> "definitely NO NEED to replicate my whole Mac config over there, but keep the installed
> software there minimal for my user is totally fine. What I have configured in my neusis
> for my user `rshen` across machines are good enough, but I just need pi and also codex to
> be installed and configured into nix config properly."

and separately, as a standing constraint:

> "I ONLY touch my own home config customized for myself on those machines, NEVER the
> system-level shared config, a crucial thing."

The **ownership model is still Alan's** — nixos-config owns the profile, neusis imports it —
but it is reached **incrementally** rather than in one jump. Step one exports only what
neusis genuinely cannot supply. Modules migrate here later, one at a time, each deleting its
corresponding neusis import as its replacement lands, until
`neusis/homes/rshen/machines/oppy.nix` is a single import like
`afermg/homes/amunoz/machines/oppy.nix`.

**Ownership boundary in neusis** (verified against the live repo — fifteen user homes exist):

| path | ownership | rule |
|---|---|---|
| `homes/rshen/**` | Runxi alone | safe to change |
| `homes/common/**` | **shared by all fifteen users** | never edit; dropping *imports* of it from `homes/rshen/**` affects nobody |
| `machines/**`, `users/cslab*.nix` | system-level, shared | never touch |
| `flake.nix` | shared | one input line only — precedented by Alan's `amunoz-nixos-config` |

**Changes**

- `homes/rshen/agents.nix` — `claude-code`, `codex`, `pi-coding-agent`, each sourced from
  **this flake's own inputs** rather than the consumer's `pkgs`.
- `flake.nix` — `homeModules.rshen-agents` wrapping it, plus
  `homeConfigurations."rshen@oppy"` as an evaluation gate, plus `inputs` added to the darwin
  `specialArgs` and `extraSpecialArgs` so the Mac resolves the module identically.
- Deleted `homes/rshen/machines/{oppy,spirit,karkinos}.nix` — dead. They held duckdb,
  poetry, pixi, gitleaks, btop, screen, cmake, rsync, which neusis already installs.
- Removed `codex`/`pi-coding-agent` from `modules/darwin/packages.nix` and `claude-code`
  from `homes/rshen/dev.nix`; `agents.nix` is now the single definition for both platforms.

**Why the packages come from our inputs, not the consumer's `pkgs`**

neusis pins nixpkgs at `36a601196c4e` (2026-04-04). Measured against it:

| package | neusis pin | this repo's pin (2026-07-19) |
|---|---|---|
| `pi-coding-agent` | **absent entirely** | 0.80.10 |
| `codex` | 0.92.0 | 0.144.4 |

Bumping neusis's nixpkgs would rebuild shared machines for fifteen people and is not ours to
do. So this copies `afermg/nixos-config`'s `homes/amunoz/packages.nix`, which hit the
identical problem with the identical package:

```nix
latestPiCodingAgent =
  inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent;
```

`rshenInputs ? inputs` (not plain `inputs`) is what makes it hold: a consuming flake passes
its own `inputs` through `extraSpecialArgs`, which would shadow ours and silently undo the
pinning. `homeModules.rshen-agents` sets `_module.args.rshenInputs = inputs`.

**A `pi` naming trap, resolved.** neusis already has an `llm-agents` input exposing a package
called `pi` (0.65.2, `badlogic/pi-mono`), which looks like a zero-new-input fix. It is the
**same upstream project** — `badlogic/pi-mono` and `earendil-works/pi` are one repository,
GitHub id `1035029907`, the old path being a transfer redirect — just older and packaged
from the monorepo rather than the coding-agent subpackage. Using `pi-coding-agent` from our
pin is the deliberate choice; an earlier note in this document claiming they were *different
tools* was wrong.

**Deliberately NOT exported:** `homes/rshen/core.nix`. It sets `programs.git`, and so does
neusis's `homes/common/dev/git.nix` (identity, SSH commit signing, the Broad address) — two
plain definitions collide at eval. The `rshen.gitUserEmail` option added in Phase 2 only
becomes useful if git ownership ever migrates here.

**Resolves the Phase 2 carry-forwards:** no `nixpkgs.config` or `nixpkgs.overlays` is set in
the export (neusis sets both in `homes/common/home_manager.nix`, and every package comes
from our inputs), so the `useGlobalPkgs` warning cannot arise. The "all overlays or just
claude-code?" question is moot for the same reason.

**Verify**

```bash
nix flake check
# THE gate -- EVALUATE, do not build (see below).
nix eval --raw '.#homeConfigurations."rshen@oppy".activationPackage.drvPath'
nix eval --json '.#homeConfigurations."rshen@oppy".config.home.packages' \
  --apply 'ps: map (p: p.name) ps'
nix run .#build     # Mac unaffected
```

**The plan's original gate was impossible.** It said
`nix build .#homeConfigurations."rshen@oppy".activationPackage`. That cannot succeed on a
Mac: most of the closure substitutes from cache, but home-manager generates a few trivial
x86_64-linux derivations (`dummy-xdg-mime-dirs1`, `hm_home...keep`) that exist in no binary
cache and must be built natively — the build dies with `required system or feature not
available` regardless of how healthy the config is. Forcing `.drvPath` evaluates the whole
module tree, which is where this phase's class of bug lives. `nix.linux-builder.enable` would
enable a genuine cross-build if ever wanted.

**Exit criteria met:** the Linux closure evaluates and resolves `codex-0.144.4`,
`pi-coding-agent-0.80.10`, `claude-code-2.1.220` for x86_64-linux; `nix flake check` exits 0;
`nix run .#build` exits 0; the Mac's `home.packages` set is unchanged at 66 derivations,
zero lost and zero gained.

**Commit:** `Export homeModules.rshen-agents for the lab servers`

---

## Phase 5 — Wire up neusis — status: TODO

**Separate repo. Land as a PR — this rebuilds machines other people use.**

**Scope reduced.** The original phase deleted `homes/rshen/home.nix`, dropped the
`claude-code-rshen` input, and shrank each `homes/rshen/machines/<host>.nix` to one import.
That would have discarded all eleven `homes/common/` imports rshen currently relies on:

| import | provides |
|---|---|
| `common/home_manager.nix` | overlays, allowUnfree, `stateVersion = "25.11"` |
| `common/dev/` | editors.nix, nixvim, terminals, zellij, wezterm, yazi, kalam |
| `common/dev/git.nix` | identity + SSH commit signing, Broad address |
| `common/themes/` | stylix theming |
| `common/browsers/` | brave (+ policy), firefox |
| `common/network/` | tailscale |
| `common/misc/` | conferencing, input_leap, us_eng, virtualization |
| `common/secrets/` | tsauthkey |
| `common/gpu_tools.nix` | nvitop |

The owner keeps all of it. This phase is now **additive**.

**Changes in `runxi-shen/neusis`** — three lines, two files under `homes/rshen/**` plus one
shared-file input line:

1. `flake.nix`: add
   `rshen-nixos-config = { url = "github:runxi-shen/nixos-config"; };`
2. `homes/rshen/machines/oppy.nix`: append
   `inputs.rshen-nixos-config.homeModules.rshen-agents` to the existing `imports` list,
   leaving all eleven `common/` imports untouched. `spirit.nix` and `karkinos.nix` already
   import `oppy.nix`, so they inherit it for free.
3. `homes/rshen/home.nix`: **remove** the
   `inputs.claude-code-rshen.packages.${system}.claude-code` line. Both it and our module
   provide `bin/claude`, and two derivations claiming the same path make `home.packages`
   fail with a collision. Leave the now-unused `claude-code-rshen` input in `flake.nix`
   alone — removing it is a shared-file edit with no benefit.
4. Leave `users/cslab*.nix` and everything under `machines/` alone. Account, shell and SSH
   key stay in neusis — correct for a shared machine, and outside the owner's boundary.
5. **Do not touch `homes/common/**`.** It is shared by fifteen users.

**Verify**

```bash
nix flake check
nix build .#nixosConfigurations.oppy.config.system.build.toplevel   # composes before anyone rebuilds
nix build .#nixosConfigurations.spirit.config.system.build.toplevel
nix build .#nixosConfigurations.karkinos.config.system.build.toplevel
```

Run these **on a Linux machine** — the same "required system or feature not available"
limitation that reshaped Phase 4's gate applies here, and these are full system closures.

**Watch for:** a second nixpkgs generation landing on the servers. Our three agents come
from a 2026-07-19 pin while everything else on the box comes from neusis's 2026-04-04 pin,
so some runtime dependencies will be duplicated. `nix build --dry-run` on the exported
closure reported 209 paths / 625 MiB to fetch, though much of that will already exist from
neusis's own profile. Measure real disk impact on oppy before assuming it is free.

**Exit criteria:** all three system closures build; PR opened; no changes outside
`homes/rshen/**` and the one `flake.nix` input line.

**Ongoing cadence after this:** change lands here → in neusis,
`nix flake update rshen-nixos-config` → rebuild. `homeConfigurations."rshen@oppy"` is for
`nix eval`/`nix build` iteration only — **do not routinely `home-manager switch` it
alongside neusis's system-applied profile.** System-applied home-manager writes its
generation to `/nix/var/nix/profiles/per-user/…`, standalone to
`~/.local/state/nix/profiles/home-manager`; both claiming `~/.config` will clobber each
other's symlinks.

**Migrating further later.** To move a capability from neusis to here: add the equivalent
module under `homes/rshen/`, export it as another `homeModules.rshen-*`, import it in
`homes/rshen/machines/oppy.nix`, delete the corresponding `common/` import in the same
commit, and rebuild. One capability per PR keeps each step revertible. `programs.git` is the
one to do carefully — see the collision note in Phase 4.

**Commit:** `Source rshen's coding agents from runxi-shen/nixos-config`

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
- **Broaden the doc sweep** (from Phase 1 verification). `CLAUDE.md` and the byte-identical
  `AGENTS.md` still teach the deleted auto-scanning overlay contract (`:85`, `:99-103`,
  `:131`) and still point at deleted paths — `modules/nixos/packages.nix`,
  `hosts/nixos/default.nix` "felix", `disk-config.nix`, `templates/`, `.#install`,
  `.#build-switch-emacs` — plus a Wayland/KDE "System Environment" section describing a
  machine this repo no longer has. `overlays/README.md:3` repeats the auto-load claim and
  lists nine deleted overlays. `README.md` is still upstream's project README verbatim
  (`:384` links the deleted `modules/nixos/README.md`). Also `apps/README.md` (names the
  three deleted app sets), `modules/shared/README.md` (lists two files deleted in Phase 2)
  and `modules/darwin/README.md` (lists a `modules/darwin/default.nix` that has never
  existed). Sweep all at once, against the final tree — Phases 2-4 invalidate more first.
- Refresh the **Target structure** sketch above: it still lists `codex` under
  `homes/rshen/dev.nix`, but `codex` and `pi-coding-agent` moved to
  `modules/darwin/packages.nix` (Mac-only) in `8abee7d9`, and `gui.nix` is imported
  unconditionally rather than "Macs only".
- Drop the stale `.gitignore` entries `modules/nixos/scripts/__pycache__/` and
  `tests/garage-analyzer/__pycache__/`.
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

Retire `overlays/pandas-stubs-skip-tests.nix` in that same commit. Phase 1 verification
found it is already **obsolete at the current pin**: `python3Packages.pandas-stubs` is now
`3.0.3.260530` (the overlay's comment says 2.3.3) and `doCheck = false` landed upstream, so
its only remaining effect is `pythonImportsCheck = [ ]`.

## Risks

- **Shared machines.** Phases 0–4 touch nothing on oppy/spirit/karkinos. Phase 5 does —
  hence the PR and the pre-merge closure builds.
- **Phase 1 deletions.** Recoverable from git history and from
  `backup/personalize-pre-rebase-2026-08-22`, which survives until Phase 6.
- **Phase 6 archival.** Reversible; deletion would not be. Confirm before acting.
