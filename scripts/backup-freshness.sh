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
Usage: backup-freshness.sh [--help]

Fail if the last successful backup marker is stale or the repository cannot
return its latest MiniOps snapshot.
EOF
}

while (($#)); do
  case "$1" in
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
marker=$MINIOPS_STATE_DIR/status/last-backup
[[ -s "$marker" ]] || miniops_die "No successful backup marker exists." 1
marker_epoch=$(stat -c '%Y' "$marker")
now_epoch=$(date +%s)
age=$((now_epoch - marker_epoch))
(( age >= 0 && age <= MINIOPS_MAX_BACKUP_AGE_SECONDS )) ||
  miniops_die "Last backup marker is stale (${age}s)." 1

miniops_prepare_restic 1 0
restic snapshots --tag "$MINIOPS_BACKUP_TAG" --latest 1 >/dev/null
miniops_log INFO "Backup freshness is healthy (${age}s old)."
