# Default spirit profile: reuse oppy's. Diverge only when spirit actually needs
# something different -- this mirrors how neusis structures it today.
{ ... }:

{
  imports = [ ./oppy.nix ];
}
