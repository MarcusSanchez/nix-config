# Linux-only packages: build essentials the mac gets from Xcode CLT and
# macOS itself (clang, make, bsdtar, curl). Everything shared lives in
# modules/common/packages.nix.
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
    # shell-integration-features = ssh-terminfo in home/marcus/mac/ghostty.nix.)
    ghostty.terminfo
  ];
}
