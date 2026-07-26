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
Usage: configure-fail2ban.sh [--apply] [--dry-run] [--yes] [--help]
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
miniops_require_command fail2ban-client systemctl
target=/etc/fail2ban/jail.d/90-miniops-sshd.local
temporary=$(mktemp)
trap 'rm -f -- "$temporary"' EXIT
cat >"$temporary" <<'EOF'
[sshd]
enabled = true
banaction = ufw
backend = systemd
findtime = 10m
maxretry = 5
bantime = 1h
EOF

(( apply )) || {
  cat "$temporary"
  miniops_log INFO "Preview only. Re-run with --apply."
  exit 0
}
miniops_confirm "Install and activate the MiniOps Fail2ban jail?" ||
  miniops_die "Operator declined Fail2ban changes." 75
miniops_install_file "$temporary" "$target" 0644 root root
if (( ! MINIOPS_DRY_RUN )); then
  fail2ban-client -t
  systemctl enable --now fail2ban.service
  systemctl reload fail2ban.service
fi
miniops_log INFO "Fail2ban SSH jail validated."
