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
Usage: init-repository.sh [--apply] [--dry-run] [--yes] [--help]

Initialize the configured Restic repository if it does not already exist.
Without --apply, show the intended action without changing the repository.
EOF
}

apply=0
while (($#)); do
  case "$1" in
    --apply) apply=1 ;;
    --dry-run) MINIOPS_DRY_RUN=1 ;;
    --yes) MINIOPS_ASSUME_YES=1 ;;
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
miniops_prepare_restic 1

if (( MINIOPS_DRY_RUN )); then
  miniops_quote_command restic init
  exit 0
fi
if restic cat config >/dev/null 2>&1; then
  miniops_log INFO "The configured Restic repository is already initialized."
  exit 0
fi
(( apply )) || {
  miniops_log INFO "Would initialize the configured Restic repository. Re-run with --apply."
  exit 0
}
miniops_confirm "Initialize the configured Restic repository?" ||
  miniops_die "Operator declined repository initialization." 75
restic init
miniops_log INFO "Restic repository initialized successfully."
