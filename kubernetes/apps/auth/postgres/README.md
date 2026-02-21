# Postgres (Authentik)

Dedicated CNPG PostgreSQL cluster for Authentik. Backups go to Garage S3.

## Backups

Scheduled every 12h at 03:30 and 15:30 UTC (9:30 PM / 9:30 AM CST). WAL is archived continuously.
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
    name: authentik-postgres' | kubectl apply -n auth -f -
```

## Restore

To restore to a new cluster (e.g. for testing or disaster recovery), bootstrap from the object store:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: authentik-postgres-restore
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:18.1@sha256:cc78f0c280978dd93fa6f49ce6cef60015cf4b56fd0e6a47c8ca49020b875f74

  bootstrap:
    recovery:
      source: authentik-postgres
      # Optionally target a point in time:
      # recoveryTarget:
      #   targetTime: "2026-02-21 03:00:00"

  externalClusters:
    - name: authentik-postgres
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
    size: 10Gi
    storageClass: longhorn
```

Apply it to the `auth` namespace, verify data, then delete when done. The `credentials-backup-s3` secret must exist in the target namespace.
