# Overlays

`default.nix` returns a **named attrset** of overlays, exported as the flake output
`outputs.overlays` and applied via `builtins.attrValues outputs.overlays` in
`modules/shared/default.nix`.

This is deliberately **not** the auto-loading directory scanner this repo used to carry.
That loader mapped every `*.nix` here into an anonymous list, so no individual overlay could
be referenced from anywhere else — and an exported `homeModule` may need to hand one
specific overlay to a consuming flake, which requires it to have a name. Pattern taken from
`afermg/nixos-config`.

**Adding an overlay:** add a named attribute to `default.nix`. Give it a file of its own
only when it carries enough explanation to be worth separating.

**Flakes only see tracked files.** `git add` before building.

## Current overlays

| name | purpose |
|---|---|
| `claude-code` | Claude Code from the `sadjow/claude-code-nix` flake input, taking `inputs` as an argument — something the old bare `final: prev:` loader could not do |

## Shape

```nix
{ inputs, ... }:
{
  my-overlay = final: _prev: {
    my-package = inputs.some-flake.packages.${final.stdenv.hostPlatform.system}.default;
  };

  from-a-file = import ./my-overlay.nix;
}
```

Prefer `final` over `prev` when referring to the resulting package set, and name the unused
argument `_prev` so `statix` stays quiet.
