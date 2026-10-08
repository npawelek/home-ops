# PostgreSQL Databases

This directory contains Database CRDs for creating databases in the main postgres cluster.

## Databases

- **hass**: Home Assistant database
- **firefly**: Firefly III finance manager database
- **immich**: Immich photo management database (requires vector extensions)
- **dawarich**: Dawarich location history (PostGIS, declared in CR)

## Immich Setup

After the immich database is created, you need to install the required extensions:

```bash
kubectl exec -n database postgres-1 -c postgres -- \
  psql -U postgres -d immich -c "CREATE EXTENSION IF NOT EXISTS vchord CASCADE;"
kubectl exec -n database postgres-1 -c postgres -- \
  psql -U postgres -d immich -c "CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;"
```

Verify extensions are installed:

```bash
kubectl exec -n database postgres-1 -c postgres -- \
  psql -U postgres -d immich -c "\dx"
```

You should see `vchord` and `earthdistance` in the list.

## Dawarich Setup

The `dawarich` Database CR declares `postgis` and `pgcrypto` under `spec.extensions`, so CNPG creates them as superuser — no manual step. PostGIS libraries come from the `postgis` extension image in `../app/cluster.yaml`. Verify:

```bash
kubectl exec -n database postgres-1 -c postgres -- \
  psql -U postgres -d dawarich -c "\dx"
```
