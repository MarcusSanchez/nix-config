# Bootloader and the graphical boot experience. The ESP is only 1 GB,
# so cap retained generations — each one's kernel+initrd runs ~200 MB
# with the nvidia modules and firmware included (see nvidia.nix for the
# early-KMS initrd).
{ lib, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
      # Skip the generation menu (it default-selects the newest after
      # 5 s anyway). Rollbacks stay reachable: hold Space during
      # power-on to bring the menu up.
      timeout = 0;
    };

    # Splash on boot/shutdown instead of console text: bgrt draws a
    # spinner under the firmware's vendor logo, Windows-style. Esc during
    # boot shows the log.
    plymouth.enable = true;

    # Silence the kernel and systemd chatter the splash would otherwise
    # flash through. The non-rd. systemd.show_status matters beyond
    # boot: without it, logout flashes green [ OK ] unit messages on
    # the VT during the session -> greeter handoff. plymouth's module
    # adds splash/loglevel=0 itself; boot.shell_on_fail keeps a
    # recovery shell reachable if the initrd ever breaks.
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "boot.shell_on_fail"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "systemd.show_status=false"
      # no blinking console cursor in the brief VT gaps between
      # compositor handoffs
      "vt.global_cursor_default=0"
    ];
  };

  # Bridge the splash -> login-screen gap. The HANDOFF itself lives in
  # greeter.nix: plymouth-quit/-quit-wait are unhooked from the boot
  # transaction there, and greetd's last pre-start fires the quit — so
  # the spinner animates until the greeter is imminent instead of
  # systemd cutting it loose seconds earlier. This override is the
  # belt behind that: anything that ever does invoke plymouth-quit
  # (manual start, a future DM that pulls it back in) retains the last
  # frame instead of clearing to black.
  systemd.services.plymouth-quit.serviceConfig.ExecStart =
    lib.mkForce "-${pkgs.plymouth}/bin/plymouth quit --retain-splash";

  # Independent of the splash machinery above. Compressed swap in RAM:
  # no disk swap exists on these machines, and RAM at this size makes
  # zram effectively free headroom that keeps the OOM killer away from
  # a browser+IDE workload. Default memoryPercent (50) is fine. No disk
  # swap also means hibernation stays impossible — accepted.
  zramSwap.enable = true;
}
