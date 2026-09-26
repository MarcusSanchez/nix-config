# Noctalia — the trial second shell beside the session's default DMS,
# round two (the 4.x-era experiment and its greeter-session machinery
# live in git history; this round uses the lighter live-swap shape the
# iNiR trial proved). v5 straight from nixpkgs, quickshell-based like
# DMS, quiet-by-design and config-file-driven; its settings are
# machine-local (~/.config/noctalia/settings.json) and deliberately
# start stock. DMS keeps the session's spawn-at-startup — a reboot
# always comes back to DMS; the shell:* pair below swaps the LIVE
# session. Both shells are quickshell configs, so each command puts
# down both before starting its target, and the lock guard refuses a
# locked session (killing the active locker leaves niri's fail-secure
# screen). The spotlight/lock binds in niri.config.kdl dispatch to
# whichever shell is running (`noctalia msg` is the IPC surface).
{ pkgs, ... }:

let
  mkShellSwitch =
    name: script:
    pkgs.runCommand "shell-${name}" { } ''
      mkdir -p $out/bin
      install -m755 ${pkgs.writeShellScript "shell-${name}" ''
        set -u
        if [ "$(dms ipc call lock isLocked 2>/dev/null)" = true ]; then
          echo "shell:${name}: session is locked — unlock first (killing the" >&2
          echo "active locker leaves niri's fail-secure screen)" >&2
          exit 1
        fi
        # the bracket keeps each pattern from matching a process that
        # merely QUOTES it (same trick as mpvpaper:toggle)
        pkill -f "[d]ms run" 2>/dev/null || true
        pkill "[n]octalia" 2>/dev/null || true
        pkill "[q]uickshell" 2>/dev/null || true
        sleep 1
        ${script}
      ''} "$out/bin/shell:${name}"
    '';
in
{
  home.packages = [
    pkgs.noctalia

    (mkShellSwitch "noctalia" ''
      # quickshell-family shells share a first-run race: on virgin
      # state the daemonized child can die mid-initialization, and the
      # second start — config now seeded — succeeds. Verify and retry
      # once rather than leaving a shell-less session.
      noctalia -d >/dev/null 2>&1
      for _ in 1 2 3 4; do
        sleep 1
        pgrep "[n]octalia" >/dev/null && break
      done
      if ! pgrep "[n]octalia" >/dev/null; then
        echo "noctalia: first start died (first-run init) — retrying" >&2
        noctalia -d >/dev/null 2>&1
      fi
      echo "shell: noctalia (Space binds dispatch to its launcher; shell:dms returns)"
    '')
    (mkShellSwitch "dms" ''
      setsid dms run >/dev/null 2>&1 </dev/null &
      echo "shell: DMS"
    '')
  ];
}
