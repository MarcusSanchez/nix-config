# Compressed swap in RAM: no disk swap exists on this machine, and 30 GiB
# of RAM makes zram effectively free headroom that keeps the OOM killer
# away from a browser+IDE workload. Default memoryPercent (50) is fine.
# Note: no disk swap also means hibernation stays impossible — accepted.
{ ... }:

{
  zramSwap.enable = true;
}
