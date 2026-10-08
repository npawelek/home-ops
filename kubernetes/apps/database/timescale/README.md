# TimescaleDB

Dedicated CNPG cluster running PostgreSQL 18 with TimescaleDB (Timescale License edition) and
`timescaledb_toolkit`. Tenant: Tracearr (`media/tracearr`). Kept separate from the shared
`postgres` cluster so TimescaleDB's preload library, image and upgrade cadence don't touch other apps.

- Image: `timescale/timescaledb-ha` via `ImageCatalog/timescale` (`major: 18`). The tag format
  `pg18.6-ts2.30.2` isn't CNPG-parseable, so the catalog declares the major. The image runs
  postgres as UID/GID 1000, hence `postgresUID`/`postgresGID` on the Cluster.
- Service: `timescale-rw.database.svc.cluster.local:5432` only (`ro`/`r` disabled). TLS required
  (`hostssl`); clients without the cluster CA use `sslmode=no-verify`.
- No superuser password and no LoadBalancer. Admin access is peer auth through `kubectl exec`.

Status: `task cnpg:status-timescale`. Promote: `task cnpg:promote-timescale NODE=timescale-N`.

## Backups

Barman Cloud plugin to RustFS bucket `cnpg-database-timescale` (`ObjectStore/timescale-backup`,
credentials `credentials-timescale-backup-s3`, created by `terraform/rustfs/cnpg-database-timescale.tf`).

- WAL archived continuously (`ContinuousArchiving` condition).
- Base backups at 05:30 and 17:30 UTC (`ScheduledBackup/timescale`, `0 30 5/12 * * *`).
- Retention: 21 days.

Tracearr also writes its own zip backups (Settings → Backup) to the `tracearr-data` PVC, which
Longhorn backs up daily.

Manual base backup:

```sh
cat <<'EOF' | mise x -- kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: timescale-manual
  namespace: database
spec:
  cluster:
    name: timescale
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
    parameters:
      barmanObjectName: timescale-backup
EOF
mise x -- kubectl -n database get backup timescale-manual -w   # phase: completed
```

## Restore

Bootstrap a new cluster from the object store. It needs the same image, UID/GID and TimescaleDB
settings as the source, or recovery fails on the preload library. Leave out `plugins:` so the
restored cluster doesn't archive WAL into the source's `timescale/` prefix.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: timescale-restore
  namespace: database
spec:
  instances: 1
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ImageCatalog
    name: timescale
    major: 18
  postgresUID: 1000
  postgresGID: 1000
  postgresql:
    shared_preload_libraries:
      - timescaledb
    parameters:
      timescaledb.license: timescale
      max_locks_per_transaction: "1024"
  bootstrap:
    recovery:
      source: timescale
      # recoveryTarget:
      #   targetTime: "2026-10-08 03:00:00+00"
  externalClusters:
    - name: timescale
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: timescale-backup
          serverName: timescale
  storage:
    size: 10Gi
    storageClass: longhorn-local
```

Verify (`\dx` and row counts in `tracearr`), then delete the restore cluster and its PVCs.

## Upgrades

### TimescaleDB extension (after every image bump)

Renovate opens PRs for new `pg18.x-tsX.Y.Z` tags (never automerged; PG major is pinned). After
the cluster has rolled onto the new image, the library is new but the extension objects in
`tracearr` are still the old version. Update them on the primary. `ALTER EXTENSION timescaledb
UPDATE` must be the first statement in a fresh session, so use separate `psql -X` calls:

```sh
P=$(mise x -- kubectl -n database get cluster timescale -o jsonpath='{.status.currentPrimary}')
mise x -- kubectl -n database exec "$P" -c postgres -- psql -X -U postgres -d tracearr -c 'ALTER EXTENSION timescaledb UPDATE;'
mise x -- kubectl -n database exec "$P" -c postgres -- psql -X -U postgres -d tracearr -c 'ALTER EXTENSION timescaledb_toolkit UPDATE;'
mise x -- kubectl -n database exec "$P" -c postgres -- psql -X -U postgres -d tracearr -c '\dx'
```

Until this runs, Tracearr logs a TimescaleDB version-drift warning. Don't set
`TIMESCALEDB_AUTO_UPDATE` in Tracearr: the app role lacks the privilege and the step is one-way.

### PostgreSQL major

Not handled by Renovate (the major is pinned by the versioning rule). Plan it separately: add the
new major to the ImageCatalog, check that the target image ships the same TimescaleDB version, and
follow CNPG's major-upgrade procedure.

## Storage

10Gi `longhorn-local` per instance, holding both data and WAL. WAL is bounded by
`max_wal_size: 512MB` and `max_slot_wal_keep_size: 1GB`. A failing WAL archive is **not** bounded:
WAL piles up on the primary until archiving recovers, so watch `ContinuousArchiving`.

Tracearr data stays small: sessions are compressed after 7 days, `library_snapshots` after 3 days
and dropped after 90. Grow the volume if `cnpg_pg_database_size_bytes` passes about 6 GiB:
raise `spec.storage.size` in `app/cluster.yaml`. `longhorn-local` allows expansion and CNPG
resizes the PVCs in place.
