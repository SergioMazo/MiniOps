#!/usr/bin/env bash
set -Eeuo pipefail

miniops_detect_platform >/dev/null
RESTIC_CONFIG=${MINIOPS_BACKUP_CONFIG:-/etc/miniops/backup.env}
miniops_load_env "$RESTIC_CONFIG"

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is required}"
: "${RESTIC_PASSWORD_FILE:?RESTIC_PASSWORD_FILE is required}"
: "${MINIOPS_BACKUP_TAG:=miniops}"
: "${MINIOPS_BACKUP_HOST:=$(hostname)}"
: "${MINIOPS_RESTIC_CACHE_DIR:=/var/cache/miniops/restic}"
: "${MINIOPS_RESTIC_LOCK:=/run/lock/miniops-restic.lock}"
: "${MINIOPS_MAX_BACKUP_AGE_SECONDS:=108000}"

export RESTIC_REPOSITORY
export RESTIC_PASSWORD_FILE
export RESTIC_CACHE_DIR=$MINIOPS_RESTIC_CACHE_DIR
if [[ -n ${MINIOPS_SFTP_COMMAND:-} ]]; then
  export RESTIC_SFTP_COMMAND=$MINIOPS_SFTP_COMMAND
fi

miniops_require_command restic flock
miniops_validate_secret_file "$RESTIC_PASSWORD_FILE"
miniops_require_absolute_safe_path "$MINIOPS_RESTIC_CACHE_DIR"
miniops_require_absolute_safe_path "$MINIOPS_RESTIC_LOCK"

miniops_prepare_restic() {
  local wait_seconds=${1:-1}
  local prepare_state=${2:-1}
  miniops_run install -d -o root -g root -m 0700 "$MINIOPS_RESTIC_CACHE_DIR"
  if (( prepare_state )); then
    miniops_run install -d -o root -g root -m 0700 "$MINIOPS_STATE_DIR/status"
  fi
  miniops_acquire_lock "$MINIOPS_RESTIC_LOCK" "$wait_seconds"
}

miniops_refresh_backup_status() {
  local marker="$MINIOPS_STATE_DIR/status/backup.env"
  local snapshot_output snapshot_count repository_size temporary
  snapshot_output=$(restic snapshots --tag "$MINIOPS_BACKUP_TAG" --compact)
  snapshot_count=$(awk '/ snapshots?$/ {print $1}' <<<"$snapshot_output" | tail -n 1)
  snapshot_count=${snapshot_count:-unknown}
  repository_size=$(
    restic stats --mode raw-data 2>/dev/null |
      awk -F: '/Total Size:/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}'
  )
  repository_size=${repository_size:-unknown}
  temporary=$(mktemp "$MINIOPS_STATE_DIR/status/.backup.XXXXXX")
  {
    printf 'LAST_BACKUP=%q\n' "$(miniops_now)"
    printf 'SNAPSHOT_COUNT=%q\n' "$snapshot_count"
    printf 'REPOSITORY_SIZE=%q\n' "$repository_size"
  } >"$temporary"
  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$marker"
}
