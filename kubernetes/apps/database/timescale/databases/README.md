# TimescaleDB Databases

Database CRDs for the dedicated `timescale` cluster (TimescaleDB, Timescale License edition).

## Databases

- **tracearr**: Tracearr media-server monitoring. The CR declares `timescaledb`, `timescaledb_toolkit` and `pg_trgm` under `spec.extensions`, so CNPG creates them as superuser — no manual step. Verify:

```bash
P=$(kubectl -n database get cluster timescale -o jsonpath='{.status.currentPrimary}')
kubectl exec -n database "$P" -c postgres -- \
  psql -U postgres -d tracearr -c "\dx"
```
