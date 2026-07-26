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
Usage: install-restic.sh [--apply] [--dry-run] [--yes] [--help]

Install the distribution-packaged Restic version using apt.
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

miniops_require_root
miniops_detect_platform >/dev/null
miniops_require_command apt-get
if command -v restic >/dev/null 2>&1; then
  restic version
  miniops_log INFO "Restic is already installed."
  exit 0
fi
(( apply )) || {
  miniops_log INFO "Would install the distribution package: restic"
  exit 0
}
miniops_confirm "Install Restic from the configured apt repositories?" ||
  miniops_die "Operator declined Restic installation." 75
miniops_run apt-get update
miniops_run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends restic
if (( ! MINIOPS_DRY_RUN )); then
  restic version
fi

