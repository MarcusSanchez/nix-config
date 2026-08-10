# Tailscale on the mac: the open-source daemon via nix-darwin, NOT the GUI
# cask — deliberately the opposite call from before, made so this machine can
# be a Tailscale SSH *server* like the WSL boxes. The SSH server cannot run
# in the sandboxed GUI builds (App Store or Standalone pkg); only the
# unsandboxed OSS tailscaled can spawn login shells. The cost is that there
# is no menu bar app at all — the CLI (usable without sudo thanks to
# --operator below) and the admin console are the interface.
#
# Never add the "tailscale-app" cask back while this is enabled: macOS runs
# ONE tailscaled at a time, and the GUI's network extension fights the
# daemon's utun — Tailscale's documented migration between variants is
# uninstall + reboot, not coexistence.
#
# MagicDNS needs no hand-holding here: /etc/resolv.conf is a decoy on macOS
# (resolution goes through mDNSResponder), and the nix-darwin module drops
# /etc/resolver/ts.net -> nameserver 100.100.100.100, macOS's split-DNS
# hook, so *.ts.net resolves system-wide. If bare hostnames ever fail where
# the FQDN works, that's the search domain — add
# `networking.search = [ "tailc8bd6a.ts.net" ]` rather than debugging DNS.
#
# Known wart, accepted: nix-darwin#1688 (open) — after some switches the
# daemon needs a manual restart, and a switch performed *over Tailscale SSH*
# can kill its own session when tailscaled restarts. On a laptop rebuilt
# locally that degrades to "run one command":
#   sudo launchctl kickstart -k system/com.tailscale.tailscaled
# Remote Login (system.nix) stays on as the password-auth fallback path.
#
# Enrolment is interactive, once: sudo tailscale up --ssh
# After that, the activation hook below re-asserts prefs on every switch.
{ config, lib, ... }:

{
  services.tailscale.enable = true;

  # `set`, not `up`: set changes only the flags given and is idempotent,
  # where up resets every unspecified pref to its default. Same idea as
  # NixOS's tailscaled-set unit, which darwin's module doesn't have.
  # --accept-risk=lose-ssh suppresses the interactive prompt that would
  # otherwise hang activation when toggling SSH over a Tailscale SSH
  # session. Guarded so a not-yet-enrolled or not-yet-started daemon warns
  # instead of failing the switch.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    for _ in $(seq 1 15); do
      [ -S /var/run/tailscaled.socket ] && break
      sleep 1
    done
    if [ -S /var/run/tailscaled.socket ]; then
      ${lib.getExe' config.services.tailscale.package "tailscale"} set \
        --ssh --operator=${config.identity.username} --accept-risk=lose-ssh \
        || echo "tailscale set skipped (node not enrolled yet — sudo tailscale up --ssh)" >&2
    else
      echo "tailscaled socket never appeared (nix-darwin#1688) — run:" >&2
      echo "  sudo launchctl kickstart -k system/com.tailscale.tailscaled" >&2
    fi
  '';
}
