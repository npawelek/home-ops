{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = false;
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = "npawelek";
  };

  networking.nftables.enable = true;
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.20.49 tcp dport { 47984, 47989, 48010 } accept
    ip saddr 192.168.20.49 udp dport { 47998-48000, 48002, 48010 } accept
  '';
}
