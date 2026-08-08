# Arms the onboard NIC to wake this machine on a magic packet.
#
# Wake-on-LAN is not a persistent property of the card: the running
# driver switches the listener on, and the shutdown path is what leaves
# it armed. So whichever OS powered the machine down decides whether a
# packet gets through. Windows arms it as a side effect of its own
# shutdown (magic-packet wake is on by default in its driver, and Fast
# Startup's hybrid hibernate preserves that state), which is why WoL
# worked for free while Windows was the default boot entry. Linux
# leaves ethtool's wol flag at `d`, so making NixOS the default meant
# nothing armed the chip any more and the packets were ignored.
#
# A .link file is the mechanism rather than an ethtool service because
# udev honors .link units whether or not systemd-networkd is running
# (nixpkgs says so at the generation site) — NetworkManager owns this
# interface, and its own wake-on-lan default of `ignore` leaves the
# setting alone.
#
# Matched on MAC rather than interface name: the address is this
# machine's hardware truth and can't be renamed out from under the
# match the way a predictable interface name can.
{
  systemd.network.links."40-wol" = {
    matchConfig.MACAddress = "d8:43:ae:fa:bb:31";
    linkConfig.WakeOnLan = "magic";
  };
}
