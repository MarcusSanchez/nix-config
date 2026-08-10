# Build essentials for the WSL boxes — what the mac gets from Xcode CLT
# and macOS itself (clang, make, bsdtar, curl). Everything shared across
# platforms lives in modules/common/packages.nix. Duplicated with
# modules/nixos/packages.nix on purpose: each directory is
# self-contained for its kind of machine.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gcc
    gnumake
    curl
    unzip
    gzip
    gnutar

    # Ghostty sets TERM=xterm-ghostty, so a session opened from the mac's
    # Ghostty needs that entry here or the line editor redraws wrong and
    # typing comes out duplicated. terminfo-only output — a few KB, not
    # the emulator. (The other half of this is
    # shell-integration-features = ssh-terminfo in the shared ghostty base, home/marcus/common/dotfiles/ghostty.config.)
    ghostty.terminfo
  ];
}
