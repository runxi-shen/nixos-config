# Mac-only packages. The portable set lives in homes/rshen/{packages,dev,gui}.nix
# and is applied by importing that profile in ./home-manager.nix.
{ pkgs }:

with pkgs; [
  # C
  # Coding agents that stay on the Macs. Deliberately NOT in
  # homes/rshen/dev.nix: that profile ships to oppy/spirit/karkinos, which are
  # shared lab machines that do not have these today and did not ask for them.
  # claude-code is the exception and stays portable -- neusis already installs it.
  codex # OpenAI Codex CLI coding agent

  # D
  dockutil # Manage icons in the dock

  # dsh (DeepSeek Harness) launcher. Upstream 0.1.x enables cordis-plugin-hmr in
  # the web profile, which aborts boot unless node runs with --expose-internals.
  # node rejects that flag from NODE_OPTIONS, so bin.js must be invoked directly
  # -- plain `npx @deepseek-ai/dsh web` cannot work. The npm tree stays imperative
  # under ~/.local/share/dsh (455 deps, pre-1.0 rc-only; not worth pinning a
  # buildNpmPackage hash until upstream cuts a stable release).
  (writeShellScriptBin "dsh" ''
    entry="$HOME/.local/share/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js"
    if [ ! -f "$entry" ]; then
      echo "dsh: npm tree missing at ~/.local/share/dsh" >&2
      echo "reinstall: mkdir -p ~/.local/share/dsh && cd ~/.local/share/dsh \\" >&2
      echo "           && npm init -y && npm install @deepseek-ai/dsh" >&2
      exit 1
    fi
    exec ${nodejs_22}/bin/node --expose-internals "$entry" "$@"
  '')

  # F
  fswatch # File change monitor

  # P
  pi-coding-agent # Pi coding agent CLI (read/bash/edit/write tools); binary is `pi`
  # rpi-imager # Raspberry PI SD card imager (commented out - broken in current nixpkgs, build fails trying to fetch git)
]
