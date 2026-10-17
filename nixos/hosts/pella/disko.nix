let
  # Pin by serial from `ls -l /dev/disk/by-id/`. Never /dev/nvmeXn1: enumeration
  # order is not stable, and the other disks belong to Talos.
  device = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7KHNU0X718422J";
in
{
  disko.devices.disk.nixos = {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        # Reinstall keeps @home and @games: recreate only @root (see README).
        # btrfs mount options are filesystem-wide, so all subvolumes share them.
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = [ "compress=zstd:1" "noatime" ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd:1" "noatime" ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd:1" "noatime" ];
              };
              # Steam library + Lutris prefixes; outside @home so home snapshots stay small.
              "@games" = {
                mountpoint = "/games";
                mountOptions = [ "compress=zstd:1" "noatime" ];
              };
            };
          };
        };
      };
    };
  };
}
