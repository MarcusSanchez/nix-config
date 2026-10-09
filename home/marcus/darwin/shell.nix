# The zsh startup guard for GUI-launched terminals on the mac.
#
# nix-darwin's /etc/zshenv builds PATH once per process tree and marks
# it done with __NIX_DARWIN_SET_ENVIRONMENT_DONE, trusting the flag on
# every later shell. Launchers that snapshot a login shell's environment
# and hand it to the apps they open (Raycast does) pass the flag along
# while macOS resets the PATH beneath it — so a terminal opened from
# such a launcher starts a shell that skips the setup and finds none of
# the Nix tools. Dock- and launchd-started apps inherit a clean
# environment and are unaffected.
#
# ~/.zshenv is read after /etc/zshenv in every shell, so this is the
# earliest user-side point to notice the mismatch: the flag set but the
# system profile absent from PATH. Re-sourcing /etc/zshenv with both of
# its guards cleared rebuilds the environment exactly as a clean start
# would.
{ ... }:

{
  programs.zsh.envExtra = ''
    if [[ -n "''${__NIX_DARWIN_SET_ENVIRONMENT_DONE-}" && ":$PATH:" != *":/run/current-system/sw/bin:"* ]]; then
      unset __NIX_DARWIN_SET_ENVIRONMENT_DONE __ETC_ZSHENV_SOURCED
      source /etc/zshenv
    fi
  '';
}
