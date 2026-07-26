#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -r "$SCRIPT_DIR/lib/miniops-common.sh" ]]; then
  # shellcheck source=lib/miniops-common.sh
  source "$SCRIPT_DIR/lib/miniops-common.sh"
else
  # shellcheck source=/dev/null
  source /usr/local/lib/miniops/miniops-common.sh
fi

usage() {
  cat <<'EOF'
Usage: backup.sh [--dry-run] [--help]

Create an encrypted Restic backup using /etc/miniops/backup.env.
EOF
}

while (($#)); do
  case "$1" in
    --dry-run) MINIOPS_DRY_RUN=1 ;;
    --help)
      usage
      exit 0
      ;;
    *) miniops_usage_error "Unknown option: $1" ;;
  esac
  shift
done

if [[ -r "$SCRIPT_DIR/lib/miniops-restic.sh" ]]; then
  # shellcheck source=lib/miniops-restic.sh
  source "$SCRIPT_DIR/lib/miniops-restic.sh"
else
  # shellcheck source=/dev/null
  source /usr/local/lib/miniops/miniops-restic.sh
fi
miniops_require_root
: "${MINIOPS_BACKUP_SOURCES_FILE:?MINIOPS_BACKUP_SOURCES_FILE is required}"
: "${MINIOPS_BACKUP_EXCLUDES_FILE:?MINIOPS_BACKUP_EXCLUDES_FILE is required}"
[[ -s "$MINIOPS_BACKUP_SOURCES_FILE" && ! -L "$MINIOPS_BACKUP_SOURCES_FILE" ]] ||
  miniops_die "Backup sources file is unavailable." 78
[[ -f "$MINIOPS_BACKUP_EXCLUDES_FILE" && ! -L "$MINIOPS_BACKUP_EXCLUDES_FILE" ]] ||
  miniops_die "Backup excludes file is unavailable." 78

miniops_prepare_restic 1
args=(
  backup
  --files-from "$MINIOPS_BACKUP_SOURCES_FILE"
  --exclude-file "$MINIOPS_BACKUP_EXCLUDES_FILE"
  --tag "$MINIOPS_BACKUP_TAG"
  --host "$MINIOPS_BACKUP_HOST"
)
[[ ${MINIOPS_BACKUP_ONE_FILE_SYSTEM:-1} == 1 ]] && args+=(--one-file-system)

miniops_log INFO "Starting encrypted backup for configured source list."
if (( MINIOPS_DRY_RUN )); then
  miniops_quote_command restic "${args[@]}" --dry-run
  exit 0
fi

failure() {
  local rc=$?
  miniops_log ERROR "Backup failed with exit code $rc."
  exit "$rc"
}
trap failure ERR
restic "${args[@]}"
miniops_write_marker "$MINIOPS_STATE_DIR/status/last-backup"
miniops_refresh_backup_status
trap - ERR
miniops_log INFO "Backup completed successfully."
