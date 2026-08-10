# PipeWire, with PulseAudio emulation for the apps that expect it.
# rtkit lives here because its job is real-time scheduling priority for
# the audio graph.
{ ... }:

{
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # Follow the content's sample rate instead of resampling all to
    # 48k. The list is a MENU, not a demand: PipeWire intersects it
    # with each device's own capabilities, so this is safe flavor-wide
    # — a laptop codec that only does 44.1/48 picks between those,
    # while a hi-res DAC (the desk's Fosi K7 does 24-bit/192k) gets
    # the full range. Bit depth needs no config: mixing is float32
    # internally and each device negotiates its best format itself.
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

  security.rtkit.enable = true;
}
