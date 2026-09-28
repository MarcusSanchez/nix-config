# The Ryoku desktop's home half (system half: hosts/hero/ryoku.nix,
# where the whole story lives). Ryoku owns the session — shell,
# wallpaper, theming, locker, and niri's one config entrypoint
# (~/.config/niri/config.kdl, laid and maintained by its materializer;
# per-user overrides go in ~/.config/niri/user.kdl, machine-owned).
# What lives here is only what Ryoku doesn't bring:
#
#   - xremap, the per-app remapper (alt-hjkl -> arrows outside vim-y
#     apps), as a session-bound user service — the same shape the DMS
#     world uses (home/marcus/nixos/niri.nix), duplicated on purpose.
#   - tpm-fido, which the DMS world spawns from its niri config; Ryoku's
#     config is not ours to edit, so here it is a user service instead.
#   - the swaylock fallback (PAM entry in modules/nixos/niri.nix) for
#     when qylock misbehaves.
#   - force on btop.conf: Ryoku's materializer replaces it (a replaced
#     link is the "would be clobbered" activation failure), and HM
#     stomps it back each switch. ghostty and nvim are safe by Ryoku's
#     own seed logic; gtk theming is Ryoku's here (no HM gtk module in
#     this world).
{
  config,
  pkgs,
  ...
}:

let
  # niri variant: tracks the focused window over niri IPC to gate the
  # per-app remaps
  xremapNiri = pkgs.xremap.override { withVariant = "niri"; };
in
{
  xdg.configFile."btop/btop.conf".force = true;

  home.packages = [
    # on PATH for hand-runs; the SESSION copy is the service below
    xremapNiri

    # TPM-backed virtual FIDO2 key (system plumbing in
    # modules/nixos/security.nix). It shells out to a bare `pinentry`
    # for the touch-confirmation prompt — the alias points that name at
    # the gnome3 flavor, which prompts via gcr.
    pkgs.tpm-fido
    (pkgs.runCommand "pinentry-alias" { } ''
      mkdir -p $out/bin
      ln -s ${pkgs.pinentry-gnome3}/bin/pinentry-gnome3 $out/bin/pinentry
    '')
  ];

  # xremap as a session-bound user service, NOT a compositor spawn —
  # spawn children outlive the session and a stale xremap keeps its
  # exclusive evdev grab past logout (dead keyboard at next login).
  # PartOf graphical-session.target releases the grab exactly when the
  # session ends. The wrapper reads the CURRENT manager environment at
  # exec because a user service otherwise snapshots it at spawn, and
  # losing the race against niri's NIRI_SOCKET import leaves xremap
  # blind: per-app `not:` matchers pass vacuously and the remaps
  # capture inside neovim/Zed/JetBrains.
  systemd.user.services.xremap = {
    Unit = {
      Description = "Per-application key remapping (niri variant)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = toString (
        pkgs.writeShellScript "xremap-with-niri-socket" ''
          for _ in $(seq 1 30); do
            sock=$(systemctl --user show-environment | ${pkgs.gnused}/bin/sed -n 's/^NIRI_SOCKET=//p')
            [ -n "$sock" ] && [ -S "$sock" ] && break
            sleep 0.5
          done
          if [ -n "''${sock:-}" ] && [ -S "$sock" ]; then
            export NIRI_SOCKET="$sock"
          else
            echo "xremap: NIRI_SOCKET never appeared — running without focused-window tracking" >&2
          fi
          exec ${xremapNiri}/bin/xremap --watch=config,device ${config.home.homeDirectory}/nix-config/home/marcus/common/dotfiles/xremap.yml
        ''
      );
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # The DMS world spawns this from niri.config.kdl; Ryoku's session
  # needs it running the same way for the FIDO2 key to answer.
  systemd.user.services.tpm-fido = {
    Unit = {
      Description = "TPM-backed virtual FIDO2 token";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.tpm-fido}/bin/tpm-fido";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # fallback lock (PAM entry in modules/nixos/niri.nix) in case qylock
  # ever misbehaves — run `swaylock` from a terminal
  programs.swaylock.enable = true;
}
