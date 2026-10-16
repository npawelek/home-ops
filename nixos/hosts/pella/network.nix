{
  # Switch port: native VLAN Default (Talos 192.168.0.35, PXE), VLAN 30 tagged.
  # NixOS lives only on VLAN 30, static. Matched by MAC: PCI names shift with cards.
  networking.networkmanager.settings.main.no-auto-default = "*";

  networking.networkmanager.ensureProfiles.profiles = {
    # X540 port 0, untagged: link only, no address.
    x540-port0 = {
      connection = {
        id = "x540-port0";
        uuid = "80cc6474-6323-41d9-82a8-3458f8a10a6f";
        type = "ethernet";
        autoconnect = true;
      };
      ethernet.mac-address = "6C:92:BF:65:0B:66";
      ipv4.method = "disabled";
      ipv6.method = "disabled";
    };

    vlan30 = {
      connection = {
        id = "vlan30";
        uuid = "1ca491e1-48ce-486e-8ba2-45ab0fb7f7a9";
        type = "vlan";
        interface-name = "vlan30";
        autoconnect = true;
      };
      vlan = {
        id = 30;
        parent = "80cc6474-6323-41d9-82a8-3458f8a10a6f";
      };
      ipv4 = {
        method = "manual";
        address1 = "192.168.30.96/24,192.168.30.1";
        dns = "192.168.0.77;192.168.0.78;";
        ignore-auto-dns = true;
      };
      ipv6.method = "disabled";
    };
  };
}
