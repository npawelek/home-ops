# synology-nfs-tuning

Ensures the Synology NAS NFS server advertises a 1MB max block size (`rsize=1048576`) to NFS clients instead of the default 128KB. This allows Linux NFS clients to negotiate larger read/write transfer sizes, improving sustained throughput.

## What it does

1. Reads `/proc/fs/nfsd/max_block_size` — skips all changes if already set correctly
2. If wrong: stops `nfs-server`, mounts the nfsd procfs, writes the new value, restarts `nfs-server`
3. Installs a systemd unit (`nfsd-block-size.service`) that re-applies the setting before `nfs-server` starts on each boot

## Running manually

```bash
kubectl create job --from=cronjob/synology-nfs-tuning manualrun-$(date +%s) -n automation
```

## Scheduled runner

A weekly CronJob runs every Monday at 1am UTC via `kubernetes/apps/automation/synology-nfs-tuning/`.
