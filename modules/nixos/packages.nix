# System packages for the bare-metal machines: the build essentials the
# mac gets from Xcode CLT and macOS itself (clang, make, bsdtar, curl),
# plus the desk-only tools. Everything shared across platforms lives in
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
    # shell-integration-features = ssh-terminfo in the shared ghostty base, home/marcus/common/dotfiles/ghostty.config.)
    ghostty.terminfo

    # libsecret's secret-tool probes the org.freedesktop.secrets
    # provider by hand: secret-tool store/lookup. watchman's
    # folly/fbthrift closure is ~87 MiB — a desk can afford it (the mac
    # gets its own from brew). ethtool reads and sets the NIC's own
    # hardware flags — `ethtool <iface>` is how you confirm the
    # Wake-on-LAN state a host's link file arms (`Wake-on: g` armed,
    # `d` disabled).
    ethtool
    libsecret
    watchman
    # lspci/lsusb — the first questions hardware diagnosis asks (which
    # chip is this, which driver bound); their absence was felt the day
    # a wedged bluetooth combo card needed identifying
    pciutils
    usbutils
  ];
}
