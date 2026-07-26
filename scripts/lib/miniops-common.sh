#!/usr/bin/env bash
set -Eeuo pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LC_ALL=C

MINIOPS_DRY_RUN=${MINIOPS_DRY_RUN:-0}
MINIOPS_ASSUME_YES=${MINIOPS_ASSUME_YES:-0}
MINIOPS_CONFIG_DIR=${MINIOPS_CONFIG_DIR:-/etc/miniops}
MINIOPS_STATE_DIR=${MINIOPS_STATE_DIR:-/var/lib/miniops}
MINIOPS_CACHE_DIR=${MINIOPS_CACHE_DIR:-/var/cache/miniops}
MINIOPS_LOG_DIR=${MINIOPS_LOG_DIR:-/var/log/miniops}

miniops_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

miniops_log() {
  local level=$1
  shift
  printf '%s [%s] %s\n' "$(miniops_now)" "$level" "$*" >&2
}

miniops_die() {
  local message=$1
  local code=${2:-1}
  miniops_log ERROR "$message"
  exit "$code"
}

miniops_usage_error() {
  miniops_die "$1" 64
}

miniops_require_command() {
  local command_name
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 ||
      miniops_die "Required command not found: $command_name" 69
  done
}

miniops_require_root() {
  (( EUID == 0 )) || miniops_die "This operation requires root privileges." 77
}

miniops_quote_command() {
  local argument
  printf '+'
  for argument in "$@"; do
    printf ' %q' "$argument"
  done
  printf '\n'
}

miniops_run() {
  if (( MINIOPS_DRY_RUN )); then
    miniops_quote_command "$@"
    return 0
  fi
  "$@"
}

miniops_confirm() {
  local prompt=$1
  if (( MINIOPS_ASSUME_YES )); then
    return 0
  fi
  [[ -t 0 ]] || miniops_die "Confirmation required: $prompt" 75
  local answer
  read -r -p "$prompt [y/N] " answer
  [[ "$answer" == y || "$answer" == Y || "$answer" == yes || "$answer" == YES ]]
}

