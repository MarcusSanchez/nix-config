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
#     rails) and is in-tree. Everything lands in hwmon for `sensors`
#     and the shell widgets; the case fans' curves live in the Lian Li
#     daemon (lianli.nix), not here.
#   - LACT: the GPU tuning daemon + GUI (power limits, clocks, fan
#     control). Its voltage-curve editor leans on undocumented driver
#     paths — the power-limit and PowerMizer knobs are the safe
#     everyday surface.
#   - Memory-clock floor: at desktop idle the driver parks the memory
#     clock at its lowest step, which cannot feed the desk's two
#     high-refresh panels — the display pipe starves and a band of
#     the frame drops out for a refresh, and so does every memory-clock
#     transition. The service below pins 7001 MHz, the lowest step
#     above deep idle (the supported steps are 405/810/7001/13801/
#     14001; a floor-to-max range still flickers on each jump);
#     GPU-heavy work on this OS runs at that bandwidth unless the
#     service is stopped for the job. LACT leaves it alone.
{ config, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;
  nvidiaSmi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";

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

  services.lact.enable = true;

  systemd.services.nvidia-memory-clock-floor = {
    description = "Hold the GPU memory clock above the deep-idle step";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    unitConfig.ConditionPathExists = "/dev/nvidiactl";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${nvidiaSmi} --lock-memory-clocks=7001,7001";
      ExecStop = "${nvidiaSmi} --reset-memory-clocks";
    };
  };
}
