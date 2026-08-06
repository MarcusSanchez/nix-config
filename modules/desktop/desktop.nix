# The desktop session: niri (scrollable-tiling Wayland compositor)
# with DankMaterialShell, entered through DMS's own greetd greeter —
# plus the services a machine you sit in front of needs (audio,
# network, bluetooth, printing). Plasma 6 and GNOME were trialed here
# and removed once niri + DMS stuck; git history has both working.
{ pkgs, ... }:

let
  # niri, with its session Exec routed through systemd-cat: greetd
  # starts sessions with stdio inherited from the VT, so niri's and
  # quickshell's startup/shutdown output otherwise flashes as raw text
  # during every login/logout handoff. journalctl -t niri-session reads
  # it back. symlinkJoin only rewrites the .desktop — no niri rebuild.
  niriQuiet = pkgs.symlinkJoin {
    name = "niri-quiet";
    paths = [ pkgs.niri ];
    postBuild = ''
      rm $out/share/wayland-sessions/niri.desktop
      {
        echo "[Desktop Entry]"
        echo "Name=niri"
        echo "Comment=A scrollable-tiling Wayland compositor (session logs to the journal)"
        echo "Exec=${pkgs.systemd}/bin/systemd-cat --identifier=niri-session $out/bin/niri-session"
        echo "Type=Application"
        echo "DesktopNames=niri"
      } > $out/share/wayland-sessions/niri.desktop
    '';
    passthru.providedSessions = [ "niri" ];
  };
