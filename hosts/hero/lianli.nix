# The case's Lian Li screen-and-fan stack, driven by lian-li-linux (an
# open replacement for the vendor's Windows-only L-Connect): the 8.8"
# Universal Screen (LCD + LED ring), the SL-INF Flex LCD fan trio on
# the wired controller, and the wireless family behind the RX dongle
# (two more fan groups and two Strimers). HOST-level: this machine's
# hardware.
#
# Split of responsibilities:
#   - the DAEMON (built here from the pinned source, daemon crate only
#     — the Tauri GUI is deliberately not built: no lockfile upstream,
#     and everything it does reaches the daemon through a scriptable
#     socket) runs fans, RGB and LCD streaming as a user service;
#   - the udev rules ship in the package output and grant uaccess (no
#     group membership needed, same pattern as security.nix's rules);
#     the lianli group only exists to keep udev's GROUP= reference
#     quiet;
#   - evdi is the desktop-mode trick: the daemon attaches the
#     Universal Screen as a REAL output (its EDID and all), so the
#     compositor treats it as a monitor — wallpapers/windows land on
#     it like any other screen. Module + auto-load below; the daemon
#     merely warns when it's absent.
#
# Control without the GUI: the daemon listens on
# $XDG_RUNTIME_DIR/lianli-daemon.sock speaking newline-delimited JSON
# ({"method": ..., "params": ...} — SetLcdMedia assigns image/video/
# sensor media to a screen by device id; ListDevices enumerates ids).
# Config persists in ~/.config/lianli/config.json, so assignments
# survive restarts; scripts can go through the socket or the file.
{ config, pkgs, ... }:

let
  evdi = config.boot.kernelPackages.evdi;

  lianli-daemon = pkgs.rustPlatform.buildRustPackage {
    pname = "lianli-daemon";
    version = "0-unstable-2026-08-26";

    src = pkgs.fetchFromGitHub {
      owner = "sgtaziz";
      repo = "lian-li-linux";
      rev = "22d12ca4f594672e444d721ed9412796d2f7b343";
      hash = "sha256-Kj16Q+YwqmtVN7g0WF+Hf7iuzcgIF0X7hVtdZNiSKdg=";
      fetchSubmodules = true;
    };

    cargoHash = "sha256-K4GOsGLleC/pNqKznK1kBq0/DpDrKMCohhVnQUD9pzE=";

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      nasm
      rustPlatform.bindgenHook
    ];

    buildInputs = with pkgs; [
      libusb1
      udev
      ffmpeg
      fontconfig
      glib
      evdi
    ];

    # the evdi crate links -levdi directly, no pkg-config lookup
    RUSTFLAGS = "-L ${evdi}/lib";

    # daemon only — the workspace's GUI crate would pull the whole
    # Tauri/webkit tree
    buildAndTestSubdir = "crates/lianli-daemon";

    postInstall = ''
      # the evdi-node access rule calls /bin/chmod, which the udev-rules
      # checker rejects — point it at the store's coreutils
      substituteInPlace packaging/udev/60-lianli.rules \
        --replace-fail "/bin/chmod" "${pkgs.coreutils}/bin/chmod"
      install -Dm644 packaging/udev/60-lianli.rules $out/lib/udev/rules.d/60-lianli.rules
    '';

    # the binary NEEDs soname libevdi.so.1, but the evdi package
    # installs only the unversioned .so — shim it and point the rpath
    # here (after fixup, so shrink-rpath cannot drop the entry)
    postFixup = ''
      ln -s ${evdi}/lib/libevdi.so $out/lib/libevdi.so.1
      patchelf --add-rpath $out/lib $out/bin/lianli-daemon
    '';
  };
in
{
  # desktop-mode virtual display for the Universal Screen
  boot.extraModulePackages = [ evdi ];
  boot.kernelModules = [ "evdi" ];

  # device access rules (60- sorts before 70-uaccess, which resolves
  # the uaccess tags); ffmpeg/ffprobe on PATH for video/GIF decode
  services.udev.packages = [ lianli-daemon ];
  users.groups.lianli = { };
  environment.systemPackages = [
    lianli-daemon
    pkgs.ffmpeg
  ];

  # per-user service, the upstream unit's shape: the session owns the
  # daemon (config in ~/.config/lianli, socket in $XDG_RUNTIME_DIR)
  systemd.user.services.lianli-daemon = {
    description = "Lian Li device daemon";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    path = [ pkgs.ffmpeg ];
    serviceConfig = {
      ExecStart = "${lianli-daemon}/bin/lianli-daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
