#!/usr/bin/env bash
set -Eeuo pipefail

# Immediate rollback for 1793437200_enable_rate_limits.js only. There are no
# defaults: every target must be explicit so the same guarded path can be
# exercised against a disposable clone before its production invocation.

readonly migration=1793437200_enable_rate_limits.js
readonly expected_migration_sha=6dfe631f6e1e65e68060c753f23b700ddc51488623987b6cfc110ebb40af89f2
readonly expected_baseline_settings_sha=8ebf08d019320f87f58a9d7f944cf28fe42d7c7fd43b3626e760e506d3266c37
readonly expected_deployed_settings_sha=fe9623ed0ba238dc534f5aab00bb98f4df8528686586958ad3011597b312c8a2
readonly pocketbase=/opt/zar/server/pocketbase
readonly expected_pocketbase_sha=14ec215bc7aaceda356713cd4b29aa7fcfee854ff2ae1151c5ddba41b43aec8a

data_dir=
migrations_dir=
service=
evidence=
admin_url=
health_urls=()

usage() {
  cat >&2 <<'USAGE'
Usage: guarded_rate_limit_rollback.sh \
  --data-dir ABSOLUTE_PATH \
  --migrations-dir ABSOLUTE_PATH \
  --service SYSTEMD_UNIT \
  --evidence ABSOLUTE_PATH \
  --health-url URL [--health-url URL ...] \
  [--admin-url URL_EXPECTED_TO_RETURN_404]
USAGE
  exit 64
}

