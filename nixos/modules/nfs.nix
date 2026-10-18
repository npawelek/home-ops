{ config, ... }:
{
  # NAS shares via autofs, not fileSystems: fileSystems would put the server name in
  # /etc/fstab and the world-readable store. The autofs map is rendered by sops-nix into
  # /run/secrets/rendered at activation, so the name only exists there (root, 0400).
  boot.supportedFilesystems = [ "nfs" ];

  # NAS hostname, same value as RACKNAS_ADDR in the cluster secrets.
  sops.secrets.racknas-addr = { };

  # Export paths are not secret (see kubernetes/apps/storage/nfs-volumes); only the server is.
  # Options match the cluster PVs (racknas-downloads.yaml) plus soft: a NAS outage returns
  # I/O errors instead of hanging every process that touches it.
  sops.templates."auto.racknas" = {
    content = ''
      media -fstype=nfs,nfsvers=4.1,rw,soft,nconnect=4,rsize=1048576,wsize=1048576,noatime,nodiratime,timeo=30,retrans=3 ${config.sops.placeholder.racknas-addr}:/volume1/media
    '';
    restartUnits = [ "autofs.service" ];
  };

  # Mounted on first access under /mnt/racknas/<key>, unmounted after 10 idle minutes.
  services.autofs = {
    enable = true;
    autoMaster = ''
      /mnt/racknas file:${config.sops.templates."auto.racknas".path} --timeout=600
    '';
  };
}
