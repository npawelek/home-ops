#!/usr/bin/env bash
set -Eeuo pipefail

NS=storage
CRONJOB=offsite-backup
POD="offsite-exec-$(date +%s)"

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <run|mirror --dry-run|proton ARGS...|restic ARGS...|sh>" >&2
  exit 2
fi

active=$(kubectl -n "${NS}" get cronjob "${CRONJOB}" -o jsonpath='{.status.active[*].name}')
if [[ -n "${active}" ]]; then
  echo "Job ${active} is running and holds the state volume and restic lock; wait for it or delete it first" >&2
  exit 1
fi

tty=false
[[ -t 0 && -t 1 ]] && tty=true

argv=$(jq -n '$ARGS.positional' --args -- "$@")
spec=$(kubectl -n "${NS}" get cronjob "${CRONJOB}" -o json | jq \
  --argjson tty "${tty}" --argjson argv "${argv}" \
  --arg steps "${OFFSITE_STEPS:-}" --arg massdelete "${MIRROR_ALLOW_MASS_DELETE:-}" '
  .spec.jobTemplate.spec.template.spec
  | .restartPolicy = "Never"
  | .containers[0].command = (if $argv == ["sh"] then ["bash"] else ["python3", "/scripts/offsite-backup.py"] + $argv end)
  | .containers[0].stdin = true
  | .containers[0].tty = $tty
  | if $steps != "" then .containers[0].env += [{name: "OFFSITE_STEPS", value: $steps}] else . end
  | if $massdelete != "" then .containers[0].env += [{name: "MIRROR_ALLOW_MASS_DELETE", value: $massdelete}] else . end
  ')

image=$(jq -r '.containers[0].image' <<<"${spec}")
flags=(-i)
[[ "${tty}" == true ]] && flags+=(-t)

kubectl -n "${NS}" run "${POD}" --rm "${flags[@]}" --restart=Never --image="${image}" \
  --pod-running-timeout=10m \
  --overrides="$(jq -n --argjson spec "${spec}" '{apiVersion: "v1", spec: $spec}')"
