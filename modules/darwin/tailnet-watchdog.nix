# Keeps the tailnet link alive on an unattended machine.
#
# Why this exists at all: `launchd.daemons.tailscaled` has RunAtLoad but no
# KeepAlive, and a tailscaled that is *running* is not the same as a tailscaled
# that is *reachable*. The failure this is built for is the soft one -- the
# process is alive, the daemon answers locally, but the node has dropped off the
# tailnet after a Wi-Fi flap or a DERP hiccup. launchd cannot see that; only an
# actual reachability probe can.
#
# Hard rule, and the reason the policy below is narrow: THIS MUST NEVER REBOOT.
# The disk is FileVault-encrypted with no auto-login, so a reboot parks the
# machine at the pre-boot unlock screen with no network stack and waits for a
# human to walk over. Rebooting would convert a recoverable soft failure into a
# hard one. Restart services in place; never the machine.
{ config, lib, pkgs, user, ... }:

let
  tailscale = config.services.tailscale.package;

  # Probe + remediate. Runs as root out of a LaunchDaemon, so it is alive
  # before login and independent of any GUI session.
  watchdog = pkgs.writeShellScript "tailnet-watchdog" ''
    set -uo pipefail
    PATH=${lib.makeBinPath [ tailscale pkgs.coreutils ]}:/usr/bin:/bin:/usr/sbin

    log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"; }

    # `tailscale status` exits non-zero when the node is not up, which is the
    # single cheapest signal that covers both "daemon dead" and "daemon alive
    # but logged out". --peers=false keeps the output small.
    if tailscale status --peers=false --json >/dev/null 2>&1; then
      exit 0
    fi

    log "tailnet probe FAILED; attempting remediation"

    # TODO(runxi): remediation policy -- see the note in chat.
    #
    # Everything above has established: the node is NOT on the tailnet right
    # now. Everything below is yours to decide. Available levers, cheapest
    # first:
    #
    #   tailscale up                       # re-assert prefs; fixes a logged-out
    #                                      # or half-configured daemon
    #   launchctl kickstart -k \
    #     system/com.tailscale.tailscaled  # hard-restart the daemon (-k kills
    #                                      # first); fixes a wedged process
    #   networksetup -setairportpower \
    #     en0 off && ... on                # bounce Wi-Fi; fixes the case where
    #                                      # the radio, not tailscale, is stuck
    #
    # Things to weigh:
    #   - Order and escalation. Try the cheap fix first and return, or go
    #     straight to the big hammer? A gentle fix that does not work means
    #     another 2 minutes offline before the next tick.
    #   - Idempotence under repeated failure. If the network is genuinely down
    #     (router rebooting, ISP out), this runs every 2 minutes for an hour.
    #     Bouncing Wi-Fi in a tight loop can make recovery *slower* than doing
    #     nothing. Consider backing off, or only escalating after N failures.
    #   - Blast radius. `launchctl kickstart -k` drops every live Tailscale SSH
    #     session, including the one you may be watching this log from.
    #
    # Whatever you write, do not add a reboot -- see the header.

    log "remediation finished"
  '';
in
{
  launchd.daemons.tailnet-watchdog = {
    serviceConfig = {
      Label = "org.runxi.tailnet-watchdog";
      ProgramArguments = [ "${watchdog}" ];

      # Every 2 minutes. Fast enough that a flap self-heals before you notice,
      # slow enough to be free. Deliberately StartInterval rather than a
      # KeepAlive-with-sleep loop: launchd owns the schedule, so a crashed
      # probe cannot silently stop the whole watchdog.
      StartInterval = 120;
      RunAtLoad = true;

      StandardOutPath = "/var/log/tailnet-watchdog.log";
      StandardErrorPath = "/var/log/tailnet-watchdog.log";
    };
  };
}
