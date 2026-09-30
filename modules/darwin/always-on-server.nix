# Turns a Mac into an always-on headless workstation reachable over the tailnet.
#
# Imported by hosts/darwin/runxi-mbp.nix only. This is deliberately NOT in
# hosts/darwin/default.nix: it is true of the machine that lives on a shelf at
# home, not of "a Mac". Applying it to a laptop that travels would pin that
# laptop awake on battery and expose sshd on every coffee-shop network.
#
# The three failure modes this is built against, in order of likelihood:
#
#   1. The lid gets closed         -> clamshell sleep, which no sleep *timer*
#                                     prevents. Needs pmset disablesleep.
#   2. Something panics or wedges  -> restartAfterFreeze brings it back.
#   3. FileVault stops a reboot    -> unavoidable by design; see the
#                                     `authrestart` note under power, below.
{ config, lib, pkgs, user, ... }:

{
  # ---------------------------------------------------------------------------
  # Remote shell
  # ---------------------------------------------------------------------------
  # Two independent paths in, on purpose, because they fail for different
  # reasons:
  #
  #   tailnet IP:22  -> Tailscale SSH. Identity-based, governed by tailnet
  #                     ACLs, needs no keys on the client. This is the path
  #                     that makes a phone usable. Enabled on the daemon with
  #                     `tailscale up --ssh`, not from here -- it is tailnet
  #                     state, not host state.
  #   LAN IP:22      -> this sshd. Survives tailscaled being broken or the
  #                     tailnet being unreachable, which is exactly when you
  #                     need a way in.
  #
  # tailscaled intercepts :22 on the tailnet address before sshd sees it, so
  # the two coexist without a port conflict.
  services.openssh = {
    enable = true;
    extraConfig = ''
      # Keys only. There is no interactive user at this machine to type a
      # password, so password auth could only ever serve an attacker.
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no

      # Drop sessions whose client vanished (phone locked, laptop lid shut)
      # instead of accumulating dead sshd processes for days. 60s x 5 = 5min.
      # Long-running work belongs in tmux, which survives the disconnect
      # regardless -- see homes/rshen/core.nix for the continuum config.
      ClientAliveInterval 60
      ClientAliveCountMax 5
    '';
  };

  # ---------------------------------------------------------------------------
  # Tailnet
  # ---------------------------------------------------------------------------
  # nixpkgs' tailscaled as a launchd *daemon* (RunAtLoad, system domain), not
  # the Tailscale.app cask.
  #
  # This distinction is the whole point of the machine. The cask is a GUI app:
  # its tailscaled starts when a user logs in, so between boot and login the
  # machine has no tailnet address and is unreachable -- which is precisely the
  # window you need it in after an unattended restart. A system daemon is up
  # before the login window is even drawn.
  #
  # Consequence: no menubar icon on this host, and `tailscale-app` must stay
  # out of its cask list -- two tailscaled instances fight over the utun
  # interface. Use the CLI here; the GUI lives on the other Mac.
  services.tailscale.enable = true;

  # ---------------------------------------------------------------------------
  # Power
  # ---------------------------------------------------------------------------
  power = {
    sleep = {
      # Never idle-sleep the machine. macOS keeps separate pmset profiles per
      # power source and the AC profile already defaulted to `sleep 0`; this
      # states it declaratively so a fresh install cannot come up otherwise.
      computer = "never";

      # The display is the one thing that SHOULD sleep -- there is no monitor
      # attached, and an awake framebuffer is pure waste. Sleeping the display
      # does not sleep the system.
      display = 10;

      # Keep the SSD awake. Spinning it down saves almost nothing on flash and
      # adds wake latency to every remote command.
      harddisk = "never";
    };

    # Come back from a kernel panic or a wedge without a human. The one case
    # this cannot cover is FileVault: the machine reboots, then waits at the
    # pre-boot unlock screen with no network stack. For *planned* reboots use
    # `authrestart`, which caches the unlock key for exactly one boot:
    #
    #     sudo fdesetup authrestart
    #
    # (also available as the `reboot-unattended` alias -- see below.)
    restartAfterFreeze = true;

    # `power.restartAfterPowerFailure` is deliberately NOT set. It is a desktop
    # feature; `systemsetup -getRestartPowerFailure` answers "Not supported" on
    # a notebook, and nix-darwin turns that into a *preflight check* that aborts
    # the whole activation (modules/system/checks.nix:267) rather than a no-op.
    # Verified the hard way: setting it failed this exact switch.
    #
    # Nothing is lost. On a laptop the battery already is the UPS -- a power cut
    # switches to battery for hours instead of cutting the machine off, so there
    # is no post-power-failure boot to configure. This is the one respect in
    # which a MacBook is a *better* always-on box than a Mac mini. Uncomment it
    # only if this config ever lands on a desktop.
  };

  # Clamshell. This is the setting that actually keeps a closed-lid MacBook up,
  # and the one with no nix-darwin option -- power.sleep.* drives `systemsetup`,
  # which has no equivalent. Closing the lid triggers clamshell sleep through a
  # path that ignores every sleep *timer*, so without this the machine goes
  # offline the moment the lid shuts, no matter what `sleep` is set to.
  #
  # `-a` covers both power profiles. On battery that is a deliberate choice for
  # this host: an unattended box should ride out a power cut on battery rather
  # than sleep halfway through a task. It is also why this module must not be
  # applied to a laptop that travels.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "configuring clamshell (disablesleep)..." >&2
    /usr/bin/pmset -a disablesleep 1 || \
      echo "warning: could not set disablesleep; closed-lid operation will sleep" >&2
  '';

  # ---------------------------------------------------------------------------
  # Operator conveniences
  # ---------------------------------------------------------------------------
  home-manager.users.${user} = {
    # The reboot you almost always want on a FileVault machine you cannot
    # physically reach. A bare `reboot` strands it at the unlock screen;
    # authrestart hands the key to the next boot exactly once, so the machine
    # comes all the way back up on its own -- sshd and tailscaled included --
    # while the disk stays encrypted at rest.
    programs.zsh.shellAliases.reboot-unattended = "sudo fdesetup authrestart";
  };
}
