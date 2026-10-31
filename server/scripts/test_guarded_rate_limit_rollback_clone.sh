#!/usr/bin/env bash
set -Eeuo pipefail

readonly candidate=1793437200_enable_rate_limits.js
readonly candidate_sha=6dfe631f6e1e65e68060c753f23b700ddc51488623987b6cfc110ebb40af89f2
readonly production_data=/opt/zar/server/pb_data/data.db
readonly production_migrations=/opt/zar/server/pb_migrations
readonly pocketbase=/opt/zar/server/pocketbase
readonly unit=zar-rate-rollback-clone.service
readonly unit_file=/run/systemd/system/$unit
readonly port=18101

if [[ ${1:-} != --confirm-disposable-clone || $# != 4 ]]; then
  echo "usage: $0 --confirm-disposable-clone ROLLBACK_SCRIPT CANDIDATE_MIGRATION EVIDENCE_DIR" >&2
  exit 64
fi

readonly rollback_script=$2
readonly candidate_source=$3
readonly evidence=$4

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 77; }
[[ $rollback_script == /* && -f $rollback_script ]] || exit 64
[[ $candidate_source == /* && -f $candidate_source ]] || exit 64
[[ $evidence == /root/zar-rate-limit-rollback-clone-* ]] || exit 64
[[ ! -e $evidence ]] || { echo "evidence directory already exists" >&2; exit 73; }
test "$(sha256sum "$candidate_source" | awk '{print $1}')" = "$candidate_sha"
systemctl is-active --quiet zar-server
systemctl is-active --quiet caddy
test ! -e "$production_migrations/$candidate"
test "$(sqlite3 -readonly "$production_data" \
  "SELECT count(*) FROM _migrations WHERE file='$candidate';")" = 0
test ! -e "$unit_file"
! systemctl cat "$unit" >/dev/null 2>&1
! ss -H -ltn "sport = :$port" | grep -q .

work_root=$(mktemp -d /opt/zar/server/rate-rollback-clone.XXXXXX)
readonly work_root
readonly data_dir=$work_root/pb_data
readonly migrations_dir=$work_root/pb_migrations
success=0

cleanup() {
  trap - EXIT
  systemctl stop "$unit" >/dev/null 2>&1 || true
  if [[ -f $unit_file ]]; then
    rm -f -- "$unit_file"
    systemctl daemon-reload
  fi
  resolved=$(realpath -m "$work_root")
  if [[ $resolved == /opt/zar/server/rate-rollback-clone.* && -d $resolved ]]; then
    rm -rf -- "$resolved"
  else
    echo "refusing unexpected clone cleanup target: $resolved" >&2
    exit 70
  fi
  if [[ $success != 1 ]]; then
    echo "CLONE_ROLLBACK_TEST_FAILED evidence=$evidence" >&2
  fi
}
trap cleanup EXIT

install -d -o zarapp -g zarapp -m 0700 "$data_dir" "$migrations_dir"
sqlite3 "$production_data" ".backup '$data_dir/data.db'"
if [[ -f /opt/zar/server/pb_data/auxiliary.db ]]; then
  sqlite3 /opt/zar/server/pb_data/auxiliary.db \
    ".backup '$data_dir/auxiliary.db'"
fi
cp -a "$production_migrations/." "$migrations_dir/"
install -o zarapp -g zarapp -m 0600 "$candidate_source" \
  "$migrations_dir/$candidate"
chown -R zarapp:zarapp "$work_root"
chmod 0700 "$work_root" "$data_dir" "$migrations_dir"

install -d -o root -g root -m 0700 "$evidence"
sqlite3 -readonly "$data_dir/data.db" \
  "SELECT json_extract(value, '$.rateLimits') FROM _params WHERE id='settings';" \
  > "$evidence/rate-limits.before.json"
sqlite3 -readonly "$data_dir/data.db" \
  "SELECT 'zar_workspaces|'||count(*) FROM zar_workspaces
   UNION ALL SELECT 'zar_people|'||count(*) FROM zar_people
   UNION ALL SELECT 'zar_deals|'||count(*) FROM zar_deals
   UNION ALL SELECT 'zar_settlements|'||count(*) FROM zar_settlements
   UNION ALL SELECT 'zar_coin_types|'||count(*) FROM zar_coin_types
   UNION ALL SELECT 'zar_currency_types|'||count(*) FROM zar_currency_types
   UNION ALL SELECT 'zar_allocations|'||count(*) FROM zar_allocations
   UNION ALL SELECT 'zar_cash_entries|'||count(*) FROM zar_cash_entries;" \
  > "$evidence/domain-counts.before.txt"
sqlite3 -readonly "$data_dir/data.db" \
  "SELECT file FROM _migrations ORDER BY file;" \
  > "$evidence/migrations.before.txt"
sha256sum "$migrations_dir/$candidate" > "$evidence/migration.sha256"
sha256sum "$data_dir/data.db" "$data_dir/auxiliary.db" \
  > "$evidence/clone-data.before.sha256"
sha256sum "$rollback_script" > "$evidence/rollback-script.sha256"

(
  cd /opt/zar/server
  runuser -u zarapp -- "$pocketbase" migrate up \
    --dir="$data_dir" \
    --migrationsDir="$migrations_dir"
)

printf '%s\n' \
  '[Unit]' \
  'Description=Disposable ZAR rate-limit rollback clone' \
  'After=network.target' \
  '' \
  '[Service]' \
  'Type=simple' \
  'User=zarapp' \
  'Group=zarapp' \
  "ExecStart=$pocketbase serve --http=127.0.0.1:$port --dir=$data_dir --migrationsDir=$migrations_dir" \
  'Restart=no' \
  '' \
  '[Install]' \
  'WantedBy=multi-user.target' \
  > "$unit_file"
chmod 0644 "$unit_file"
systemctl daemon-reload
systemctl start "$unit"
for _ in $(seq 1 100); do
  if curl -fsS "http://127.0.0.1:$port/api/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
curl -fsS "http://127.0.0.1:$port/api/health" >/dev/null
systemctl show "$unit" -p NRestarts --value > "$evidence/nrestarts.before.txt"

bash "$rollback_script" \
  --data-dir "$data_dir" \
  --migrations-dir "$migrations_dir" \
  --service "$unit" \
  --evidence "$evidence" \
  --health-url "http://127.0.0.1:$port/api/health"

test -f "$evidence/rollback-result.txt"
grep -qx RATE_LIMIT_ROLLBACK_PASS "$evidence/rollback-result.txt"
test ! -e "$migrations_dir/$candidate"
test "$(sqlite3 -readonly "$data_dir/data.db" \
  "SELECT count(*) FROM _migrations WHERE file='$candidate';")" = 0
test "$(sqlite3 -readonly "$data_dir/data.db" 'PRAGMA integrity_check;')" = ok
test ! -e "$production_migrations/$candidate"
test "$(sqlite3 -readonly "$production_data" \
  "SELECT count(*) FROM _migrations WHERE file='$candidate';")" = 0
systemctl is-active --quiet zar-server
systemctl is-active --quiet caddy
printf 'production_candidate_history=0\nproduction_candidate_file=absent\n' \
  > "$evidence/production-unchanged.txt"

success=1
echo "CLONE_ROLLBACK_TEST_PASS evidence=$evidence"