miniops_require_absolute_safe_path() {
  local path=$1
  [[ "$path" == /* ]] || miniops_die "Path must be absolute: $path" 65
  case "$path" in
    / | /etc | /usr | /var | /home | /root)
      miniops_die "Refusing broad path: $path" 65
      ;;
  esac
}

miniops_backup_file() {
  local target=$1
  [[ -e "$target" ]] || return 0
  [[ ! -L "$target" ]] || miniops_die "Refusing to back up symlink: $target" 73
  local stamp backup
  stamp=$(date -u +%Y%m%dT%H%M%SZ)
  backup="${target}.miniops-backup-${stamp}"
  [[ ! -e "$backup" ]] || miniops_die "Backup already exists: $backup" 73
  miniops_run cp -a -- "$target" "$backup"
  miniops_log INFO "Backup created: $backup"
}

miniops_install_file() {
  local source=$1
  local target=$2
  local mode=$3
  local owner=${4:-root}
  local group=${5:-root}
  [[ -f "$source" && ! -L "$source" ]] ||
    miniops_die "Source must be a regular file: $source" 66
  miniops_require_absolute_safe_path "$target"
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    miniops_run chown "$owner:$group" "$target"
    miniops_run chmod "$mode" "$target"
    miniops_log INFO "Already current: $target"
    return 0
  fi
  miniops_backup_file "$target"
  miniops_run install -D -o "$owner" -g "$group" -m "$mode" "$source" "$target"
  miniops_log INFO "Installed: $target"
}

miniops_load_env() {
  local env_file=$1
  [[ -f "$env_file" && ! -L "$env_file" ]] ||
    miniops_die "Configuration file is missing or unsafe: $env_file" 78
  local owner mode mode_value
  owner=$(miniops_file_owner_id "$env_file")
  mode=$(miniops_file_mode "$env_file")
  [[ "$owner" == 0 || "$owner" == "$EUID" ]] ||
    miniops_die "Configuration owner is not trusted: $env_file" 78
  mode_value=$((8#$mode))
  (( (mode_value & 0022) == 0 )) ||
    miniops_die "Configuration must not be group- or world-writable: $env_file" 78

  local line='' line_number=0 name value quote
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    [[ "$line" =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ ! "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      miniops_die "Invalid configuration syntax at $env_file:$line_number" 78
    fi
    name=${BASH_REMATCH[2]}
    value=${BASH_REMATCH[3]}
    case "$name" in
      MINIOPS_* | RESTIC_* | LAST_BACKUP | SNAPSHOT_COUNT | REPOSITORY_SIZE) ;;
      *) miniops_die "Unsupported configuration variable at $env_file:$line_number" 78 ;;
    esac
    if [[ "$value" == \'* || "$value" == \"* ]]; then
      quote=${value:0:1}
      [[ ${#value} -ge 2 && "${value: -1}" == "$quote" ]] ||
        miniops_die "Unterminated quoted value at $env_file:$line_number" 78
      value=${value:1:${#value}-2}
    elif [[ "$value" =~ [[:space:]] ]]; then
      miniops_die "Unquoted whitespace at $env_file:$line_number" 78
    fi
    printf -v "$name" '%s' "$value"
    export "${name?}"
  done <"$env_file"
}

miniops_file_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}

miniops_file_owner_id() {
  if stat -c '%u' "$1" >/dev/null 2>&1; then
    stat -c '%u' "$1"
  else
    stat -f '%u' "$1"
  fi
}

miniops_validate_secret_file() {
  local secret_file=$1
  miniops_require_absolute_safe_path "$secret_file"
  [[ -s "$secret_file" && ! -L "$secret_file" ]] ||
    miniops_die "Secret file is missing, empty, or a symlink." 78
  local mode owner
  mode=$(miniops_file_mode "$secret_file")
  owner=$(miniops_file_owner_id "$secret_file")
  [[ "$owner" == "$EUID" ]] ||
    miniops_die "Secret file must be owned by the executing account." 78
  [[ "$mode" == 600 || "$mode" == 400 ]] ||
    miniops_die "Secret file must have mode 0600 or 0400." 78
}

miniops_detect_platform() {
  local os_release=${MINIOPS_OS_RELEASE_FILE:-/etc/os-release}
  [[ ${MINIOPS_TEST_PLATFORM:-} == linux || "$(uname -s)" == Linux ]] ||
    miniops_die "MiniOps currently supports Linux only." 69
  [[ -r "$os_release" ]] || miniops_die "Cannot read $os_release" 69
  local ID='' VERSION_ID=''
  # shellcheck disable=SC1090
  source "$os_release"
  case "${ID:-}" in
    ubuntu | debian) ;;
    *)
      [[ ${MINIOPS_ALLOW_UNSUPPORTED:-0} == 1 ]] ||
        miniops_die "Unsupported distribution: ${ID:-unknown}" 69
      ;;
  esac
  printf '%s %s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
}

miniops_require_systemd() {
  if [[ ${MINIOPS_SKIP_SYSTEMD_CHECK:-0} == 1 ]]; then
    return 0
  fi
  [[ -d /run/systemd/system ]] ||
    miniops_die "systemd is not running as PID 1." 69
  miniops_require_command systemctl
}

miniops_acquire_lock() {
  local lock_file=$1
  local wait_seconds=${2:-1}
  miniops_require_command flock
  miniops_require_absolute_safe_path "$lock_file"
  mkdir -p "$(dirname "$lock_file")"
  exec 9>"$lock_file"
  flock -w "$wait_seconds" 9 ||
    miniops_die "Another MiniOps operation holds $lock_file" 75
}

miniops_write_marker() {
  local marker=$1
  miniops_require_absolute_safe_path "$marker"
  miniops_run install -d -o root -g root -m 0755 "$(dirname "$marker")"
  if (( MINIOPS_DRY_RUN )); then
    miniops_quote_command sh -c "date -u > $marker"
    return 0
  fi
  local temporary
  temporary=$(mktemp "$(dirname "$marker")/.marker.XXXXXX")
  miniops_now >"$temporary"
  chmod 0644 "$temporary"
  mv -f -- "$temporary" "$marker"
}
