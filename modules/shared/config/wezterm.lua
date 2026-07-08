-- WezTerm configuration
-- Managed declaratively by home-manager (see modules/shared/files.nix).
-- This file is symlinked read-only into ~/.config/wezterm/wezterm.lua.
-- Edit it in the repo and run `nix run .#build-switch` to apply.
--
-- The GUI app itself comes from the Homebrew cask "wezterm"
-- (modules/darwin/casks.nix), NOT from nixpkgs -- so there is no
-- duplicate WezTerm binary in the Nix store.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ── Font ───────────────────────────────────────────────────────────────
-- Matches the Alacritty config: MesloLGS NF (a Nerd Font, already
-- installed via modules/shared/fonts.nix) at size 14 on macOS.
config.font = wezterm.font 'MesloLGS NF'
config.font_size = 14.0

-- ── Window ─────────────────────────────────────────────────────────────
config.window_padding = { left = 24, right = 24, top = 24, bottom = 24 }
config.window_background_opacity = 1.0
config.hide_tab_bar_if_only_one_tab = true
config.default_cursor_style = 'SteadyBlock'

-- ── Colors ─────────────────────────────────────────────────────────────
-- The same palette as the Alacritty config, ported to WezTerm so both
-- terminals look identical.
config.colors = {
  foreground = '#c0c5ce',
  background = '#1f2528',

  ansi = {
    '#1f2528', -- black
    '#ec5f67', -- red
    '#99c794', -- green
    '#fac863', -- yellow
    '#6699cc', -- blue
    '#c594c5', -- magenta
    '#5fb3b3', -- cyan
    '#c0c5ce', -- white
  },
  brights = {
    '#65737e', -- bright black
    '#ec5f67', -- bright red
    '#99c794', -- bright green
    '#fac863', -- bright yellow
    '#6699cc', -- bright blue
    '#c594c5', -- bright magenta
    '#5fb3b3', -- bright cyan
    '#d8dee9', -- bright white
  },
}

-- ── Shell ──────────────────────────────────────────────────────────────
-- WezTerm launches your login shell from the system passwd entry, which
-- nix-darwin sets to the Nix-managed zsh (users.users.runxishen.shell).
-- So unlike Alacritty, no explicit `default_prog` workaround is needed.
-- If you ever want to force it, uncomment and hardcode the path:
-- config.default_prog = { '/run/current-system/sw/bin/zsh', '-l' }

config.scrollback_lines = 50000

return config
