# Thermals and GPU tuning for this desk's silicon. HOST-level: the
# sensor modules are board-specific, the tuning daemon GPU-specific.
#
#   - asus_ec_sensors reads the board's EC (chipset/VRM temps, the
#     water-flow and T_Sensor headers, extra fan RPMs) — but this
#     board postdates the in-tree driver's DMI table, so the pinned
#     out-of-tree build below lands in updates/ (which depmod prefers)
#     until a kernel that knows the board arrives; drop the package
#     when `modinfo asus_ec_sensors` grows this board's alias.
#     nct6775 reads the Nuvoton super-I/O (fan headers and voltage
#     rails) and is in-tree. Everything lands in hwmon for `sensors`,
#     DMS widgets and CoolerControl alike.
#   - CoolerControl: fan curves driven off any hwmon sensor, with a
#     GUI (in the spotlight); its daemon applies curves headlessly
#     from then on, and finds the GPU's fans through the driver on
#     its own.
#   - LACT: the GPU tuning daemon + GUI (power limits, clocks, fan
#     control). Its voltage-curve editor leans on undocumented driver
#     paths — the power-limit and PowerMizer knobs are the safe
#     everyday surface.
{ config, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  asus-ec-sensors = pkgs.stdenv.mkDerivation {
    pname = "asus-ec-sensors";
    version = "0-unstable-2026-08-24";
    src = pkgs.fetchFromGitHub {
      owner = "zeule";
      repo = "asus-ec-sensors";
      rev = "5d1487d310721180541e0fe8de0f50627db489b6";
      hash = "sha256-bxzGZ2k1pr2mqd8IAVkQKJAO0BSke4FDqjMA6OnW6eM=";
    };
    nativeBuildInputs = kernel.moduleBuildDependencies;
    makeFlags = [
      "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}"
    ];
    installPhase = ''
      runHook preInstall
      install -Dm444 asus-ec-sensors.ko \
        $out/lib/modules/${kernel.modDirVersion}/updates/asus-ec-sensors.ko
      runHook postInstall
    '';
  };
in
{
  boot.extraModulePackages = [ asus-ec-sensors ];
  boot.kernelModules = [
    "nct6775"
    "asus_ec_sensors"
  ];

  # the `sensors` CLI over the hwmon nodes the modules above populate
  environment.systemPackages = [ pkgs.lm_sensors ];

  programs.coolercontrol.enable = true;

  services.lact.enable = true;
}
