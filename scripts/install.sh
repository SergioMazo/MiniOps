#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=lib/miniops-common.sh
source "$SCRIPT_DIR/lib/miniops-common.sh"

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Install selected MiniOps modules.

Options:
  --modules LIST       Comma-separated modules (default: core,backup,status)
  --apply              Apply selected host configuration after installation
  --enable-timers      Enable backup timers after installing them
  --dry-run            Print actions without changing the host
  --yes                Accept explicit confirmation prompts
  --allow-unsupported  Permit an untested Linux distribution
  --help               Show this help

Modules:
  core, ssh, ufw, fail2ban, auditd, apparmor, restic, backup, status
EOF
}

modules_csv=core,backup,status
apply=0
enable_timers=0
while (($#)); do
  case "$1" in
    --modules)
      (($# >= 2)) || miniops_usage_error "--modules requires a value"
      modules_csv=$2
      shift
      ;;
    --apply)
      apply=1
      ;;
    --enable-timers)
      enable_timers=1
      ;;
    --dry-run)
      MINIOPS_DRY_RUN=1
      ;;
    --yes)
      MINIOPS_ASSUME_YES=1
      ;;
    --allow-unsupported)
      MINIOPS_ALLOW_UNSUPPORTED=1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      miniops_usage_error "Unknown option: $1"
      ;;
  esac
  shift
done

miniops_require_root
miniops_require_command awk cmp install systemctl
preflight_args=()
[[ ${MINIOPS_ALLOW_UNSUPPORTED:-0} == 1 ]] && preflight_args+=(--allow-unsupported)
"$SCRIPT_DIR/preflight-check.sh" "${preflight_args[@]}"

IFS=, read -r -a modules <<<"$modules_csv"
((${#modules[@]})) || miniops_usage_error "At least one module is required"

valid_module() {
  case "$1" in
    core | ssh | ufw | fail2ban | auditd | apparmor | restic | backup | status) return 0 ;;
    *) return 1 ;;
  esac
}

has_module() {
  local wanted=$1
  local module
  for module in "${modules[@]}"; do
    [[ "$module" == "$wanted" ]] && return 0
  done
  return 1
}

for module in "${modules[@]}"; do
  valid_module "$module" || miniops_usage_error "Unknown module: $module"
done

printf 'MiniOps installation plan\n'
printf '  Modules: %s\n' "$modules_csv"
printf '  Apply host configuration: %s\n' "$apply"
printf '  Enable timers: %s\n' "$enable_timers"
printf '  Dry run: %s\n' "$MINIOPS_DRY_RUN"

if (( apply )) && { has_module ssh || has_module ufw; }; then
  miniops_confirm "Apply remote-access security changes?" ||
    miniops_die "Operator declined sensitive changes." 75
fi

miniops_run install -d -o root -g root -m 0755 \
  /etc/miniops /etc/miniops/secrets /usr/local/lib/miniops \
  /var/lib/miniops/status /var/cache/miniops /var/log/miniops
miniops_run chmod 0700 /etc/miniops/secrets

manifest_tmp=$(mktemp)
trap 'rm -f -- "$manifest_tmp"' EXIT

record_path() {
  printf '%s\n' "$1" >>"$manifest_tmp"
}

install_default() {
  local source=$1 target=$2 mode=$3
  if [[ -e "$target" ]]; then
    miniops_log INFO "Preserving existing configuration: $target"
    return 0
  fi
  miniops_run install -D -o root -g root -m "$mode" "$source" "$target"
  miniops_log INFO "Installed default: $target"
  record_path "$target"
}

install_program() {
  local source=$1 target=$2
  miniops_install_file "$source" "$target" 0755 root root
  record_path "$target"
}

install_program "$SCRIPT_DIR/lib/miniops-common.sh" /usr/local/lib/miniops/miniops-common.sh
install_program "$SCRIPT_DIR/preflight-check.sh" /usr/local/sbin/miniops-preflight
install_program "$SCRIPT_DIR/uninstall.sh" /usr/local/sbin/miniops-uninstall

install_default "$PROJECT_ROOT/config/miniops.env.example" /etc/miniops/miniops.env 0644

declare -A module_script=(
  [ssh]=harden-ssh.sh
  [ufw]=configure-ufw.sh
  [fail2ban]=configure-fail2ban.sh
  [auditd]=configure-auditd.sh
  [apparmor]=configure-apparmor.sh
  [restic]=install-restic.sh
)

for module in ssh ufw fail2ban auditd apparmor restic; do
  if has_module "$module"; then
    target="/usr/local/sbin/miniops-${module_script[$module]%.sh}"
    install_program "$SCRIPT_DIR/${module_script[$module]}" "$target"
    if [[ "$module" == restic ]]; then
      install_program "$SCRIPT_DIR/configure-restic-sftp.sh" \
        /usr/local/sbin/miniops-configure-restic-sftp
    fi
    if (( apply )); then
      args=(--apply)
      (( MINIOPS_ASSUME_YES )) && args+=(--yes)
      (( MINIOPS_DRY_RUN )) && args+=(--dry-run)
      "$SCRIPT_DIR/${module_script[$module]}" "${args[@]}"
    fi
  fi
done

if has_module backup; then
  install_program "$SCRIPT_DIR/lib/miniops-restic.sh" /usr/local/lib/miniops/miniops-restic.sh
  for script_name in \
    init-repository \
    backup \
    check-backup \
    backup-freshness \
    retention \
    restore-test; do
    install_program "$SCRIPT_DIR/${script_name}.sh" "/usr/local/sbin/miniops-${script_name}"
  done
  install_default "$PROJECT_ROOT/config/backup.env.example" /etc/miniops/backup.env 0600
  install_default "$PROJECT_ROOT/config/retention.env.example" /etc/miniops/retention.env 0644
  install_default "$PROJECT_ROOT/config/backup-sources.example" /etc/miniops/backup-sources 0644
  install_default "$PROJECT_ROOT/config/backup-excludes.example" /etc/miniops/backup-excludes 0644
  install_default "$PROJECT_ROOT/config/restore-test-paths.example" /etc/miniops/restore-test-paths 0644

  for unit_source in "$PROJECT_ROOT"/systemd/miniops-*; do
    unit_name=$(basename "$unit_source")
    miniops_install_file "$unit_source" "/etc/systemd/system/$unit_name" 0644 root root
    record_path "/etc/systemd/system/$unit_name"
  done
  miniops_run systemctl daemon-reload

  if (( enable_timers )); then
    miniops_confirm "Enable MiniOps backup timers?" ||
      miniops_die "Operator declined timer activation." 75
    for timer in \
      miniops-backup.timer \
      miniops-backup-freshness.timer \
      miniops-backup-check.timer \
      miniops-retention.timer \
      miniops-restore-test.timer; do
      miniops_run systemctl enable --now "$timer"
    done
  fi
fi

if has_module status; then
  install_program "$SCRIPT_DIR/backup-status.sh" /usr/local/sbin/miniops-status
  install_program "$SCRIPT_DIR/health-check.sh" /usr/local/sbin/miniops-health-check
  install_program "$SCRIPT_DIR/validate-reboot.sh" /usr/local/sbin/miniops-validate-reboot
fi

if (( ! MINIOPS_DRY_RUN )); then
  manifest=/var/lib/miniops/install-manifest
  if [[ -e "$manifest" ]]; then
    miniops_backup_file "$manifest"
  fi
  sort -u "$manifest_tmp" >"$manifest"
  chown root:root "$manifest"
  chmod 0600 "$manifest"
fi

miniops_log INFO "Installation completed. Review /etc/miniops before enabling jobs."
