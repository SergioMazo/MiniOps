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
Usage: validate-reboot.sh [OPTIONS]

Options:
  --prepare   Record the current boot ID before an operator-managed reboot
  --reboot    Record state and request a reboot after explicit confirmation
  --yes       Accept reboot confirmation
  --dry-run   Print reboot action without executing it
  --help

With no option, validate that the boot ID changed and critical services and
MiniOps timers returned.
EOF
}

mode=validate
while (($#)); do
  case "$1" in
    --prepare) mode=prepare ;;
    --reboot) mode=reboot ;;
    --yes) MINIOPS_ASSUME_YES=1 ;;
    --dry-run) MINIOPS_DRY_RUN=1 ;;
    --help)
      usage
      exit 0
      ;;
    *) miniops_usage_error "Unknown option: $1" ;;
  esac
  shift
done

miniops_detect_platform >/dev/null
miniops_require_systemd
boot_id_file=$MINIOPS_STATE_DIR/reboot/before-boot-id

prepare() {
  miniops_require_root
  miniops_run install -d -o root -g root -m 0755 "$(dirname "$boot_id_file")"
  if (( MINIOPS_DRY_RUN )); then
    miniops_quote_command sh -c "cat /proc/sys/kernel/random/boot_id > $boot_id_file"
  else
    cat /proc/sys/kernel/random/boot_id >"$boot_id_file"
    chmod 0644 "$boot_id_file"
  fi
}

if [[ "$mode" == prepare || "$mode" == reboot ]]; then
  prepare
  [[ "$mode" == prepare ]] && {
    miniops_log INFO "Boot baseline recorded. Reboot through your normal change process."
    exit 0
  }
  miniops_confirm "Reboot this host now?" || miniops_die "Operator declined reboot." 75
  miniops_run systemctl reboot
  exit 0
fi

[[ -r "$boot_id_file" ]] || miniops_die "Run --prepare before reboot." 66
before=$(<"$boot_id_file")
after=$(</proc/sys/kernel/random/boot_id)
[[ "$before" != "$after" ]] || miniops_die "Boot ID did not change." 1

failures=0
for service in ssh tailscaled; do
  if systemctl cat "$service.service" >/dev/null 2>&1 &&
    ! systemctl is-active --quiet "$service.service"; then
    miniops_log ERROR "$service.service did not return."
    failures=$((failures + 1))
  fi
done
for timer in \
  miniops-backup.timer \
  miniops-backup-freshness.timer \
  miniops-backup-check.timer \
  miniops-retention.timer \
  miniops-restore-test.timer; do
  if systemctl cat "$timer" >/dev/null 2>&1 &&
    ! systemctl is-active --quiet "$timer"; then
    miniops_log ERROR "$timer is inactive after reboot."
    failures=$((failures + 1))
  fi
done
(( failures == 0 )) || exit 1
miniops_log INFO "Reboot validation succeeded: $before -> $after"
