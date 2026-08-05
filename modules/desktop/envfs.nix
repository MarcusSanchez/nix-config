# envfs mounts a FUSE filesystem at /bin and /usr/bin that resolves any
# interpreter against the caller's PATH, so scripts with hardcoded
# shebangs run on NixOS. JetBrains Toolbox is the reason it's here: it
# generates its CLI launchers (~/.local/share/JetBrains/Toolbox/scripts/*)
# with `#!/bin/bash`, which NixOS doesn't have — only /bin/sh — and it
# rewrites them on every IDE update, so patching the shebang by hand
# never sticks.
#
# Desktop flavor only, deliberately: the WSL boxes rebuild themselves
# unattended from pushed main every week, and a FUSE mount over /bin is
# not something to hand them without testing on a machine someone is
# looking at. Promote it to modules/nixos if the WSL side ever wants it.
{ ... }:

{
  services.envfs.enable = true;
}
