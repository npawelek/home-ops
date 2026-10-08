# PostgreSQL Databases

This directory contains Database CRDs for creating databases in the main postgres cluster.

## Databases

- **hass**: Home Assistant database
- **firefly**: Firefly III finance manager database
- **immich**: Immich photo management database (requires vector extensions)
- **dawarich**: Dawarich location history (PostGIS, declared in CR)

## Immich Setup

The `immich` Database CR declares `vector` (pgvector), `vchord`, `cube` and `earthdistance` under `spec.extensions`, so CNPG creates them as superuser — no manual step. `vector` and `vchord` have pinned `version`s that Renovate bumps together with the `pgvector` / `cnpg-vchord` images in `../app/cluster.yaml` (groups `pgvector`, `vchord`); CNPG then runs `ALTER EXTENSION ... UPDATE TO` itself. Both libraries must be present in the cluster's extension images: Immich's `smart_search`/`face_search` embeddings are `vector` columns, and without `vector.so` every query touching them fails with `could not access file "vector"`. Verify:

```bash
kubectl exec -n database postgres-1 -c postgres -- \
  psql -U postgres -d immich -c "\dx"
```

## Dawarich Setup

The `dawarich` Database CR declares `postgis` and `pgcrypto` under `spec.extensions`, so CNPG creates them as superuser — no manual step. PostGIS libraries come from the `postgis` extension image in `../app/cluster.yaml`; the CR pins `postgis`'s `version`, which Renovate bumps together with that image (group `postgis`), and CNPG runs `ALTER EXTENSION postgis UPDATE TO` itself. Verify:

```bash
kubectl exec -n database postgres-1 -c postgres -- \
  psql -U postgres -d dawarich -c "\dx"
```
