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
Usage: retention.sh [--apply] [--dry-run] [--help]

Without --apply, Restic evaluates retention without changing the repository.
EOF
}

apply=0
while (($#)); do
  case "$1" in
    --apply) apply=1 ;;
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
retention_config=${MINIOPS_RETENTION_CONFIG:-/etc/miniops/retention.env}
miniops_load_env "$retention_config"
for variable in \
  MINIOPS_KEEP_DAILY \
  MINIOPS_KEEP_WEEKLY \
  MINIOPS_KEEP_MONTHLY \
  MINIOPS_KEEP_YEARLY; do
  value=${!variable:-}
  [[ "$value" =~ ^[0-9]+$ ]] || miniops_die "$variable must be a non-negative integer." 78
done

miniops_prepare_restic 1
args=(
  forget
  --tag "$MINIOPS_BACKUP_TAG"
  --keep-daily "$MINIOPS_KEEP_DAILY"
  --keep-weekly "$MINIOPS_KEEP_WEEKLY"
  --keep-monthly "$MINIOPS_KEEP_MONTHLY"
  --keep-yearly "$MINIOPS_KEEP_YEARLY"
)
if (( apply )); then
  [[ ${MINIOPS_RETENTION_PRUNE:-0} == 1 ]] && args+=(--prune)
else
  args+=(--dry-run)
fi
if (( MINIOPS_DRY_RUN )); then
  miniops_quote_command restic "${args[@]}"
  exit 0
fi
restic "${args[@]}"
(( apply )) && miniops_write_marker "$MINIOPS_STATE_DIR/status/last-retention"
miniops_log INFO "Retention evaluation completed (apply=$apply)."
