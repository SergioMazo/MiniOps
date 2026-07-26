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
Usage: configure-apparmor.sh [--apply] [--dry-run] [--yes] [--help]

Validate and optionally enable the distribution-provided AppArmor service.
MiniOps does not install an untested custom policy.
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
miniops_require_command aa-status systemctl
aa-status --enabled ||
  miniops_die "AppArmor is unavailable or disabled in the running kernel." 69
(( apply )) || {
  aa-status
  miniops_log INFO "Validation only. Re-run with --apply to enable the service."
  exit 0
}
miniops_confirm "Enable the distribution AppArmor service?" ||
  miniops_die "Operator declined AppArmor activation." 75
miniops_run systemctl enable --now apparmor.service
miniops_log INFO "AppArmor service is enabled; loaded profiles were not modified."