in
{
  # The compositor + GNOME/GTK portals; user-side pieces (DMS shell,
  # niri config) live in home/marcus/desktop/niri.nix. The module also
  # enables gnome-keyring, which provides org.freedesktop.secrets —
  # secretspec's keyring provider and libsecret's secret-tool talk to
  # it.
  programs.niri = {
    enable = true;
    package = niriQuiet;
  };

  # backs HM's dconf.settings and gsettings for GTK apps (arrived with
  # GNOME before, left with it)
  programs.dconf.enable = true;

  services = {
    displayManager = {
      # DMS's greetd-based greeter — the login screen wears the same
      # Material theme as the session shell. configHome points it at
      # the user's DMS settings so wallpaper/colors stay in sync; package
      # pinned to the same nixpkgs dms-shell the session uses so
      # greeter and shell can't drift apart.
      dms-greeter = {
        enable = true;
        compositor.name = "niri";
        configHome = "/home/marcus";
        package = pkgs.dms-shell;
        # without this the greeter's niri/quickshell startup output
        # goes to the VT — a flash of yellow WARN lines on every
        # logout/login
        logs.save = true;
      };

      # No auto-login: boot lands on the greeter. The boot-lock loop in
      # niri.config.kdl keys on session id 1, which the greeter session
      # occupies in this mode — so it stays dormant and a greeter login
      # enters the desktop unlocked. Flipping autoLogin back on
      # restores the boot-to-lock flow with no other changes needed.
      defaultSession = "niri";
    };

    # DMS persists the profile picture through AccountsService; without
    # the daemon, `dms ipc call profile setImage` claims SUCCESS but
    # only sets session memory and the avatar vanishes on reboot.
    accounts-daemon.enable = true;

    # firmware updates (LVFS), and specifically the UEFI dbx revocation
    # database: MSI's true-Setup-Mode reset (the only path to custom
    # Secure Boot keys on that board) wipes dbx, and fwupd is what
    # restores it — `fwupdmgr update` offers "UEFI dbx" as a device
    fwupd.enable = true;

    # DMS reads battery state through UPower — without it the bar's
    # battery widget silently hides — and drives the control center's
    # performance/balanced/saver switch through power-profiles-daemon.
    # Both came with GNOME/Plasma and left with them.
    upower.enable = true;
    power-profiles-daemon.enable = true;

    # PipeWire, with PulseAudio emulation for the apps that expect it.
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # Follow the content's sample rate instead of resampling all to
      # 48k: with a menu of allowed rates, PipeWire re-clocks the DAC
      # (Fosi K7: 24-bit/192k capable) to match the playing stream —
      # 44.1k sources play at 44.1k, hi-res at 96k/192k. Bit depth
      # needs no config: mixing is float32 internally and the DAC
      # negotiates its best format (S24) on its own.
      extraConfig.pipewire."10-clock-rates" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [
            44100
            48000
            88200
            96000
            176400
            192000
          ];
        };
      };
    };

    printing.enable = true;

    # FIDO2/U2F hardware security keys: the udev rules give the browser
    # access to the hidraw device, which is what makes WebAuthn passkeys
    # work (phone-as-passkey via the QR/bluetooth flow needs nothing
    # beyond bluetooth, which is on)
    udev.packages = [ pkgs.libfido2 ];
  };

  # The greeter runs niri with its OWN generated config — the session's
  # niri.config.kdl reaches only the session — so unaided it drives every monitor
  # untransformed at scale 1: sideways on a vertical monitor, tiny on
  # the 4K (bedroom-nixos's first greeter did exactly that). The DMS
  # launcher appends `include "/etc/greetd/niri_overrides.kdl"` to its
  # generated config when that file exists; hand it the same
  # connector-keyed output layout the session includes. Store copy —
  # updates on rebuild, not on save like the session's symlink.
  environment.etc."greetd/niri_overrides.kdl".source =
    ../../home/marcus/common/dotfiles/niri.outputs.kdl;

  # The greeter's avatar probe checks, in order: its own cache,
  # /var/lib/AccountsService/icons/<user>, then ~/.face — but the
  # dms-greeter user cannot read ~/.face through the 0700 home dir, and
  # AccountsService only gets an icons/ copy when the avatar is set
  # imperatively through the UI. Seed that copy declaratively from the
  # same asset home/marcus/desktop/appearance.nix links to ~/.face, so
  # a fresh machine's login screen has the face too. C+ overwrites, so
  # an asset change propagates at the next boot/activation instead of
  # being blocked by the existing copy.
  systemd.tmpfiles.rules = [
    "C+ /var/lib/AccountsService/icons/marcus 0644 root root - ${../../home/marcus/desktop/assets/avatar-spaceman.png}"
  ];

  security = {
    # swaylock is the fallback locker (DMS's is primary); it
    # authenticates via PAM, and without this entry unlocking fails
    pam.services.swaylock = { };
    rtkit.enable = true;
  };

  networking = {
    networkmanager.enable = true;
    # LAN-open ports: only servers another device plausibly connects
    # to — localhost traffic never touches the firewall, so a dev
    # server used purely from this machine's own browser needs nothing
    # here. Databases and other internals stay closed; for anything
    # not listed, the tailnet path (tailscale.nix trusts tailscale0)
    # reaches every port from enrolled devices with no LAN exposure.
    firewall = {
      allowedTCPPorts = [
        # localsend discovers and transfers here
        53317
        # Metro (Expo/React Native dev server) — phone-on-LAN loads the
        # app from here. WSL never needed this: its traffic enters
        # through Windows' network stack, not the NixOS firewall.
        8081
        # the front-end dev-server canon, for phone-testing on the LAN:
        # Next.js/CRA/Express habit, Vite, Django/`python -m http.server`,
        # and the generic-8080 crowd (Spring, proxies, tools)
        3000
        5173
        8000
        8080
      ];
      # croc's LAN-local mode: same-network transfers go direct instead
      # of silently falling back to the public relay (relay mode is
      # outbound-only and needs nothing here)
      allowedTCPPortRanges = [
        {
          from = 9009;
          to = 9013;
        }
      ];
      allowedUDPPorts = [
        # localsend's discovery side
        53317
        # croc LAN peer discovery
        9009
      ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # /dev/uinput + the uinput group, for xremap's synthetic input
  hardware.uinput.enable = true;

  # Desktop-only group memberships, layered onto the base user from
  # modules/nixos/users.nix (extraGroups lists merge): NetworkManager
  # control without polkit prompts, and evdev read + uinput write for
  # xremap (home/marcus/desktop/niri.nix).
  users.users.marcus.extraGroups = [
    "networkmanager"
    "input"
    "uinput"
  ];

  # libsecret's secret-tool probes the org.freedesktop.secrets provider
  # by hand: secret-tool store/lookup. watchman is desktop-only on Linux:
  # its folly/fbthrift closure is ~87 MiB, which the WSL boxes shouldn't
  # carry (the mac gets its own from brew).
  environment.systemPackages = [
    pkgs.libsecret
    pkgs.watchman
  ];
}