while (($#)); do
  case "$1" in
    --data-dir)
      (($# >= 2)) || usage
      data_dir=$2
      shift 2
      ;;
    --migrations-dir)
      (($# >= 2)) || usage
      migrations_dir=$2
      shift 2
      ;;
    --service)
      (($# >= 2)) || usage
      service=$2
      shift 2
      ;;
    --evidence)
      (($# >= 2)) || usage
      evidence=$2
      shift 2
      ;;
    --health-url)
      (($# >= 2)) || usage
      health_urls+=("$2")
      shift 2
      ;;
    --admin-url)
      (($# >= 2)) || usage
      admin_url=$2
      shift 2
      ;;
    *) usage ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 77; }
[[ $data_dir == /opt/zar/server/* ]] || usage
[[ $migrations_dir == /opt/zar/server/* ]] || usage
[[ $evidence == /* && $evidence != / ]] || usage
[[ $service == zar-*.service ]] || usage
((${#health_urls[@]} > 0)) || usage
[[ $(realpath -m "$data_dir") == "$data_dir" ]] || usage
[[ $(realpath -m "$migrations_dir") == "$migrations_dir" ]] || usage
[[ $(realpath -m "$evidence") == "$evidence" ]] || usage

readonly db=$data_dir/data.db
readonly auxiliary_db=$data_dir/auxiliary.db
readonly migration_path=$migrations_dir/$migration
readonly started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
stopped=0

settings_json() {
  sqlite3 -readonly "$db" \
    "SELECT json_extract(value, '$.rateLimits') FROM _params WHERE id='settings';"
}

settings_sha() {
  settings_json | sha256sum | awk '{print $1}'
}

migration_count() {
  sqlite3 -readonly "$db" \
    "SELECT count(*) FROM _migrations WHERE file='$migration';"
}

latest_migration() {
  sqlite3 -readonly "$db" \
    "SELECT file FROM _migrations
     ORDER BY substr(applied||'0000000000000000',0,17) DESC, file DESC
     LIMIT 1;"
}

migrations_list() {
  sqlite3 -readonly "$db" "SELECT file FROM _migrations ORDER BY file;"
}

domain_counts() {
  sqlite3 -readonly "$db" \
    "SELECT 'zar_workspaces|'||count(*) FROM zar_workspaces
     UNION ALL SELECT 'zar_people|'||count(*) FROM zar_people
     UNION ALL SELECT 'zar_deals|'||count(*) FROM zar_deals
     UNION ALL SELECT 'zar_settlements|'||count(*) FROM zar_settlements
     UNION ALL SELECT 'zar_coin_types|'||count(*) FROM zar_coin_types
     UNION ALL SELECT 'zar_currency_types|'||count(*) FROM zar_currency_types
     UNION ALL SELECT 'zar_allocations|'||count(*) FROM zar_allocations
     UNION ALL SELECT 'zar_cash_entries|'||count(*) FROM zar_cash_entries;"
}

start_and_wait() {
  systemctl start "$service"
  for _ in $(seq 1 100); do
    if curl -fsS "${health_urls[0]}" >/dev/null 2>&1; then
      stopped=0
      return 0
    fi
    sleep 0.1
  done
  echo "service did not return to health" >&2
  return 1
}

restart_on_error() {
  rc=$?
  failed_command=$BASH_COMMAND
  failed_line=${BASH_LINENO[0]:-unknown}
  trap - ERR
  set +e
  printf 'rc=%s\nline=%s\ncommand=%s\n' \
    "$rc" "$failed_line" "$failed_command" > "$evidence/rollback-failure.txt"
  if [[ $stopped == 1 ]]; then
    count=$(migration_count 2>/dev/null || true)
    live_settings_sha=$(settings_sha 2>/dev/null || true)
    if [[ $count == 0 && $live_settings_sha == "$expected_baseline_settings_sha" ]]; then
      if [[ -f $migration_path ]]; then
        file_sha=$(sha256sum "$migration_path" | awk '{print $1}')
        if [[ $file_sha == "$expected_migration_sha" ]]; then
          mv -- "$migration_path" "$evidence/migration.removed-after-error.js"
        else
          echo "rollback failed after down and migration file hash drifted; service remains stopped" >&2
          exit "$rc"
        fi
      fi
      start_and_wait || true
    elif [[ $count == 1 && $live_settings_sha == "$expected_deployed_settings_sha" ]]; then
      start_and_wait || true
    else
      echo "ambiguous rollback state; service remains stopped for operator investigation" >&2
    fi
  fi
  echo "RATE_LIMIT_ROLLBACK_FAILED rc=$rc" >&2
  exit "$rc"
}
trap restart_on_error ERR

# Immutable evidence and live-state guards before stopping traffic.
test -d "$evidence"
test "$(stat -c '%U:%G:%a' "$evidence")" = root:root:700
test -f "$evidence/rate-limits.before.json"
test -f "$evidence/domain-counts.before.txt"
test -f "$evidence/migrations.before.txt"
test -f "$evidence/nrestarts.before.txt"
test -f "$evidence/migration.sha256"
test -f "$auxiliary_db"
test "$(sha256sum "$evidence/rate-limits.before.json" | awk '{print $1}')" = \
  "$expected_baseline_settings_sha"
test "$(awk 'NR==1 {print $1}' "$evidence/migration.sha256")" = \
  "$expected_migration_sha"
test "$(sha256sum "$migration_path" | awk '{print $1}')" = \
  "$expected_migration_sha"
test "$(sha256sum "$pocketbase" | awk '{print $1}')" = \
  "$expected_pocketbase_sha"
test "$(settings_sha)" = "$expected_deployed_settings_sha"
test "$(migration_count)" = 1
test "$(latest_migration)" = "$migration"
migrations_list | grep -Fvx "$migration" > \
  "$evidence/migrations.pre-rollback-minus-candidate.txt"
cmp -s "$evidence/migrations.before.txt" \
  "$evidence/migrations.pre-rollback-minus-candidate.txt"
systemctl is-active --quiet "$service"
systemctl is-active --quiet caddy
test "$(systemctl show "$service" -p User --value)" = zarapp
test "$(systemctl show "$service" -p Group --value)" = zarapp
service_exec=$(systemctl show "$service" -p ExecStart --value)
[[ $service_exec == *"path=$pocketbase"* ]]
[[ $service_exec == *"argv[]=$pocketbase serve "* ]]
if [[ $service == zar-server.service ]]; then
  test "$data_dir" = /opt/zar/server/pb_data
  test "$migrations_dir" = /opt/zar/server/pb_migrations
  test "$(systemctl show "$service" -p WorkingDirectory --value)" = \
    /opt/zar/server
  [[ $service_exec == *"--http=127.0.0.1:8090"* ]]
else
  [[ $service_exec == *"--dir=$data_dir"* ]]
  [[ $service_exec == *"--migrationsDir=$migrations_dir"* ]]
fi

install -o root -g root -m 0600 "$migration_path" \
  "$evidence/migration.before-rollback.js"
test "$(sha256sum "$evidence/migration.before-rollback.js" | awk '{print $1}')" = \
  "$expected_migration_sha"

stopped=1
systemctl show "$service" -p NRestarts --value > \
  "$evidence/nrestarts.rollback-start.txt"
systemctl stop "$service"

# Recheck after traffic is stopped; never overwrite an intervening edit.
test "$(settings_sha)" = "$expected_deployed_settings_sha"
test "$(migration_count)" = 1
test "$(latest_migration)" = "$migration"
test "$(sha256sum "$migration_path" | awk '{print $1}')" = \
  "$expected_migration_sha"
domain_counts > "$evidence/domain-counts.rollback-stop.txt"

(
  cd /opt/zar/server
  printf 'y\n' | runuser -u zarapp -- "$pocketbase" migrate down 1 \
    --dir="$data_dir" \
    --migrationsDir="$migrations_dir"
)

test "$(migration_count)" = 0
latest_migration > "$evidence/latest-migration.after-down.txt"
migrations_list > "$evidence/migrations.after-down.txt"
cmp -s "$evidence/migrations.before.txt" "$evidence/migrations.after-down.txt"
test "$(settings_sha)" = "$expected_baseline_settings_sha"
rm -f -- "$migration_path"

start_and_wait

settings_json > "$evidence/rate-limits.after-rollback.json"
migrations_list > "$evidence/migrations.after-rollback.txt"
domain_counts > "$evidence/domain-counts.after-rollback.txt"
systemctl show "$service" -p NRestarts --value > "$evidence/nrestarts.after-rollback.txt"

cmp -s "$evidence/rate-limits.before.json" \
  "$evidence/rate-limits.after-rollback.json"
cmp -s "$evidence/migrations.before.txt" \
  "$evidence/migrations.after-rollback.txt"
cmp -s "$evidence/domain-counts.rollback-stop.txt" \
  "$evidence/domain-counts.after-rollback.txt"
cmp -s "$evidence/nrestarts.rollback-start.txt" \
  "$evidence/nrestarts.after-rollback.txt"
test "$(sqlite3 -readonly "$db" 'PRAGMA quick_check;')" = ok
test "$(sqlite3 -readonly "$db" 'PRAGMA integrity_check;')" = ok
test "$(sqlite3 -readonly "$auxiliary_db" 'PRAGMA quick_check;')" = ok
test "$(sqlite3 -readonly "$auxiliary_db" 'PRAGMA integrity_check;')" = ok
test "$(sha256sum "$pocketbase" | awk '{print $1}')" = \
  "$expected_pocketbase_sha"
systemctl is-active --quiet "$service"
systemctl is-active --quiet caddy

for url in "${health_urls[@]}"; do
  curl -fsS "$url" >/dev/null
done

if [[ -n $admin_url ]]; then
  test "$(curl -sS -o /dev/null -w '%{http_code}' "$admin_url")" = 404
fi

journalctl -q -u "$service" -p err --since "$started_utc" --no-pager > \
  "$evidence/rollback-error-journal.txt"
test ! -s "$evidence/rollback-error-journal.txt"
printf 'data_quick_check=ok\ndata_integrity_check=ok\nauxiliary_quick_check=ok\nauxiliary_integrity_check=ok\n' > \
  "$evidence/rollback-integrity.txt"
printf 'RATE_LIMIT_ROLLBACK_PASS\n' | tee "$evidence/rollback-result.txt"
