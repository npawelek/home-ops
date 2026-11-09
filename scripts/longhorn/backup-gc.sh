#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

NS="${LONGHORN_NAMESPACE:-longhorn-system}"
GRACE_DAYS="${GRACE_DAYS:-28}"
RECENT_HOURS="${RECENT_HOURS:-48}"
MAX_DELETE="${MAX_DELETE:-10}"
DRY_RUN="${DRY_RUN:-true}"

function main() {
  check_cli kubectl jq

  local volumes backupvolumes candidates recent count
  volumes=$(kubectl -n "${NS}" get volumes.longhorn.io -o json | jq '[.items[].metadata.name]')
  if [[ $(jq length <<<"${volumes}") -eq 0 ]]; then
    log error "No Longhorn volumes listed; refusing to treat any backup as orphaned"
  fi

  backupvolumes=$(kubectl -n "${NS}" get backupvolumes.longhorn.io -o json)
  recent=$(jq --argjson hours "${RECENT_HOURS}" '[.items[]
    | select((.status.lastBackupAt // "") != "")
    | select((now - (.status.lastBackupAt | fromdateiso8601)) < ($hours * 3600))] | length' <<<"${backupvolumes}")
  if [[ "${recent}" -eq 0 ]]; then
    log error "No backup in the last ${RECENT_HOURS}h; backups are not running (restore in progress?), refusing to delete"
  fi

  candidates=$(jq -r --argjson volumes "${volumes}" --argjson grace "$((GRACE_DAYS * 86400))" '.items[]
    | select(.metadata.deletionTimestamp == null)
    | select(.spec.volumeName as $v | $volumes | index($v) | not)
    | select((.status.lastBackupAt // "") != "")
    | select((now - (.status.lastBackupAt | fromdateiso8601)) > $grace)
    | [.metadata.name, ((.status.labels.KubernetesStatus // "{}") | fromjson
        | "\(.namespace // "?")/\(.pvcName // "?")"), .status.lastBackupAt] | @tsv' <<<"${backupvolumes}")

  if [[ -z "${candidates}" ]]; then
    log info "No orphaned backup volumes older than ${GRACE_DAYS} days"
    return 0
  fi

  count=$(wc -l <<<"${candidates}" | tr -d ' ')
  if [[ "${count}" -gt "${MAX_DELETE}" ]]; then
    log error "${count} orphaned backup volumes exceed MAX_DELETE=${MAX_DELETE}; refusing" "candidates=${candidates//$'\t'/ }"
  fi

  local name pvc last
  while IFS=$'\t' read -r name pvc last; do
    if [[ "${DRY_RUN}" == "true" ]]; then
      log info "Would delete backup volume" "name=${name}" "pvc=${pvc}" "lastBackupAt=${last}"
    else
      log info "Deleting backup volume" "name=${name}" "pvc=${pvc}" "lastBackupAt=${last}"
      kubectl -n "${NS}" delete backupvolumes.longhorn.io "${name}" --wait=false
    fi
  done <<<"${candidates}"
}

main "$@"
