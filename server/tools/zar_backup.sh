#!/usr/bin/env bash
set -Eeuo pipefail

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 0077

readonly source_db="${ZAR_BACKUP_SOURCE_DB:-/opt/zar/server/pb_data/data.db}"
readonly backup_dir="${ZAR_BACKUP_DIR:-/backups/zar-daily}"
readonly retention_days="${ZAR_BACKUP_RETENTION_DAYS:-30}"
readonly minimum_count="${ZAR_BACKUP_MINIMUM_COUNT:-7}"
readonly lock_file="${ZAR_BACKUP_LOCK_FILE:-/run/lock/zar-backup.lock}"

backup_root=''
temporary_dir=''

fail() {
  printf 'BACKUP_FAILED: %s\n' "$*" >&2
  exit 1
}

safe_remove_staging_dir() {
  local target="$1"
  local name
  local parent

  [[ -n "$backup_root" && -d "$target" && ! -L "$target" ]] || return 0
  name="${target##*/}"
  [[ "$name" =~ ^\.zar-[0-9]{8}T[0-9]{6}Z\.partial\.[0-9]+$ ]] || return 0
  parent="${target%/*}"
  [[ "$(realpath -e -- "$parent")" == "$backup_root" ]] || return 0
  rm -rf --one-file-system -- "$target"
}

cleanup() {
  if [[ -n "$temporary_dir" ]]; then
    safe_remove_staging_dir "$temporary_dir"
  fi
}

trap cleanup EXIT

[[ "$EUID" -eq 0 ]] || fail 'must run as root'
[[ "$retention_days" =~ ^[0-9]+$ ]] || fail 'retention must be a non-negative integer'
[[ "$minimum_count" =~ ^[1-9][0-9]*$ ]] || fail 'minimum count must be a positive integer'
[[ "$source_db" == /* && "$backup_dir" == /* && "$lock_file" == /* ]] || fail 'all paths must be absolute'
[[ -f "$source_db" && ! -L "$source_db" && -s "$source_db" ]] || fail "source is not a non-empty regular database file: $source_db"

for command_name in chmod date find flock install mv realpath rm sha256sum sort sqlite3 stat sync; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing command: $command_name"
done

install -d -m 0700 -- "$backup_dir"
[[ ! -L "$backup_dir" ]] || fail 'backup directory must not be a symlink'
backup_root="$(realpath -e -- "$backup_dir")"
[[ "$(stat -c '%u:%g:%a' "$backup_root")" == '0:0:700' ]] || fail 'backup directory ownership or mode is unsafe'

readonly lock_dir="${lock_file%/*}"
install -d -m 0700 -- "$lock_dir"
exec 9>"$lock_file"
flock -n 9 || fail 'another backup is already running'

while IFS= read -r -d '' stale_staging; do
  safe_remove_staging_dir "$stale_staging"
  printf 'BACKUP_STALE_STAGING_REMOVED path=%s\n' "$stale_staging"
done < <(
  find "$backup_root" -mindepth 1 -maxdepth 1 -type d \
    -regextype posix-extended \
    -regex '.*/\.zar-[0-9]{8}T[0-9]{6}Z\.partial\.[0-9]+' \
    -mmin +1440 -print0
)

readonly timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
readonly snapshot_name="zar-$timestamp"
readonly final_dir="$backup_root/$snapshot_name"
readonly final_path="$final_dir/data.db"
temporary_dir="$backup_root/.$snapshot_name.partial.$$"
readonly temporary_db="$temporary_dir/data.db"
readonly temporary_checksum="$temporary_dir/SHA256SUMS"
readonly temporary_metadata="$temporary_dir/METADATA"

[[ ! -e "$final_dir" && ! -e "$temporary_dir" ]] || fail "backup already exists for timestamp: $timestamp"
install -d -m 0700 -- "$temporary_dir"

sqlite3 -readonly "$source_db" ".timeout 10000" ".backup '$temporary_db'"
chmod 0600 -- "$temporary_db"

readonly immutable_uri="file:$temporary_db?mode=ro&immutable=1"
readonly quick_check="$(sqlite3 "$immutable_uri" 'PRAGMA quick_check;')"
readonly integrity_check="$(sqlite3 "$immutable_uri" 'PRAGMA integrity_check;')"
readonly schema_check="$(sqlite3 "$immutable_uri" "SELECT count(*) FROM sqlite_schema WHERE type='table' AND name IN ('_migrations','users','zar_workspaces');")"

[[ "$quick_check" == 'ok' ]] || fail "quick_check returned: $quick_check"
[[ "$integrity_check" == 'ok' ]] || fail "integrity_check returned: $integrity_check"
[[ "$schema_check" == '3' ]] || fail "required schema table count returned: $schema_check"

readonly checksum_output="$(sha256sum -- "$temporary_db")"
readonly checksum="${checksum_output%% *}"
printf '%s  data.db\n' "$checksum" >"$temporary_checksum"
printf 'created_utc=%s\nsource=%s\nquick_check=%s\nintegrity_check=%s\nrequired_schema_tables=%s\n' \
  "$timestamp" "$source_db" "$quick_check" "$integrity_check" "$schema_check" >"$temporary_metadata"
chmod 0600 -- "$temporary_db" "$temporary_checksum" "$temporary_metadata"
sync -f -- "$temporary_db" "$temporary_checksum" "$temporary_metadata" "$temporary_dir"
mv -- "$temporary_dir" "$final_dir"
temporary_dir=''
sync -f -- "$backup_root"

readonly now_epoch="$(date -u +%s)"
readonly retention_seconds="$((retention_days * 86400))"
mapfile -t snapshots < <(
  find "$backup_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' |
    while IFS= read -r candidate; do
      [[ "$candidate" =~ ^zar-[0-9]{8}T[0-9]{6}Z$ ]] && printf '%s\n' "$candidate"
    done |
    sort
)

snapshot_count="${#snapshots[@]}"
for candidate in "${snapshots[@]}"; do
  (( snapshot_count > minimum_count )) || break
  candidate_path="$backup_root/$candidate"
  [[ -d "$candidate_path" && ! -L "$candidate_path" ]] || continue
  candidate_age="$((now_epoch - $(stat -c '%Y' "$candidate_path")))"
  if (( candidate_age > retention_seconds )); then
    [[ "$(realpath -e -- "${candidate_path%/*}")" == "$backup_root" ]] || fail 'retention path escaped backup root'
    rm -rf --one-file-system -- "$candidate_path"
    printf 'BACKUP_RETENTION_REMOVED path=%s\n' "$candidate_path"
    snapshot_count="$((snapshot_count - 1))"
  fi
done

printf 'BACKUP_OK path=%s sha256=%s size=%s quick_check=%s integrity_check=%s\n' \
  "$final_path" "$checksum" "$(stat -c '%s' "$final_path")" "$quick_check" "$integrity_check"
