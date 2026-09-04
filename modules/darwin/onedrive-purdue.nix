# Purdue OneDrive: a clean home-folder alias, and a tombstone for the ugly one
# Microsoft insists on creating.
#
# Imported EXPLICITLY by each host that signs into the Purdue tenant, rather
# than from hosts/darwin/default.nix. Both Macs currently want it, but that is
# a fact about those two machines, not about "a Mac" -- a future host that
# never signs into OneDrive should get nothing from this file, and an unused
# import is a one-line deletion.
#
# Three paths are involved, and only one of them is ugly:
#
#   ~/Library/CloudStorage/OneDrive-purdue.edu   the real sync root. Created and
#       owned by the macOS File Provider API once OneDrive signs in. NEVER
#       rename it -- the name is derived from the tenant, and File Provider
#       re-creates what it expects. It already contains no spaces.
#
#   ~/OneDrive - purdue.edu                      the home-folder shortcut. This
#       is the badly-formatted one. OneDrive exposes no preference to disable
#       it, hence the tombstone below.
#
#   ~/Purdue_OneDrive                            the alias declared here. This
#       is the one to actually use, in scripts and in Finder.
{ user, ... }:

{
  home-manager.users.${user} = { config, lib, ... }: {
    # mkOutOfStoreSymlink is essential: a plain `source` would try to copy the
    # target into the nix store, which for a live cloud folder would be
    # catastrophic. This emits a direct symlink to the real path.
    #
    # The target does not exist until OneDrive is signed in, and that is fine --
    # the symlink is created either way and simply dangles until then. Nothing
    # in activation stats it.
    home.file."Purdue_OneDrive".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Library/CloudStorage/OneDrive-purdue.edu";

    # Squat the path OneDrive uses for its own home-folder shortcut, so the
    # space-laden "OneDrive - purdue.edu" cannot appear -- or come back after an
    # app update.
    #
    # A 0-byte file with uchg makes OneDrive's unlink() fail with EPERM, and its
    # symlink() then fails with EEXIST. `hidden` keeps it out of Finder.
    #
    # ORDERING MATTERS on a fresh machine. Run build-switch BEFORE signing into
    # OneDrive: the guard below only ever replaces a symlink or nothing, so if
    # OneDrive has already created a real directory of synced files there, this
    # correctly refuses and the tombstone silently never lands. Check with
    # `/bin/ls -lO ~/"OneDrive - purdue.edu"` -- it should be a 0-byte regular
    # file flagged uchg,hidden.
    #
    # To undo:  chflags nouchg ~/"OneDrive - purdue.edu" && rm ~/"OneDrive - purdue.edu"
    home.activation.onedriveShortcutTombstone =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        p="$HOME/OneDrive - purdue.edu"
        # Only ever replace a symlink or nothing -- never a real file.
        if [ -L "$p" ] || [ ! -e "$p" ]; then
          /usr/bin/chflags nouchg "$p" 2>/dev/null || true
          rm -f "$p" || true
          touch "$p" || true
        fi
        /usr/bin/chflags uchg,hidden "$p" 2>/dev/null || true
      '';
  };
}
