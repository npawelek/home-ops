# PostgreSQL Databases

This directory contains Database CRDs for creating databases in the main postgres cluster.

## Databases

- **hass**: Home Assistant database
- **jellystat**: Jellyfin statistics database
- **firefly**: Firefly III finance manager database
- **immich**: Immich photo management database (requires vector extensions)

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
