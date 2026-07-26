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
Usage: configure-ufw.sh [--apply] [--dry-run] [--yes] [--help]

Configure conservative UFW defaults and an administrative SSH source.
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
miniops_require_command ufw
config=${MINIOPS_GENERAL_CONFIG:-/etc/miniops/miniops.env}
[[ -f "$config" ]] && miniops_load_env "$config"

allowed_cidr=${MINIOPS_SSH_ALLOWED_CIDR:-}
enable_tailscale=${MINIOPS_ENABLE_TAILSCALE:-0}
[[ "$allowed_cidr" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]] ||
  miniops_die "Set MINIOPS_SSH_ALLOWED_CIDR to a concrete IPv4 CIDR." 78
[[ "$allowed_cidr" != *x* ]] ||
  miniops_die "Replace the fictitious SSH CIDR before applying UFW." 78

printf 'UFW plan: deny incoming, allow outgoing, permit SSH from %s' "$allowed_cidr"
(( enable_tailscale )) && printf ', permit tailscale0'
printf '\n'
(( apply )) || {
  miniops_log INFO "Preview only. Re-run with --apply."
  exit 0
}

miniops_confirm "Apply UFW rules and enable the firewall?" ||
  miniops_die "Operator declined UFW changes." 75

state_backup="/var/lib/miniops/ufw-status-$(date -u +%Y%m%dT%H%M%SZ).txt"
config_backup="/var/lib/miniops/ufw-config-$(date -u +%Y%m%dT%H%M%SZ)"
miniops_run install -d -o root -g root -m 0700 /var/lib/miniops
if [[ -d /etc/ufw && ! -L /etc/ufw ]]; then
  [[ ! -e "$config_backup" ]] || miniops_die "UFW backup target already exists." 73
  miniops_run cp -a -- /etc/ufw "$config_backup"
fi
if (( MINIOPS_DRY_RUN )); then
  miniops_quote_command sh -c "ufw status verbose > $state_backup"
else
  ufw status verbose >"$state_backup"
  chmod 0600 "$state_backup"
fi

miniops_run ufw default deny incoming
miniops_run ufw default allow outgoing
if ! ufw status | grep -Fq "$allowed_cidr"; then
  miniops_run ufw allow from "$allowed_cidr" to any port 22 proto tcp comment 'MiniOps SSH'
fi
if (( enable_tailscale )) && ! ufw status | grep -Fq 'tailscale0'; then
  miniops_run ufw allow in on tailscale0 comment 'MiniOps Tailscale'
fi
miniops_run ufw --force enable
miniops_log INFO "UFW configuration completed. State backup: $state_backup"
