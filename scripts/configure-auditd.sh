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
Usage: configure-auditd.sh [--apply] [--dry-run] [--yes] [--help]
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
miniops_require_command augenrules systemctl
target=/etc/audit/rules.d/90-miniops.rules
temporary=$(mktemp)
trap 'rm -f -- "$temporary"' EXIT
cat >"$temporary" <<'EOF'
## MiniOps security-relevant configuration watches
-w /etc/miniops/ -p wa -k miniops_config
-w /etc/ssh/sshd_config -p wa -k ssh_config
-w /etc/ssh/sshd_config.d/ -p wa -k ssh_config
-w /etc/systemd/system/ -p wa -k systemd_units
EOF

(( apply )) || {
  cat "$temporary"
  miniops_log INFO "Preview only. Re-run with --apply."
  exit 0
}
miniops_confirm "Install MiniOps audit rules?" ||
  miniops_die "Operator declined auditd changes." 75
miniops_install_file "$temporary" "$target" 0640 root root
if (( ! MINIOPS_DRY_RUN )); then
  augenrules --check
  augenrules --load
  systemctl enable --now auditd.service
fi
miniops_log INFO "auditd rules validated."
