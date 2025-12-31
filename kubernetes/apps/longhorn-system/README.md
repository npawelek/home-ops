# Longhorn

## Talos Prerequisites

Schematics will include the necessary extensions required for using Longhorn with Talos.
As of 1.10.1, this included:

```
iscsi-tools (required)
nfs-utils
nvme-cli
util-linux-tools (required)
```

### Longhorn-specific Machine Configs

You need to create and apply the necessary machine configs to each node as
they are not homogenous. Refer to `talos/patches/nodes` to apply
`UserVolumeConfig` for the associated disk that Longhorn will be using on that
associated worker node. There is a generic worker configuration in
`talos/patches/worker` that will mount the proper disk to `/var/mnt/longhorn`.

You can verify with the following:

```
# Define the variables
set NODE <name>
set XX <lastOctetofIPAddr>

# Apply and verify the configuration
task talos:generate-config
yq '.machine.kubelet' talos/clusterconfig/kubernetes-$NODE.yaml
# Reboot may be required
task talos:apply-node IP=192.168.0.$XX
talosctl -n 192.168.0.$XX get mounts | grep longhorn
talosctl -n 192.168.0.$XX read /proc/mounts | grep longhorn

# Unset variables (if you need to label, leave in-place until labeling below)
set -e NODE XX
```

## Node Labeling

To label the node after it comes up, you can run the following:

```
set NODE <name>
k label $NODE node.longhorn.io/create-default-disk=true
set -e NODE XX
```

## Reclaiming a `Released` volume

Released volumes by default won't allow attaching to the existing PV. In order to resolve this, you can delete the PVC and patch the PV to ensure it's `Available`.

```
k delete pvc -n <ns> <pvc-name>
k patch pv <pvc-id> -p '{"spec":{"claimRef": null}}'
```

## Restoring a volume from Longhorn backup

1. Validate backups exist for the associated volume
2. Scale down the workload
3. Ensure enough nodes are available for the number of replicas needed. The volume will fail restore otherwise
4. Delete the associated PVC and PV within the Kubernetes
5. Delete the volume in Longhorn
6. Navigate to backups and select the volume being restored
7. Choose a snapshot date and select restore from the drop-down, using original PV and PVC names
8. Wait for the new volume to populate and detach
9. Scale up the workload and validate restore was successful
10. Rinse and repeat if a different restore date is required
