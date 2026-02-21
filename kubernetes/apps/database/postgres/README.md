# Postgres (Main)

Shared CNPG PostgreSQL cluster serving multiple apps. Backups go to Garage S3.

## Backups

Scheduled every 12h at 04:30 and 16:30 UTC (10:30 PM / 10:30 AM CST). WAL is archived continuously.
Retention: 14 days.

To trigger a manual backup:

```fish
echo 'apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: postgres-manual
spec:
  method: barmanObjectStore
  cluster:
    name: postgres' | kubectl apply -n database -f -
```

## Restore

To restore to a new cluster (e.g. for testing or disaster recovery), bootstrap from the object store:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-restore
spec:
  instances: 1
  imageName: ghcr.io/tensorchord/cloudnative-vectorchord:18.0-0.5.3@sha256:267f6cbb32af6e109e138a143c7e9dd5d44d68433ec2303f0c30e745c788d1a9

  bootstrap:
    recovery:
      source: postgres
      # Optionally target a point in time:
      # recoveryTarget:
      #   targetTime: "2026-02-21 03:00:00"

  externalClusters:
    - name: postgres
      barmanObjectStore:
        destinationPath: s3://<dest path>
        endpointURL: http://garage.storage.svc.cluster.local:3900
        s3Credentials:
          accessKeyId:
            name: credentials-backup-s3
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: credentials-backup-s3
            key: ACCESS_SECRET_KEY
          region:
            name: credentials-backup-s3
            key: REGION
        wal:
          maxParallel: 8

  storage:
    size: 30Gi
    storageClass: longhorn-6h
```

Apply it to the `database` namespace, verify data, then delete when done. The `credentials-backup-s3` secret must exist in the target namespace.
