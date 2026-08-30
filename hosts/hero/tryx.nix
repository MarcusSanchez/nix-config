# The AIO's curved AMOLED (Tryx Panorama — the cooler's screen), driven
# by the community Qt manager: the vendor software is Windows-only. The
# display enumerates as a USB printer-class device (that is its real
# transfer pipe) and, unserviced, resets itself every ~70 seconds — the
# runtime holding it open is what keeps it awake. HOST-level: this
# machine's hardware.
#
# Two binaries from one pinned build: tryx-panorama-runtime (headless
# D-Bus service org.tryx.Panorama, owns the device — the user service
# below) and tryx-panorama-manager (the GUI, talks to the runtime; in
# the spotlight via its desktop entry). Media upload, presets and
# sensor overlays all go through the GUI or the D-Bus API; state lives
# under ~/.config. ffmpeg rides the service PATH for video conversion.
#
# The upstream install step writes to /usr and into other packages'
# store paths, so the package installs the built artifacts by hand; the
# udev rules grant uaccess on the device and keep systemd from treating
# it as a printer.
{ pkgs, ... }:

let
  tryx = pkgs.qt6Packages.callPackage (
    {
      stdenv,
      fetchFromGitHub,
      qmake,
      qtbase,
      qtdeclarative,
      wrapQtAppsHook,
      pkg-config,
      protobuf,
      libusb1,
      systemd,
    }:
    stdenv.mkDerivation {
      pname = "tryx-panorama-manager";
      version = "2.2.0";

      src = fetchFromGitHub {
        owner = "DXVSI";
        repo = "tryx-panorama-se-360-linux-gui";
        rev = "v2.2.0";
        hash = "sha256-nFnkKEUG0NR0zH5R2ZnwkEMD7PrFcM8GMvuIO9CWCE4=";
      };

      nativeBuildInputs = [
        qmake
        wrapQtAppsHook
        pkg-config
        protobuf
      ];

      buildInputs = [
        qtbase
        qtdeclarative
        protobuf
        libusb1
        systemd
      ];

      # the lrelease qmake feature hardcodes a tool path inside qtbase
      # that doesn't exist in the split Qt packaging; drop the
      # translation build (the only catalog is a Russian locale)
      postPatch = ''
        sed -i 's/ lrelease embed_translations//' \
          tryx-panorama.pro tryx-panorama-quick.pro
      '';

      qmakeFlags = [ "tryx-panorama-all.pro" ];

      # the project's install target writes to /usr and into other
      # packages' store paths; take the built artifacts directly
      installPhase = ''
        runHook preInstall
        install -Dm755 build/quick/tryx-panorama-manager $out/bin/tryx-panorama-manager
        install -Dm755 build/runtime/tryx-panorama-runtime $out/bin/tryx-panorama-runtime
        install -Dm644 packaging/70-tryx-pase-access.rules $out/lib/udev/rules.d/70-tryx-pase-access.rules
        install -Dm644 packaging/99-tryx-pase-printer.rules $out/lib/udev/rules.d/99-tryx-pase-printer.rules
        install -Dm644 packaging/tryx-panorama-manager.desktop $out/share/applications/tryx-panorama-manager.desktop
        runHook postInstall
      '';
    }
  ) { };
in
{
  services.udev.packages = [ tryx ];
  environment.systemPackages = [ tryx ];

  # the upstream unit's shape: D-Bus-activated identity, and stop
  # timeouts that defer to an in-flight firmware write
  systemd.user.services.tryx-panorama = {
    description = "Tryx Panorama display runtime";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    path = [ pkgs.ffmpeg ];
    serviceConfig = {
      Type = "dbus";
      BusName = "org.tryx.Panorama";
      ExecStart = "${tryx}/bin/tryx-panorama-runtime";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStartSec = 15;
      KillMode = "mixed";
      TimeoutStopSec = "infinity";
    };
  };
}
