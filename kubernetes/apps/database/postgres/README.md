# Postgres (Main)

Shared CNPG PostgreSQL 18 cluster for most apps: `hass`, `firefly`, `immich`, `lubelogger`, `buzz`,
`dawarich`. Each app has a managed role (`app/cluster.yaml` `spec.managed.roles`, password from
`app/credentials-<app>.sops.yaml`) and a Database CR in `databases/` (see `databases/README.md`).
Tracearr runs on the separate `timescale` cluster (`../timescale/`).

- Image: `ghcr.io/cloudnative-pg/postgresql:18-minimal-trixie`, plus extension images mounted via
  `spec.postgresql.extensions`: `pgvector` and `vchord` (immich; `vchord.so` is preloaded) and
  `postgis` (dawarich, with GEOS/PROJ/GDAL under `system/`).
- 3 instances, `longhorn-local` 30Gi each, required pod anti-affinity across nodes.
- Services: `postgres-rw.database.svc.cluster.local:5432` in-cluster (`ro`/`r` disabled), and
  `postgres-external-rw` as a MetalLB LoadBalancer at `${CNPG_LB}` for LAN clients (see `pg_hba`).
- TLS required (`hostssl`, scram-sha-256). Superuser access is enabled (`credentials-admin`).

Status: `task cnpg:status-postgres`. Promote: `task cnpg:promote-postgres NODE=postgres-N`.

## Backups

Barman Cloud plugin to RustFS bucket `cnpg-database-postgres` (`ObjectStore/postgres-backup`,
`destinationPath: ${BACKUP_DESTINATION_PATH_MAIN}`, credentials `credentials-backup-s3`, created by
`terraform/rustfs/cnpg-database-postgres.tf`).

- WAL archived continuously (`ContinuousArchiving` condition).
- Base backups at 05:00 and 17:00 UTC (`ScheduledBackup/postgres`, `0 0 5/12 * * *`).
- Retention: 21 days (`ObjectStore.spec.retentionPolicy`). The `spec.backup.retentionPolicy: 14d`
  in `app/cluster.yaml` is a leftover from in-tree barman and doesn't apply to plugin backups.

Check backups with `ObjectStore.status.serverRecoveryWindow`, not `Cluster.status.lastSuccessfulBackup`
(that field is only maintained for in-tree barman):

```sh
mise x -- kubectl -n database get objectstore postgres-backup -o jsonpath='{.status.serverRecoveryWindow.postgres}'
```

Manual base backup:

```sh
cat <<'EOF' | mise x -- kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: postgres-manual
  namespace: database
spec:
  cluster:
    name: postgres
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
    parameters:
      barmanObjectName: postgres-backup
EOF
mise x -- kubectl -n database get backup postgres-manual -w   # phase: completed
```

## Restore

Bootstrap a new cluster from the object store. It needs the same base image and extension images as
the source, and `vchord.so` preloaded, or recovery fails. Copy the current image references from
`app/cluster.yaml`. Leave out `plugins:` so the restored cluster doesn't archive WAL into the source's
`postgres/` prefix.

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-restore
  namespace: database
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:18-minimal-trixie  # same tag@digest as app/cluster.yaml
  postgresql:
    extensions:  # same references as app/cluster.yaml
      - name: pgvector
        image:
          reference: ghcr.io/cloudnative-pg/pgvector:0.8.7-18-trixie
      - name: vchord
        image:
          reference: ghcr.io/jdijt/cnpg-vchord:1.1.1-20260823082441-18-trixie
      - name: postgis
        image:
          reference: ghcr.io/cloudnative-pg/postgis-extension:3.6.4-18-trixie
        ld_library_path:
          - system
    shared_preload_libraries:
      - "vchord.so"
  bootstrap:
    recovery:
      source: postgres
      # recoveryTarget:
      #   targetTime: "2026-10-08 03:00:00+00"
  externalClusters:
    - name: postgres
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: postgres-backup
          serverName: postgres
  storage:
    size: 30Gi
    storageClass: longhorn-local
```

Verify (`\l`, `\dx` per database, row counts), then delete the restore cluster and its PVCs.

## Extension upgrades

- `vector`, `vchord` (immich) and `postgis` (dawarich) are pinned by `version` in their Database
  CRs. Renovate bumps each extension image and its CR `version` in one PR (groups `pgvector`,
  `vchord`, `postgis`). After the cluster rolls, CNPG runs `ALTER EXTENSION ... UPDATE TO` itself,
  retrying every 30s until the primary is on the new image.
- Contrib extensions (`pgcrypto`, `cube`, `earthdistance`, `pg_trgm`, `unaccent`, `uuid-ossp`) ship
  with PostgreSQL and only change version on a PostgreSQL major upgrade.
- Every extension in a database must have its files in the cluster's images. If an image is dropped,
  the extension stays installed but every query touching its types fails (tech-debt #27: pgvector was
  missing for ~5 weeks). Check each database after image changes:

```sql
select e.extname, e.extversion, coalesce(a.default_version, 'MISSING')
from pg_extension e left join pg_available_extensions a on a.name = e.extname
where a.default_version is distinct from e.extversion;
```

Expect no rows. `MISSING` means the extension's files aren't in any mounted image.
