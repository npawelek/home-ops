#!/usr/bin/env bash
set -Eeuo pipefail

NS=storage
CRONJOB=offsite-backup
POD="offsite-exec-$(date +%s)"

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <run|mirror --dry-run|proton ARGS...|restic ARGS...|sh>" >&2
  exit 2
fi

active=$(kubectl -n "${NS}" get jobs -o json | jq -r --arg cj "${CRONJOB}" '.items[]
  | select(any(.metadata.ownerReferences[]?; .kind == "CronJob" and .name == $cj))
  | select((.status.active // 0) > 0) | .metadata.name' | xargs)
if [[ -n "${active}" ]]; then
  echo "Job ${active} is running and holds the state volume and restic lock; wait for it or delete it first" >&2
  exit 1
fi

shell=false
[[ "$*" == "sh" ]] && shell=true

argv=$(jq -n '$ARGS.positional' --args -- "$@")
spec=$(kubectl -n "${NS}" get cronjob "${CRONJOB}" -o json | jq \
  --argjson shell "${shell}" --argjson argv "${argv}" \
  --arg steps "${OFFSITE_STEPS:-}" --arg massdelete "${MIRROR_ALLOW_MASS_DELETE:-}" '
  .spec.jobTemplate.spec.template.spec
  | .restartPolicy = "Never"
  | .containers[0].command = (if $shell then ["bash"] else ["python3", "/scripts/offsite-backup.py"] + $argv end)
  | .containers[0].stdin = $shell
  | .containers[0].tty = $shell
  | if $steps != "" then .containers[0].env += [{name: "OFFSITE_STEPS", value: $steps}] else . end
  | if $massdelete != "" then .containers[0].env += [{name: "MIRROR_ALLOW_MASS_DELETE", value: $massdelete}] else . end
  ')

image=$(jq -r '.containers[0].image' <<<"${spec}")
overrides=$(jq -n --argjson spec "${spec}" '{apiVersion: "v1", spec: $spec}')

if [[ "${shell}" == true ]]; then
  exec kubectl -n "${NS}" run "${POD}" --rm -it --restart=Never --image="${image}" \
    --pod-running-timeout=10m --overrides="${overrides}"
fi

trap 'kubectl -n "${NS}" delete pod "${POD}" --wait=false --ignore-not-found >/dev/null' EXIT

kubectl -n "${NS}" run "${POD}" --restart=Never --image="${image}" --overrides="${overrides}" >/dev/null

phase=Pending
for _ in $(seq 300); do
  phase=$(kubectl -n "${NS}" get pod "${POD}" -o jsonpath='{.status.phase}')
  [[ "${phase}" != "Pending" ]] && break
  sleep 2
done
if [[ "${phase}" == "Pending" ]]; then
  kubectl -n "${NS}" describe pod "${POD}" | sed -n '/^Events:/,$p' >&2
  echo "${POD} still Pending after 10m" >&2
  exit 1
fi

running='{.status.containerStatuses[0].state.running.startedAt}'
kubectl -n "${NS}" logs -f "${POD}" -c offsite-backup || true
while [[ -n $(kubectl -n "${NS}" get pod "${POD}" -o jsonpath="${running}") ]]; do
  since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  sleep 2
  kubectl -n "${NS}" logs -f --since-time="${since}" "${POD}" -c offsite-backup || true
done

code=""
for _ in $(seq 30); do
  code=$(kubectl -n "${NS}" get pod "${POD}" \
    -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}')
  [[ -n "${code}" ]] && break
  sleep 1
done
exit "${code:-1}"
