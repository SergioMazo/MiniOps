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
Usage: check-backup.sh [OPTIONS]

Options:
  --full          Read and verify all repository data
  --subset N/M    Read one deterministic subset (default: 1/4)
  --dry-run       Print the Restic command
  --help
EOF
}

mode=subset
week=$(date +%V)
subset="$((10#$week % 4 + 1))/4"
while (($#)); do
  case "$1" in
    --full) mode=full ;;
    --subset)
      (($# >= 2)) || miniops_usage_error "--subset requires N/M"
      subset=$2
      shift
      ;;
    --dry-run) MINIOPS_DRY_RUN=1 ;;
    --help)
      usage
      exit 0
      ;;
    *) miniops_usage_error "Unknown option: $1" ;;
  esac
  shift
done
[[ "$subset" =~ ^[1-9][0-9]*/[1-9][0-9]*$ ]] ||
  miniops_usage_error "Subset must use N/M"
subset_number=${subset%/*}
subset_total=${subset#*/}
(( subset_number <= subset_total )) ||
  miniops_usage_error "Subset numerator must not exceed its denominator"

if [[ -r "$SCRIPT_DIR/lib/miniops-restic.sh" ]]; then
  # shellcheck source=lib/miniops-restic.sh
  source "$SCRIPT_DIR/lib/miniops-restic.sh"
else
  # shellcheck source=/dev/null
  source /usr/local/lib/miniops/miniops-restic.sh
fi
miniops_require_root
miniops_prepare_restic 1
args=(check)
if [[ "$mode" == full ]]; then
  args+=(--read-data)
else
  args+=("--read-data-subset=$subset")
fi
if (( MINIOPS_DRY_RUN )); then
  miniops_quote_command restic "${args[@]}"
  exit 0
fi
restic "${args[@]}"
miniops_write_marker "$MINIOPS_STATE_DIR/status/last-check"
miniops_log INFO "Repository integrity check completed."
