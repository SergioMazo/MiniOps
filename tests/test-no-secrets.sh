#!/usr/bin/env bash
set -Eeuo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$TEST_DIR/.." && pwd)
cd "$PROJECT_ROOT"

forbidden=(
  "Auro""ra"
  "Maxi""con"
  "Open""Claw"
  "Zo""ho"
  "sergio""mazo"
  "auro""ra-infra"
  "auro""ra-backup"
  "100.""111."
  "100.""104."
  "100.""71."
  "192.""168.50."
)
private_markers=(
  "BEGIN OPENSSH"" PRIVATE KEY"
  "BEGIN RSA"" PRIVATE KEY"
  "BEGIN EC"" PRIVATE KEY"
)

mapfile_path=$(mktemp)
history_path=$(mktemp)
trap 'rm -f -- "$mapfile_path" "$history_path"' EXIT
git ls-files --cached --others --exclude-standard -z >"$mapfile_path"

while IFS= read -r -d '' path; do
  [[ "$path" != .git/* ]] || continue
  [[ ! -L "$path" ]] || {
    printf 'Symlink is not allowed: %s\n' "$path" >&2
    exit 1
  }
  size=$(wc -c <"$path" | tr -d ' ')
  (( size <= 1048576 )) || {
    printf 'Unexpected large file: %s\n' "$path" >&2
    exit 1
  }
  case "$path" in
    *.env)
      printf 'Live .env file is not allowed: %s\n' "$path" >&2
      exit 1
      ;;
    *authorized_keys | *known_hosts | id_* | *.pem | *.p12 | *.pfx)
      printf 'Credential-like filename is not allowed: %s\n' "$path" >&2
      exit 1
      ;;
  esac
done <"$mapfile_path"

for pattern in "${forbidden[@]}" "${private_markers[@]}"; do
  while IFS= read -r -d '' path; do
    if grep -I -F -i -q -- "$pattern" "$path"; then
      printf 'Forbidden content detected in %s.\n' "$path" >&2
      exit 1
    fi
  done <"$mapfile_path"
done

while IFS= read -r -d '' path; do
  if grep -I -E -i -q \
    '(password|passwd|token|secret)[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9+/_.-]{12,}' \
    "$path"; then
    printf 'Possible hard-coded credential detected in %s.\n' "$path" >&2
    exit 1
  fi
done <"$mapfile_path"

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git log -p --all --no-ext-diff >"$history_path"
  for pattern in "${forbidden[@]}" "${private_markers[@]}"; do
    if grep -F -i -q -- "$pattern" "$history_path"; then
      printf 'Forbidden content detected in Git history.\n' >&2
      exit 1
    fi
  done
fi

printf 'Secret and privacy scan: clean\n'
