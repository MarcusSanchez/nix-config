# Bootloader and the graphical boot experience. configurationLimit is
# sized for a 1 GB ESP: an early-KMS initrd (nvidia.nix) runs ~120 MB
# per generation, which is why the limit is 10. hosts/hero/lanzaboote.nix
# reads the same value for the signed loader.
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

  # The splash -> login-screen handoff lives in greeter.nix (greetd
  # quits plymouth itself; plymouth-quit is unhooked there). This
  # override backs it: any invocation of plymouth-quit retains the
  # last frame instead of clearing the framebuffer to black.
  systemd.services.plymouth-quit.serviceConfig.ExecStart =
    lib.mkForce "-${pkgs.plymouth}/bin/plymouth quit --retain-splash";

  # Independent of the splash machinery above. Compressed swap in RAM:
  # no disk swap exists on these machines, and RAM at this size makes
  # zram effectively free headroom that keeps the OOM killer away from
  # a browser+IDE workload. Default memoryPercent (50) is fine. No disk
  # swap also means hibernation stays impossible — accepted.
  zramSwap.enable = true;
}
