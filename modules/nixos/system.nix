# Machine-level system settings and services: timezone/locale, fonts,
# and the devices you plug in or pair — their firmware and their power
# state. Several small concerns grouped by purpose; each would
# otherwise be a near-one-line file.
{ pkgs, ... }:

{
  # Timezone and locale, carried over from the installer's config.
  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # The zed and ghostty configs assume "JetBrainsMono Nerd Font (Mono)";
  # noto is the fallback base + emoji.
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services = {
    # CUPS
    printing.enable = true;

    # virtual filesystems for the file manager: trash, USB drives,
    # MTP phones, network shares (nautilus in home/marcus/nixos/apps.nix)
    gvfs.enable = true;

    # firmware updates (LVFS), and specifically the UEFI dbx revocation
    # database: the firmware's true-Setup-Mode reset (the only path to custom
    # Secure Boot keys on that board) wipes dbx, and fwupd is what
    # restores it — `fwupdmgr update` offers "UEFI dbx" as a device
    fwupd.enable = true;

    # DMS reads battery state through UPower — without it the bar's
    # battery widget silently hides — and drives the control center's
    # performance/balanced/saver switch through power-profiles-daemon.
    # Both fail QUIETLY if removed.
    upower.enable = true;
    power-profiles-daemon.enable = true;

    # Wooting keyboard: the maintained udev rules (hidraw via uaccess),
    # which is what lets the web Wootility configure the keyboard over
    # WebHID from a chromium browser. Deliberately NOT
    # hardware.wooting.enable — that option also installs the wootility
    # desktop app, which the web version replaces here. Inert without
    # the hardware plugged in.
    udev.packages = [ pkgs.wooting-udev-rules ];
  };
}
