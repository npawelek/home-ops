{ config, ... }:
{
  # sops-nix: decrypts secrets/<hostname>.sops.yaml at activation into /run/secrets*.
  # Recipients (.sops.yaml): nixos-admin + this host, post-quantum age keys only.
  sops.defaultSopsFile = ../secrets/${config.networking.hostName}.sops.yaml;

  # Host age identity (age-keygen -pq). Lives in @nix, which a reinstall keeps, so it is
  # copied in once per disk (see README). No SSH-derived key: ssh-to-age is classical
  # X25519 and would weaken every file it is a recipient of.
  sops.age.keyFile = "/nix/persist/sops-nix/key.txt";
  sops.age.sshKeyPaths = [ ];
  sops.age.generateKey = false;
  sops.gnupg.sshKeyPaths = [ ];

  # yescrypt hash (mkpasswd -m yescrypt). Decrypted before users are created.
  sops.secrets.npawelek-password.neededForUsers = true;

  # Users and passwords come only from this config; `passwd` changes do not persist.
  # If decryption fails the password is unset, but SSH (keys.nix) still logs in.
  users.mutableUsers = false;
  users.users.npawelek.hashedPasswordFile = config.sops.secrets.npawelek-password.path;
}
