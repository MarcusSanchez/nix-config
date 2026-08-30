# The onboard MediaTek MT7927 (MT6639) combo card's bluetooth half.
# Kernels before 7.1 don't know the chip: btusb binds it by device
# class only, never runs the MediaTek init that uploads firmware, and
# the first HCI command dies with EBUSY — so this builds the
# upstream-backport btusb/btmtk from the mediatek-mt7927-dkms release
# artifact (which ships the kernel-7.1 bluetooth sources with its
# compat patches pre-applied AND the BT_RAM_CODE_MT6639 firmware,
# which linux-firmware does not carry — only the chip's WIFI blobs
# are upstream). The modules land in updates/, which depmod prefers
# over the in-tree pair, so modprobe resolves ours without blacklists.
#
# HOST-level like nvidia.nix: chip-specific hardware truth. The
# module build self-retires when nixpkgs reaches kernel 7.1 (native
# support — the same gate the dkms package applies); the firmware
# stays declared until linux-firmware ships the BT blob, then this
# whole file can go.
#
# The wifi half is deliberately NOT built (this desk is wired); it
# would need the package's patched mt76 tree as well.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  version = "2.14-6";
  deb = pkgs.fetchurl {
    url = "https://github.com/jetm/mediatek-mt7927-dkms/releases/download/v${version}/mediatek-mt7927-dkms_${version}_all.deb";
    hash = "sha256-1WUpQ/AZd/rpQ9zUSVP63XLfWF9RXI9Fu0hVCHYY2YA=";
  };

  # the deb, unpacked verbatim: usr/src/... carries the patched
  # bluetooth sources, usr/lib/firmware/... the BT firmware
  unpacked =
    pkgs.runCommand "mediatek-mt7927-dkms-unpacked"
      {
        nativeBuildInputs = [
          pkgs.libarchive
          pkgs.zstd
        ];
      }
      ''
        mkdir -p $out
        bsdtar -xOf ${deb} data.tar.zst | bsdtar --zstd -xf - -C $out
      '';

  kernel = config.boot.kernelPackages.kernel;

  btModules = pkgs.stdenv.mkDerivation {
    pname = "mt7927-bt-modules";
    inherit version;
    dontUnpack = true;
    nativeBuildInputs = kernel.moduleBuildDependencies;
    buildPhase = ''
      runHook preBuild
      cp -r ${unpacked}/usr/src/mediatek-mt7927-*/drivers/bluetooth ./bluetooth
      chmod -R u+w ./bluetooth
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD/bluetooth modules
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm444 -t $out/lib/modules/${kernel.modDirVersion}/updates \
        bluetooth/btusb.ko bluetooth/btmtk.ko
      runHook postInstall
    '';
  };

  btFirmware = pkgs.runCommand "mt7927-bt-firmware" { } ''
    install -Dm444 \
      ${unpacked}/usr/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin \
      $out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin
  '';
in
{
  boot.extraModulePackages = lib.mkIf (lib.versionOlder kernel.version "7.1") [ btModules ];
  hardware.firmware = [ btFirmware ];
}
