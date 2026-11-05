#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Destructive operations in this rehearsal are restricted to one disposable
# /opt/zar/server/restore-clone.* tree and one explicitly named /run systemd
# unit. Production is read-only throughout.

confirm_disposable=0
deploy_script=
rollback_script=
contain_script=
migration_source=
helper_source=
route_source=
state_tool=
state_guard=
expected_manifest=
canary=
production_data_dir=
production_migrations_dir=
production_hooks_dir=
production_overlay_target=
pocketbase=
production_service=
production_health_url=
clone_unit=
clone_port=
evidence=

usage() {
  cat >&2 <<'USAGE'
Usage: test_guarded_transactional_restore_clone.sh \
  --confirm-disposable-clone \
  --deploy-script ABSOLUTE_FILE \
  --rollback-script ABSOLUTE_FILE \
  --contain-script ABSOLUTE_FILE \
  --migration-source ABSOLUTE_FILE \
  --helper-source ABSOLUTE_FILE \
  --route-source ABSOLUTE_FILE \
  --state-tool ABSOLUTE_FILE \
  --state-guard ABSOLUTE_FILE \
  --expected-manifest ABSOLUTE_FILE \
  --canary ABSOLUTE_FILE \
  --production-data-dir /opt/zar/server/pb_data \
  --production-migrations-dir /opt/zar/server/pb_migrations \
  --production-hooks-dir /opt/zar/server/pb_hooks \
  --production-overlay-target /etc/systemd/system/zar-server.service.d/20-transactional-restore.conf \
  --pocketbase /opt/zar/server/pocketbase \
  --production-service zar-server.service \
  --production-health-url http://127.0.0.1:8090/api/health \
  --clone-unit zar-restore-clone-UNIQUE.service \
  --clone-port UNIQUE_LOOPBACK_PORT \
  --evidence /root/zar-transactional-restore-clone-UNIQUE

The evidence path, clone unit, and clone port must not already exist or be in
use. This script never installs anything into the production data, migration,
hook, or systemd-overlay paths.
USAGE
  exit 64
}

while (($#)); do
  case "$1" in
    --confirm-disposable-clone) confirm_disposable=1; shift ;;
    --deploy-script) deploy_script=${2:-}; shift 2 ;;
    --rollback-script) rollback_script=${2:-}; shift 2 ;;
    --contain-script) contain_script=${2:-}; shift 2 ;;
    --migration-source) migration_source=${2:-}; shift 2 ;;
    --helper-source) helper_source=${2:-}; shift 2 ;;
    --route-source) route_source=${2:-}; shift 2 ;;
    --state-tool) state_tool=${2:-}; shift 2 ;;
    --state-guard) state_guard=${2:-}; shift 2 ;;
    --expected-manifest) expected_manifest=${2:-}; shift 2 ;;
    --canary) canary=${2:-}; shift 2 ;;
    --production-data-dir) production_data_dir=${2:-}; shift 2 ;;
    --production-migrations-dir) production_migrations_dir=${2:-}; shift 2 ;;
    --production-hooks-dir) production_hooks_dir=${2:-}; shift 2 ;;
    --production-overlay-target) production_overlay_target=${2:-}; shift 2 ;;
    --pocketbase) pocketbase=${2:-}; shift 2 ;;
    --production-service) production_service=${2:-}; shift 2 ;;
    --production-health-url) production_health_url=${2:-}; shift 2 ;;
    --clone-unit) clone_unit=${2:-}; shift 2 ;;
    --clone-port) clone_port=${2:-}; shift 2 ;;
    --evidence) evidence=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done

die() {
  echo "TRANSACTIONAL_RESTORE_CLONE_REHEARSAL_ERROR: $*" >&2
  exit 1
}

assert_root_trusted_file() {
  local file=$1 current mode
  [[ -f $file && ! -L $file ]] || return 1
  [[ $(stat -c '%u:%g' "$file") == 0:0 ]] || return 1
  mode=$(stat -c '%a' "$file")
  (( (8#$mode & 022) == 0 )) || return 1
  current=$(dirname -- "$file")
  while :; do
    [[ -d $current && ! -L $current ]] || return 1
    [[ $(stat -c '%u:%g' "$current") == 0:0 ]] || return 1
    mode=$(stat -c '%a' "$current")
    (( (8#$mode & 022) == 0 )) || return 1
    [[ $current == / ]] && break
    current=$(dirname -- "$current")
  done
}

[[ $confirm_disposable == 1 ]] || usage
[[ $EUID -eq 0 ]] || { echo 'must run as root' >&2; exit 77; }

for command in bash python3 sqlite3 curl systemctl systemd-analyze ss setsid \
  sha256sum realpath runuser install find stat cmp awk grep flock; do
  command -v "$command" >/dev/null || die "required command is missing: $command"
done

for path in "$deploy_script" "$rollback_script" "$contain_script" \
  "$migration_source" "$helper_source" "$route_source" "$state_tool" \
  "$state_guard" "$expected_manifest" "$canary" "$pocketbase"; do
  [[ $path == /* && $path != / ]] || usage
  [[ $(realpath -m -- "$path") == "$path" ]] || usage
  [[ $path != *"'"* && $path != *$'\n'* ]] || usage
  assert_root_trusted_file "$path" || usage
done

for path in "$production_data_dir" "$production_migrations_dir" \
  "$production_hooks_dir" "$production_overlay_target" "$evidence"; do
  [[ $path == /* && $path != / ]] || usage
  [[ $(realpath -m -- "$path") == "$path" ]] || usage
  [[ $path != *"'"* && $path != *$'\n'* ]] || usage
done

# These exact production targets keep a typo or caller-supplied alternate tree
# from widening the read-only production scope of the rehearsal.
[[ $production_data_dir == /opt/zar/server/pb_data ]] || usage
[[ $production_migrations_dir == /opt/zar/server/pb_migrations ]] || usage
[[ $production_hooks_dir == /opt/zar/server/pb_hooks ]] || usage
[[ $production_overlay_target == /etc/systemd/system/zar-server.service.d/20-transactional-restore.conf ]] || usage
[[ $pocketbase == /opt/zar/server/pocketbase ]] || usage
[[ $production_service == zar-server.service ]] || usage
[[ $production_health_url == http://127.0.0.1:8090/api/health ]] || usage
[[ $evidence =~ ^/root/zar-transactional-restore-clone-[A-Za-z0-9._-]+$ ]] || usage
[[ ! -e $evidence && ! -L $evidence ]] || { echo 'evidence path already exists' >&2; exit 73; }

[[ $clone_unit =~ ^zar-restore-clone-[A-Za-z0-9][A-Za-z0-9_.-]*\.service$ ]] || usage
[[ $clone_port =~ ^[0-9]+$ ]] || usage
((clone_port >= 1024 && clone_port <= 65535 && clone_port != 8090)) || usage

readonly unit_file=/run/systemd/system/$clone_unit
readonly unit_dropin_dir=/run/systemd/system/$clone_unit.d
readonly overlay_target=$unit_dropin_dir/20-transactional-restore.conf
readonly clone_health_url=http://127.0.0.1:$clone_port/api/health
readonly clone_base_url=http://127.0.0.1:$clone_port
[[ $unit_file == /run/systemd/system/zar-restore-clone-*.service ]] || usage
[[ $overlay_target == /run/systemd/system/zar-restore-clone-*.service.d/20-transactional-restore.conf ]] || usage
[[ ! -e $unit_file && ! -L $unit_file ]] || { echo 'clone unit path already exists' >&2; exit 73; }
[[ ! -e $unit_dropin_dir && ! -L $unit_dropin_dir ]] || { echo 'clone drop-in path already exists' >&2; exit 73; }
! systemctl cat "$clone_unit" >/dev/null 2>&1 || { echo 'clone unit is already loaded' >&2; exit 73; }
! ss -H -ltn "sport = :$clone_port" | grep -q . || { echo 'clone port is already in use' >&2; exit 73; }

json_get() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

value = json.load(open(sys.argv[1], encoding="utf-8"))
for part in sys.argv[2].split("."):
    value = value[part]
if not isinstance(value, (str, int, float, bool)) and value is not None:
    raise SystemExit(1)
print(str(value).lower() if isinstance(value, bool) else value)
PY
}

readonly migration_name=$(json_get "$expected_manifest" artifacts.migration.name)
readonly migration_sha=$(json_get "$expected_manifest" artifacts.migration.sha256)
readonly helper_name=$(json_get "$expected_manifest" artifacts.helperHook.name)
readonly helper_sha=$(json_get "$expected_manifest" artifacts.helperHook.sha256)
readonly route_name=$(json_get "$expected_manifest" artifacts.routeHook.name)
readonly route_sha=$(json_get "$expected_manifest" artifacts.routeHook.sha256)
readonly state_tool_name=$(json_get "$expected_manifest" artifacts.stateTool.name)
readonly state_tool_sha=$(json_get "$expected_manifest" artifacts.stateTool.sha256)
readonly state_guard_name=$(json_get "$expected_manifest" artifacts.stateGuard.name)
readonly state_guard_sha=$(json_get "$expected_manifest" artifacts.stateGuard.sha256)
readonly canary_name=$(json_get "$expected_manifest" artifacts.canary.name)
readonly canary_sha=$(json_get "$expected_manifest" artifacts.canary.sha256)
readonly pocketbase_sha=$(json_get "$expected_manifest" pocketBaseSha256)
[[ $migration_name =~ ^[A-Za-z0-9_.-]+$ ]] || die 'invalid migration name in manifest'
[[ $helper_name =~ ^[A-Za-z0-9_.-]+$ ]] || die 'invalid helper name in manifest'
[[ $route_name =~ ^[A-Za-z0-9_.-]+$ ]] || die 'invalid route name in manifest'
[[ $(basename -- "$migration_source") == "$migration_name" ]] || die 'migration source name differs from manifest'
[[ $(basename -- "$helper_source") == "$helper_name" ]] || die 'helper source name differs from manifest'
[[ $(basename -- "$route_source") == "$route_name" ]] || die 'route source name differs from manifest'
[[ $(basename -- "$state_tool") == "$state_tool_name" ]] || die 'state tool name differs from manifest'
[[ $(basename -- "$state_guard") == "$state_guard_name" ]] || die 'state guard name differs from manifest'
[[ $(basename -- "$canary") == "$canary_name" ]] || die 'canary name differs from manifest'
[[ $(sha256sum "$migration_source" | awk '{print $1}') == "$migration_sha" ]] || die 'migration source hash differs from manifest'
[[ $(sha256sum "$helper_source" | awk '{print $1}') == "$helper_sha" ]] || die 'helper source hash differs from manifest'
[[ $(sha256sum "$route_source" | awk '{print $1}') == "$route_sha" ]] || die 'route source hash differs from manifest'
[[ $(sha256sum "$state_tool" | awk '{print $1}') == "$state_tool_sha" ]] || die 'state tool hash differs from manifest'
[[ $(sha256sum "$state_guard" | awk '{print $1}') == "$state_guard_sha" ]] || die 'state guard hash differs from manifest'
[[ $(sha256sum "$canary" | awk '{print $1}') == "$canary_sha" ]] || die 'canary hash differs from manifest'
[[ $(sha256sum "$pocketbase" | awk '{print $1}') == "$pocketbase_sha" ]] || die 'PocketBase hash differs from manifest'

readonly production_db=$production_data_dir/data.db
readonly production_auxiliary=$production_data_dir/auxiliary.db
[[ -f $production_db && ! -L $production_db ]] || die 'production data.db is missing or a symlink'
[[ -f $production_auxiliary && ! -L $production_auxiliary ]] || die 'production auxiliary.db is missing or a symlink'
[[ -d $production_migrations_dir && ! -L $production_migrations_dir ]] || die 'production migrations directory is invalid'

work_root=
private_canary_state=
async_child_pid=
unit_owned=0
success=0

safe_remove_unit_paths() {
  [[ $unit_owned == 1 ]] || return 0
  [[ $(realpath -m -- "$unit_file") == /run/systemd/system/zar-restore-clone-*.service ]] || return 70
  [[ $(realpath -m -- "$unit_dropin_dir") == /run/systemd/system/zar-restore-clone-*.service.d ]] || return 70
  ! systemctl is-active --quiet "$clone_unit" || return 70
  ! ss -H -ltn "sport = :$clone_port" | grep -q . || return 70
  if [[ -e $overlay_target || -L $overlay_target ]]; then
    rm -f -- "$overlay_target"
  fi
  if [[ -d $unit_dropin_dir && ! -L $unit_dropin_dir ]]; then
    rmdir --ignore-fail-on-non-empty "$unit_dropin_dir"
  fi
  if [[ -e $unit_file || -L $unit_file ]]; then
    rm -f -- "$unit_file"
  fi
  systemctl daemon-reload
  unit_owned=0
}

cleanup() {
  local rc=$?
  local clone_stopped=1
  trap - EXIT HUP INT TERM
  set +e
  if [[ $async_child_pid =~ ^[0-9]+$ ]]; then
    kill -TERM -- "-$async_child_pid" >/dev/null 2>&1 || true
    wait "$async_child_pid" >/dev/null 2>&1 || true
    async_child_pid=
  fi
  if [[ -n $private_canary_state && -n $work_root && \
        $(realpath -m -- "$private_canary_state") == "$work_root"/* ]]; then
    rm -f -- "$private_canary_state"
  fi
  if [[ $unit_owned == 1 ]]; then
    if ! systemctl stop "$clone_unit" >/dev/null 2>&1 || \
       systemctl is-active --quiet "$clone_unit" || \
       ss -H -ltn "sport = :$clone_port" | grep -q .; then
      clone_stopped=0
      rc=70
      echo 'clone stop could not be verified; preserving unit and clone tree' >&2
    else
      if ! safe_remove_unit_paths >/dev/null 2>&1; then
        clone_stopped=0
        rc=70
        echo 'clone unit cleanup failed; preserving clone tree' >&2
      fi
    fi
  fi
  if [[ -n $work_root ]]; then
    local resolved
    resolved=$(realpath -m -- "$work_root")
    if [[ $clone_stopped == 1 && $resolved == "$work_root" && \
          $resolved == /opt/zar/server/restore-clone.* && \
          -d $resolved && ! -L $resolved ]]; then
      rm -rf -- "$resolved"
    else
      echo "preserving unsafe or active clone cleanup target: $resolved" >&2
      rc=70
    fi
  fi
  if [[ $success != 1 ]]; then
    echo "TRANSACTIONAL_RESTORE_CLONE_REHEARSAL_FAILED evidence=$evidence" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT HUP INT TERM

install -d -o root -g root -m 0700 "$evidence"
install -d -o root -g root -m 0700 "$evidence/cases"
work_root=$(mktemp -d /opt/zar/server/restore-clone.XXXXXX)
readonly work_root
chown root:root "$work_root"
chmod 0755 "$work_root"
readonly pristine_dir=$work_root/pristine
readonly pristine_data_dir=$pristine_dir/pb_data
readonly pristine_migrations_dir=$pristine_dir/pb_migrations
install -d -o root -g root -m 0700 "$pristine_dir" "$pristine_data_dir"
install -d -o root -g root -m 0755 "$pristine_migrations_dir"

snapshot_state() {
  local source_data_dir=$1 output=$2
  local data_copy=$work_root/.snapshot-data.$$.db
  local auxiliary_copy=$work_root/.snapshot-auxiliary.$$.db
  rm -f -- "$data_copy" "$auxiliary_copy"
  sqlite3 -readonly "$source_data_dir/data.db" ".timeout 5000" ".backup '$data_copy'"
  sqlite3 -readonly "$source_data_dir/auxiliary.db" ".timeout 5000" ".backup '$auxiliary_copy'"
  python3 "$state_tool" --database "$data_copy" --auxiliary "$auxiliary_copy" > "$output"
  chmod 0600 "$output"
  rm -f -- "$data_copy" "$auxiliary_copy"
}

guard_state() {
  local state=$1 profile=$2 baseline=$3 receipt_count=$4
  python3 "$state_guard" --state "$state" --expected "$expected_manifest" \
    --profile "$profile" --baseline "$baseline" \
    --expected-receipt-count "$receipt_count"
}

guard_state_without_baseline() {
  local state=$1 profile=$2 receipt_count=$3
  python3 "$state_guard" --state "$state" --expected "$expected_manifest" \
    --profile "$profile" --expected-receipt-count "$receipt_count"
}

wait_for_health() {
  local url=$1
  for _ in $(seq 1 200); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

assert_production_artifacts_absent() {
  test ! -e "$production_migrations_dir/$migration_name"
  test ! -L "$production_migrations_dir/$migration_name"
  test ! -e "$production_hooks_dir/$helper_name"
  test ! -L "$production_hooks_dir/$helper_name"
  test ! -e "$production_hooks_dir/$route_name"
  test ! -L "$production_hooks_dir/$route_name"
  test ! -e "$production_overlay_target"
  test ! -L "$production_overlay_target"
  test "$(sqlite3 -readonly "$production_db" \
    "SELECT count(*) FROM _migrations WHERE file='$migration_name';")" = 0
}

capture_production_state() {
  local output=$1
  systemctl is-active --quiet "$production_service"
  systemctl is-active --quiet caddy
  curl -fsS "$production_health_url" >/dev/null
  assert_production_artifacts_absent
  snapshot_state "$production_data_dir" "$output"
  python3 "$state_guard" --state "$output" --expected "$expected_manifest" \
    --profile before --expected-receipt-count 0
}

# Preflight is read-only. Active databases are never handed to the immutable
# state reader; it receives only SQLite .backup outputs without WAL sidecars.
systemctl is-active --quiet "$production_service"
systemctl is-active --quiet caddy
curl -fsS "$production_health_url" >/dev/null
assert_production_artifacts_absent

# Create the one production-derived source snapshot. Every case below is made
# only from these two .backup outputs and this immutable migration copy.
sqlite3 -readonly "$production_db" ".timeout 5000" ".backup '$pristine_data_dir/data.db'"
sqlite3 -readonly "$production_auxiliary" ".timeout 5000" ".backup '$pristine_data_dir/auxiliary.db'"
chmod 0600 "$pristine_data_dir/data.db" "$pristine_data_dir/auxiliary.db"
cp -a "$production_migrations_dir/." "$pristine_migrations_dir/"
if find "$pristine_migrations_dir" -type l -print -quit | grep -q .; then
  die 'production migration snapshot contains a symlink'
fi
chown -R root:root "$pristine_migrations_dir"
find "$pristine_migrations_dir" -type d -exec chmod 0755 {} +
find "$pristine_migrations_dir" -type f -exec chmod 0644 {} +
assert_production_artifacts_absent

readonly baseline_state=$evidence/baseline-state.json
python3 "$state_tool" --database "$pristine_data_dir/data.db" \
  --auxiliary "$pristine_data_dir/auxiliary.db" > "$baseline_state"
chmod 0600 "$baseline_state"
python3 "$state_guard" --state "$baseline_state" --expected "$expected_manifest" \
  --profile before --expected-receipt-count 0
readonly production_preflight_state=$evidence/production-preflight-state.json
install -o root -g root -m 0600 "$baseline_state" "$production_preflight_state"
systemctl is-active --quiet "$production_service"
systemctl is-active --quiet caddy
curl -fsS "$production_health_url" >/dev/null
assert_production_artifacts_absent

{
  sha256sum "$pristine_data_dir/data.db" "$pristine_data_dir/auxiliary.db"
  sha256sum "$deploy_script" "$rollback_script" "$contain_script"
  sha256sum "$state_tool" "$state_guard" "$expected_manifest" "$canary"
  sha256sum "$migration_source" "$helper_source" "$route_source" "$pocketbase"
} > "$evidence/source-hashes.sha256"
chmod 0600 "$evidence/source-hashes.sha256"

case_root=
case_evidence=
data_dir=
migrations_dir=
hooks_dir=
overlay_source=

write_baseline_unit() {
  {
    printf '%s\n' \
      '[Unit]' \
      'Description=Disposable ZAR transactional-restore rehearsal clone' \
      'After=network.target' \
      '' \
      '[Service]' \
      'Type=simple' \
      'WorkingDirectory=/opt/zar/server' \
      "ExecStart=$pocketbase serve --http=127.0.0.1:$clone_port --dir=$data_dir --migrationsDir=$migrations_dir" \
      'Restart=always' \
      'RestartSec=5' \
      'User=zarapp' \
      'Group=zarapp' \
      'UMask=0077' \
      'NoNewPrivileges=true' \
      'PrivateTmp=true' \
      'PrivateDevices=true' \
      'ProtectSystem=strict' \
      'ProtectHome=true' \
      "ReadWritePaths=$data_dir" \
      'ProtectHostname=true' \
      'ProtectClock=true' \
      'ProtectKernelTunables=true' \
      'ProtectKernelModules=true' \
      'ProtectKernelLogs=true' \
      'ProtectControlGroups=true' \
      'ProtectProc=invisible' \
      'ProcSubset=pid' \
      'RestrictRealtime=true' \
      'RestrictSUIDSGID=true' \
      'LockPersonality=true' \
      'MemoryDenyWriteExecute=true' \
      'RemoveIPC=true' \
      'CapabilityBoundingSet=' \
      'AmbientCapabilities=' \
      'RestrictNamespaces=true' \
      'SystemCallArchitectures=native' \
      'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6' \
      '' \
      '[Install]' \
      'WantedBy=multi-user.target'
  } > "$unit_file"
  chown root:root "$unit_file"
  chmod 0644 "$unit_file"
  unit_owned=1
}

write_dynamic_overlay_source() {
  {
    printf '%s\n' \
      '[Service]' \
      'ExecStart=' \
      "ExecStart=$pocketbase serve --http=127.0.0.1:$clone_port --dir=$data_dir --migrationsDir=$migrations_dir --hooksDir=$hooks_dir --hooksWatch=false"
  } > "$overlay_source"
  chown root:root "$overlay_source"
  chmod 0644 "$overlay_source"
}

assert_tree_modes() {
  test "$(stat -c '%U:%G:%a' "$data_dir")" = zarapp:zarapp:700
  test "$(stat -c '%U:%G:%a' "$migrations_dir")" = root:root:755
  if [[ -d $hooks_dir ]]; then
    test ! -L "$hooks_dir"
    test "$(stat -c '%U:%G:%a' "$hooks_dir")" = root:root:755
  fi
  if find "$data_dir" -type l -print -quit | grep -q .; then
    die 'clone data tree contains a symlink'
  fi
  if find "$migrations_dir" -type l -print -quit | grep -q .; then
    die 'clone migration tree contains a symlink'
  fi
  if [[ -d $hooks_dir ]]; then
    if find "$hooks_dir" -type l -print -quit | grep -q .; then
      die 'clone hook tree contains a symlink'
    fi
  fi
  while IFS= read -r -d '' directory; do
    test "$(stat -c '%U:%G:%a' "$directory")" = zarapp:zarapp:700
  done < <(find "$data_dir" -type d -print0)
  while IFS= read -r -d '' file; do
    test "$(stat -c '%U:%G:%a' "$file")" = zarapp:zarapp:600
  done < <(find "$data_dir" -type f -print0)
  while IFS= read -r -d '' file; do
    test "$(stat -c '%U:%G:%a' "$file")" = root:root:644
  done < <(find "$migrations_dir" -type f -print0)
  if [[ -d $hooks_dir ]]; then
    while IFS= read -r -d '' file; do
      test "$(stat -c '%U:%G:%a' "$file")" = root:root:644
    done < <(find "$hooks_dir" -type f -print0)
  fi
}

prepare_case() {
  local name=$1
  if [[ $unit_owned == 1 ]]; then
    systemctl stop "$clone_unit" >/dev/null 2>&1 || \
      die "clone stop failed before $name"
    ! systemctl is-active --quiet "$clone_unit" || \
      die "clone remained active before $name"
    ! ss -H -ltn "sport = :$clone_port" | grep -q . || \
      die "clone port remained busy before $name"
    safe_remove_unit_paths
  fi
  ! ss -H -ltn "sport = :$clone_port" | grep -q . || die "clone port remained busy before $name"

  case_root=$work_root/case-$name
  case_evidence=$evidence/cases/$name
  data_dir=$case_root/pb_data
  migrations_dir=$case_root/pb_migrations
  hooks_dir=$case_root/pb_hooks
  overlay_source=$case_root/20-transactional-restore.source.conf
  [[ ! -e $case_root && ! -e $case_evidence ]] || die "duplicate case path: $name"
  install -d -o root -g root -m 0755 "$case_root"
  install -d -o zarapp -g zarapp -m 0700 "$data_dir"
  install -d -o root -g root -m 0755 "$migrations_dir" "$hooks_dir"
  install -d -o root -g root -m 0700 "$case_evidence"

  sqlite3 -readonly "$pristine_data_dir/data.db" ".backup '$data_dir/data.db'"
  sqlite3 -readonly "$pristine_data_dir/auxiliary.db" ".backup '$data_dir/auxiliary.db'"
  chown zarapp:zarapp "$data_dir/data.db" "$data_dir/auxiliary.db"
  chmod 0600 "$data_dir/data.db" "$data_dir/auxiliary.db"
  cp -a "$pristine_migrations_dir/." "$migrations_dir/"
  chown -R root:root "$migrations_dir"
  find "$migrations_dir" -type d -exec chmod 0755 {} +
  find "$migrations_dir" -type f -exec chmod 0644 {} +
  test ! -e "$migrations_dir/$migration_name"

  write_baseline_unit
  write_dynamic_overlay_source
  systemd-analyze verify "$unit_file"
  systemctl daemon-reload
  systemctl reset-failed "$clone_unit" >/dev/null 2>&1 || true
  systemctl start "$clone_unit"
  wait_for_health "$clone_health_url"
  systemctl is-active --quiet "$clone_unit"
  local service_exec
  service_exec=$(systemctl show "$clone_unit" -p ExecStart --value)
  [[ $service_exec == *"--http=127.0.0.1:$clone_port"* ]]
  [[ $service_exec == *"--dir=$data_dir"* ]]
  [[ $service_exec == *"--migrationsDir=$migrations_dir"* ]]
  [[ $service_exec != *'--hooksDir='* ]]
  [[ $service_exec != *'--hooksWatch='* ]]
  assert_tree_modes
  snapshot_state "$data_dir" "$case_evidence/state.fresh.json"
  cmp -s "$baseline_state" "$case_evidence/state.fresh.json"
  guard_state "$case_evidence/state.fresh.json" before "$baseline_state" 0
}

make_invocation_evidence() {
  local path=$1
  [[ ! -e $path && ! -L $path ]] || die "invocation evidence already exists: $path"
  install -d -o root -g root -m 0700 "$path"
}

build_deploy_args() {
  local invocation_evidence=$1 failpoint=${2:-}
  deploy_args=(
    --data-dir "$data_dir"
    --migrations-dir "$migrations_dir"
    --hooks-dir "$hooks_dir"
    --migration-source "$migration_source"
    --helper-source "$helper_source"
    --route-source "$route_source"
    --unit-overlay-source "$overlay_source"
    --unit-overlay-target "$overlay_target"
    --pocketbase "$pocketbase"
    --service "$clone_unit"
    --evidence "$invocation_evidence"
    --baseline-state "$baseline_state"
    --state-tool "$state_tool"
    --state-guard "$state_guard"
    --expected-manifest "$expected_manifest"
    --health-url "$clone_health_url"
    --confirm-disposable-clone
  )
  if [[ -n $failpoint ]]; then
    deploy_args+=(--failpoint "$failpoint")
  fi
}

run_deploy() {
  build_deploy_args "$1" "${2:-}"
  bash "$deploy_script" "${deploy_args[@]}"
}

start_deploy_async() {
  local invocation_evidence=$1 failpoint=$2 log=$3
  build_deploy_args "$invocation_evidence" "$failpoint"
  [[ -z $async_child_pid ]] || die 'an asynchronous deploy is already running'
  setsid bash "$deploy_script" "${deploy_args[@]}" > "$log" 2>&1 &
  async_child_pid=$!
}

run_rollback() {
  local invocation_evidence=$1 baseline=$2 failpoint=${3:-}
  local -a args=(
    --data-dir "$data_dir"
    --migrations-dir "$migrations_dir"
    --hooks-dir "$hooks_dir"
    --unit-overlay-source "$overlay_source"
    --unit-overlay-target "$overlay_target"
    --pocketbase "$pocketbase"
    --service "$clone_unit"
    --evidence "$invocation_evidence"
    --baseline-state "$baseline"
    --state-tool "$state_tool"
    --state-guard "$state_guard"
    --expected-manifest "$expected_manifest"
    --health-url "$clone_health_url"
    --confirm-no-ambiguous-commit
    --confirm-disposable-clone
  )
  if [[ -n $failpoint ]]; then
    args+=(--failpoint "$failpoint")
  fi
  bash "$rollback_script" "${args[@]}"
}

run_containment() {
  local invocation_evidence=$1 baseline=$2 confirmation=${3:-receipt}
  local failpoint=${4:-}
  local confirmation_flag
  case "$confirmation" in
    receipt) confirmation_flag=--confirm-receipt-present ;;
    ambiguous) confirmation_flag=--confirm-ambiguous-outcome ;;
    *) die "unknown containment confirmation: $confirmation" ;;
  esac
  local -a args=(
    --data-dir "$data_dir"
    --migrations-dir "$migrations_dir"
    --hooks-dir "$hooks_dir"
    --unit-overlay-source "$overlay_source"
    --unit-overlay-target "$overlay_target"
    --pocketbase "$pocketbase"
    --service "$clone_unit"
    --evidence "$invocation_evidence"
    --baseline-state "$baseline"
    --state-tool "$state_tool"
    --state-guard "$state_guard"
    --expected-manifest "$expected_manifest"
    --health-url "$clone_health_url"
    "$confirmation_flag"
    --confirm-disposable-clone
  )
  if [[ -n $failpoint ]]; then
    args+=(--failpoint "$failpoint")
  fi
  bash "$contain_script" "${args[@]}"
}

assert_route_status() {
  local path=$1 expected=$2
  test "$(curl -sS -o /dev/null -w '%{http_code}' "$clone_base_url$path")" = "$expected"
}

assert_exact_artifact() {
  local path=$1 expected_sha=$2
  [[ -f $path && ! -L $path ]]
  [[ $(sha256sum "$path" | awk '{print $1}') == "$expected_sha" ]]
}

assert_deployed() {
  local receipt_count=$1 output=$2 baseline=${3:-$baseline_state}
  assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
  assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
  assert_exact_artifact "$hooks_dir/$route_name" "$route_sha"
  assert_exact_artifact "$overlay_target" "$(sha256sum "$overlay_source" | awk '{print $1}')"
  assert_tree_modes
  systemctl is-active --quiet "$clone_unit"
  wait_for_health "$clone_health_url"
  assert_route_status /api/zar/restore/state 401
  local service_exec
  service_exec=$(systemctl show "$clone_unit" -p ExecStart --value)
  [[ $service_exec == *"--hooksDir=$hooks_dir"* ]]
  [[ $service_exec == *'--hooksWatch=false'* ]]
  snapshot_state "$data_dir" "$output"
  guard_state "$output" after "$baseline" "$receipt_count"
}

assert_recovered_baseline() {
  local profile=$1 output=$2
  test ! -e "$migrations_dir/$migration_name"
  test ! -e "$hooks_dir/$helper_name"
  test ! -e "$hooks_dir/$route_name"
  test ! -e "$overlay_target"
  test "$(sqlite3 -readonly "$data_dir/data.db" \
    "SELECT count(*) FROM _migrations WHERE file='$migration_name';")" = 0
  systemctl is-active --quiet "$clone_unit"
  wait_for_health "$clone_health_url"
  assert_route_status /api/zar/restore/state 404
  local service_exec
  service_exec=$(systemctl show "$clone_unit" -p ExecStart --value)
  [[ $service_exec != *'--hooksDir='* ]]
  [[ $service_exec != *'--hooksWatch='* ]]
  assert_tree_modes
  snapshot_state "$data_dir" "$output"
  guard_state "$output" "$profile" "$baseline_state" 0
  if [[ $profile == before ]]; then
    cmp -s "$baseline_state" "$output"
  fi
}

assert_failpoint_evidence() {
  local failpoint=$1 invocation_evidence=$2
  [[ -f $invocation_evidence/deploy-failure.txt && \
     ! -L $invocation_evidence/deploy-failure.txt ]]
  test "$(stat -c '%U:%G:%a:%h' "$invocation_evidence/deploy-failure.txt")" = \
    root:root:600:1
  assert_exact_artifact "$invocation_evidence/recovered-migration.js" "$migration_sha"
  case "$failpoint" in
    after-migration-install|after-migrate-up)
      test ! -e "$invocation_evidence/recovered-helper-hook.js"
      test ! -e "$invocation_evidence/recovered-route-hook.js"
      test ! -e "$invocation_evidence/recovered-unit-overlay.conf"
      ;;
    after-helper-install)
      assert_exact_artifact "$invocation_evidence/recovered-helper-hook.js" "$helper_sha"
      test ! -e "$invocation_evidence/recovered-route-hook.js"
      test ! -e "$invocation_evidence/recovered-unit-overlay.conf"
      ;;
    after-route-install)
      assert_exact_artifact "$invocation_evidence/recovered-helper-hook.js" "$helper_sha"
      assert_exact_artifact "$invocation_evidence/recovered-route-hook.js" "$route_sha"
      test ! -e "$invocation_evidence/recovered-unit-overlay.conf"
      ;;
    after-unit-overlay|unhealthy-start)
      assert_exact_artifact "$invocation_evidence/recovered-helper-hook.js" "$helper_sha"
      assert_exact_artifact "$invocation_evidence/recovered-route-hook.js" "$route_sha"
      assert_exact_artifact "$invocation_evidence/recovered-unit-overlay.conf" \
        "$(sha256sum "$overlay_source" | awk '{print $1}')"
      ;;
    *) die "unknown failpoint assertion: $failpoint" ;;
  esac
}

# Each failpoint receives its own filesystem, databases, baseline unit and
# dynamic overlay. The recovered artifacts prove migration -> helper -> route
# -> overlay/service ordering as well as the correct recovery boundary.
for failpoint in after-migration-install after-migrate-up after-helper-install \
  after-route-install after-unit-overlay unhealthy-start; do
  prepare_case "fail-$failpoint"
  deploy_evidence=$case_evidence/deploy
  make_invocation_evidence "$deploy_evidence"
  set +e
  run_deploy "$deploy_evidence" "$failpoint" \
    > "$case_evidence/deploy-invocation.log" 2>&1
  deploy_rc=$?
  set -e
  test "$deploy_rc" = 1 || die "$failpoint returned unexpected rc=$deploy_rc"
  grep -qx 'rc=1' "$deploy_evidence/deploy-failure.txt"
  if [[ $failpoint == after-migration-install ]]; then
    grep -qx 'recovery=baseline-without-down' "$deploy_evidence/deploy-recovery.txt"
    assert_recovered_baseline before "$case_evidence/state.recovered.json"
  else
    grep -qx 'recovery=guarded-down' "$deploy_evidence/deploy-recovery.txt"
    assert_recovered_baseline rolled-back "$case_evidence/state.recovered.json"
  fi
  assert_failpoint_evidence "$failpoint" "$deploy_evidence"
done

# An unavailable/invalid recovery-state capture is never sufficient to restart
# a service. The exact route is quarantined, but migration/helper/database state
# is preserved for operator inspection and the listener remains down.
prepare_case unvalidated-state-stays-stopped
deploy_evidence=$case_evidence/deploy
make_invocation_evidence "$deploy_evidence"
set +e
run_deploy "$deploy_evidence" unvalidated-state-after-route \
  > "$case_evidence/deploy-invocation.log" 2>&1
unvalidated_state_rc=$?
set -e
test "$unvalidated_state_rc" = 1 || \
  die "unvalidated recovery returned unexpected rc=$unvalidated_state_rc"
grep -qx 'recovery=unvalidated-state-stopped-route-quarantined' \
  "$deploy_evidence/deploy-recovery.txt"
if systemctl is-active --quiet "$clone_unit"; then
  die 'unvalidated recovery restarted the clone service'
fi
if ss -H -ltn "sport = :$clone_port" | grep -q .; then
  die 'unvalidated recovery left the clone listener active'
fi
test ! -e "$hooks_dir/$route_name"
assert_exact_artifact "$deploy_evidence/unvalidated-route-hook.js" "$route_sha"
assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
test ! -e "$overlay_target"
snapshot_state "$data_dir" "$case_evidence/state.unvalidated-recovery.json"
guard_state "$case_evidence/state.unvalidated-recovery.json" after \
  "$baseline_state" 0

# Every guarded entry point must refuse a pre-existing failure-file symlink
# before installing its ERR trap. The sentinel proves no root write followed it.
for evidence_operation in deploy rollback containment; do
  prepare_case "evidence-symlink-refusal-$evidence_operation"
  invocation_evidence=$case_evidence/invocation
  make_invocation_evidence "$invocation_evidence"
  sentinel=$case_root/evidence-write-sentinel.txt
  printf 'must-remain-unchanged\n' > "$sentinel"
  chmod 0600 "$sentinel"
  case "$evidence_operation" in
    deploy) failure_leaf=deploy-failure.txt ;;
    rollback) failure_leaf=rollback-failure.txt ;;
    containment) failure_leaf=containment-failure.txt ;;
  esac
  ln -s "$sentinel" "$invocation_evidence/$failure_leaf"
  sentinel_sha=$(sha256sum "$sentinel" | awk '{print $1}')
  refusal_pid_before=$(systemctl show "$clone_unit" -p MainPID --value)
  refusal_active_before=$(systemctl show "$clone_unit" \
    -p ActiveEnterTimestampMonotonic --value)
  set +e
  case "$evidence_operation" in
    deploy) run_deploy "$invocation_evidence" ;;
    rollback) run_rollback "$invocation_evidence" "$baseline_state" ;;
    containment) run_containment "$invocation_evidence" "$baseline_state" ambiguous ;;
  esac > "$case_evidence/invocation.log" 2>&1
  evidence_symlink_rc=$?
  set -e
  test "$evidence_symlink_rc" = 73 || \
    die "$evidence_operation symlink evidence returned rc=$evidence_symlink_rc"
  test "$(sha256sum "$sentinel" | awk '{print $1}')" = "$sentinel_sha"
  grep -qx must-remain-unchanged "$sentinel"
  test -L "$invocation_evidence/$failure_leaf"
  test "$(systemctl show "$clone_unit" -p MainPID --value)" = \
    "$refusal_pid_before"
  test "$(systemctl show "$clone_unit" \
    -p ActiveEnterTimestampMonotonic --value)" = "$refusal_active_before"
  printf 'operation=%s\nleaf=%s\ntarget=%s\ntarget_sha256=%s\n' \
    "$evidence_operation" "$failure_leaf" \
    "$(readlink -- "$invocation_evidence/$failure_leaf")" "$sentinel_sha" > \
    "$case_evidence/symlink-refusal-proof.txt"
  chmod 0600 "$case_evidence/symlink-refusal-proof.txt"
  rm -- "$invocation_evidence/$failure_leaf"
  assert_recovered_baseline before "$case_evidence/state.after-refusal.json"
done

# A root-owned 0700 leaf is still unsafe below a group/world-writable parent.
# All three guarded entry points must reject that parent chain before mutation.
for evidence_operation in deploy rollback containment; do
  prepare_case "untrusted-evidence-parent-$evidence_operation"
  untrusted_parent=$case_root/untrusted-evidence-parent
  install -d -o root -g root -m 0777 "$untrusted_parent"
  invocation_evidence=$untrusted_parent/invocation
  make_invocation_evidence "$invocation_evidence"
  refusal_pid_before=$(systemctl show "$clone_unit" -p MainPID --value)
  refusal_active_before=$(systemctl show "$clone_unit" \
    -p ActiveEnterTimestampMonotonic --value)
  set +e
  case "$evidence_operation" in
    deploy) run_deploy "$invocation_evidence" ;;
    rollback) run_rollback "$invocation_evidence" "$baseline_state" ;;
    containment) run_containment "$invocation_evidence" "$baseline_state" ambiguous ;;
  esac > "$case_evidence/invocation.log" 2>&1
  untrusted_evidence_rc=$?
  set -e
  test "$untrusted_evidence_rc" = 73 || \
    die "$evidence_operation untrusted evidence returned rc=$untrusted_evidence_rc"
  test "$(systemctl show "$clone_unit" -p MainPID --value)" = \
    "$refusal_pid_before"
  test "$(systemctl show "$clone_unit" \
    -p ActiveEnterTimestampMonotonic --value)" = "$refusal_active_before"
  assert_recovered_baseline before "$case_evidence/state.after-refusal.json"
done

# A byte-identical privileged input below a group/world-writable parent is
# still untrusted. Root execution must refuse it before touching the clone.
prepare_case untrusted-input-refusal
deploy_evidence=$case_evidence/deploy
make_invocation_evidence "$deploy_evidence"
untrusted_parent=$case_root/untrusted-parent
install -d -o root -g root -m 0777 "$untrusted_parent"
untrusted_guard=$untrusted_parent/transactional_restore_state_guard.py
install -o root -g root -m 0644 "$state_guard" "$untrusted_guard"
refusal_pid_before=$(systemctl show "$clone_unit" -p MainPID --value)
refusal_active_before=$(systemctl show "$clone_unit" \
  -p ActiveEnterTimestampMonotonic --value)
set +e
(
  state_guard=$untrusted_guard
  run_deploy "$deploy_evidence"
) > "$case_evidence/deploy-invocation.log" 2>&1
untrusted_input_rc=$?
set -e
test "$untrusted_input_rc" = 64 || \
  die "untrusted input returned unexpected rc=$untrusted_input_rc"
test "$(systemctl show "$clone_unit" -p MainPID --value)" = \
  "$refusal_pid_before"
test "$(systemctl show "$clone_unit" \
  -p ActiveEnterTimestampMonotonic --value)" = "$refusal_active_before"
assert_recovered_baseline before "$case_evidence/state.after-refusal.json"

# A clean successful deployment with no receipt must remain reversibly
# rollbackable. This case is fresh and independent of every failpoint case.
prepare_case success-pre-receipt-rollback
deploy_evidence=$case_evidence/deploy
rollback_evidence=$case_evidence/rollback
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_DEPLOY_PASS "$deploy_evidence/deploy-result.txt"
assert_deployed 0 "$case_evidence/state.after-deploy.json"
make_invocation_evidence "$rollback_evidence"
run_rollback "$rollback_evidence" "$baseline_state" \
  > "$case_evidence/rollback-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_ROLLBACK_PASS "$rollback_evidence/rollback-result.txt"
assert_recovered_baseline rolled-back "$case_evidence/state.after-rollback.json"

# Rollback is armed before its first stop. A stop-boundary failure restores only
# the fully validated deployed state and a healthy listener.
prepare_case rollback-pre-stop-recovery
deploy_evidence=$case_evidence/deploy
rollback_evidence=$case_evidence/rollback
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
assert_deployed 0 "$case_evidence/state.after-deploy.json"
make_invocation_evidence "$rollback_evidence"
set +e
run_rollback "$rollback_evidence" "$baseline_state" before-stop \
  > "$case_evidence/rollback-invocation.log" 2>&1
rollback_failpoint_rc=$?
set -e
test "$rollback_failpoint_rc" = 1 || \
  die "rollback pre-stop failpoint returned rc=$rollback_failpoint_rc"
grep -qx 'recovery=deployed-state-restored' \
  "$rollback_evidence/rollback-recovery.txt"
assert_deployed 0 "$case_evidence/state.after-recovery.json"

# A recovery restart that does not reach its verified health boundary is forced
# back down; it may never remain half-started with the restore route enabled.
prepare_case rollback-recovery-restart-fail-closed
deploy_evidence=$case_evidence/deploy
rollback_evidence=$case_evidence/rollback
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
assert_deployed 0 "$case_evidence/state.after-deploy.json"
make_invocation_evidence "$rollback_evidence"
set +e
run_rollback "$rollback_evidence" "$baseline_state" recovery-unhealthy-start \
  > "$case_evidence/rollback-invocation.log" 2>&1
rollback_failpoint_rc=$?
set -e
test "$rollback_failpoint_rc" = 1 || \
  die "rollback recovery-start failpoint returned rc=$rollback_failpoint_rc"
grep -qx 'recovery=deployed-restart-failed-service-stopped' \
  "$rollback_evidence/rollback-recovery.txt"
if systemctl is-active --quiet "$clone_unit"; then
  die 'failed rollback recovery restart left service active'
fi
if ss -H -ltn "sport = :$clone_port" | grep -q .; then
  die 'failed rollback recovery restart left listener active'
fi
assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
assert_exact_artifact "$hooks_dir/$route_name" "$route_sha"
assert_exact_artifact "$overlay_target" "$(sha256sum "$overlay_source" | awk '{print $1}')"
snapshot_state "$data_dir" "$case_evidence/state.after-recovery.json"
guard_state "$case_evidence/state.after-recovery.json" after "$baseline_state" 0

# If a verification fails after rollback start, recovery no longer trusts the
# old stopped flag. It re-stops, verifies rolled-back state/artifact absence and
# starts only that exact baseline.
prepare_case rollback-post-start-recovery
deploy_evidence=$case_evidence/deploy
rollback_evidence=$case_evidence/rollback
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
assert_deployed 0 "$case_evidence/state.after-deploy.json"
make_invocation_evidence "$rollback_evidence"
set +e
run_rollback "$rollback_evidence" "$baseline_state" after-rollback-start \
  > "$case_evidence/rollback-invocation.log" 2>&1
rollback_failpoint_rc=$?
set -e
test "$rollback_failpoint_rc" = 1 || \
  die "rollback post-start failpoint returned rc=$rollback_failpoint_rc"
grep -qx 'recovery=rolled-back-state-restored' \
  "$rollback_evidence/rollback-recovery.txt"
assert_recovered_baseline rolled-back "$case_evidence/state.after-recovery.json"

# The containment handler is armed before its first stop attempt. A failure at
# that boundary must itself stop the service and quarantine the exact route.
prepare_case containment-pre-stop-failure-fail-closed
deploy_evidence=$case_evidence/deploy
failed_containment_evidence=$case_evidence/containment
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_DEPLOY_PASS "$deploy_evidence/deploy-result.txt"
assert_deployed 0 "$case_evidence/state.after-deploy.json"
snapshot_state "$data_dir" "$case_evidence/state.before-containment.json"
make_invocation_evidence "$failed_containment_evidence"
set +e
run_containment "$failed_containment_evidence" "$baseline_state" ambiguous \
  before-contained-stop > "$case_evidence/containment-invocation.log" 2>&1
failed_containment_rc=$?
set -e
test "$failed_containment_rc" = 1 || \
  die "pre-stop containment failpoint returned rc=$failed_containment_rc"
grep -qx 'failure_state=service-stopped-route-quarantined' \
  "$failed_containment_evidence/containment-failure.txt"
if systemctl is-active --quiet "$clone_unit"; then
  die 'pre-stop containment failure left the clone service active'
fi
if ss -H -ltn "sport = :$clone_port" | grep -q .; then
  die 'pre-stop containment failure left the clone listener active'
fi
test ! -e "$hooks_dir/$route_name"
assert_exact_artifact \
  "$failed_containment_evidence/route-hook.quarantined.js" "$route_sha"
assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
assert_exact_artifact "$overlay_target" "$(sha256sum "$overlay_source" | awk '{print $1}')"
snapshot_state "$data_dir" "$case_evidence/state.after-containment-failure.json"
cmp -s "$case_evidence/state.before-containment.json" \
  "$case_evidence/state.after-containment-failure.json"
guard_state_without_baseline \
  "$case_evidence/state.after-containment-failure.json" contained 0

# A post-start containment verification failure must never restore the route or
# leave an unverified service running. The failure handler keeps the exact route
# quarantined and the service/listener stopped for operator inspection.
prepare_case containment-failure-fail-closed
deploy_evidence=$case_evidence/deploy
failed_containment_evidence=$case_evidence/containment
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_DEPLOY_PASS "$deploy_evidence/deploy-result.txt"
assert_deployed 0 "$case_evidence/state.after-deploy.json"
snapshot_state "$data_dir" "$case_evidence/state.before-containment.json"
make_invocation_evidence "$failed_containment_evidence"
set +e
run_containment "$failed_containment_evidence" "$baseline_state" ambiguous \
  after-contained-start > "$case_evidence/containment-invocation.log" 2>&1
failed_containment_rc=$?
set -e
test "$failed_containment_rc" = 1 || \
  die "containment failpoint returned unexpected rc=$failed_containment_rc"
grep -qx 'failure_state=service-stopped-route-quarantined' \
  "$failed_containment_evidence/containment-failure.txt"
if systemctl is-active --quiet "$clone_unit"; then
  die 'containment failure left the clone service active'
fi
if ss -H -ltn "sport = :$clone_port" | grep -q .; then
  die 'containment failure left the clone listener active'
fi
test ! -e "$hooks_dir/$route_name"
assert_exact_artifact \
  "$failed_containment_evidence/route-hook.quarantined.js" "$route_sha"
assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
assert_exact_artifact "$overlay_target" "$(sha256sum "$overlay_source" | awk '{print $1}')"
snapshot_state "$data_dir" "$case_evidence/state.after-containment-failure.json"
cmp -s "$case_evidence/state.before-containment.json" \
  "$case_evidence/state.after-containment-failure.json"
guard_state_without_baseline \
  "$case_evidence/state.after-containment-failure.json" contained 0

# An ambiguous client outcome must use the same forward-only route quarantine
# even when no receipt is visible. No migration down or domain mutation is
# allowed in this branch.
prepare_case success-pre-receipt-ambiguous-containment
deploy_evidence=$case_evidence/deploy
ambiguous_containment_evidence=$case_evidence/containment
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_DEPLOY_PASS "$deploy_evidence/deploy-result.txt"
assert_deployed 0 "$case_evidence/state.after-deploy.json"
snapshot_state "$data_dir" "$case_evidence/state.before-containment.json"
make_invocation_evidence "$ambiguous_containment_evidence"
run_containment "$ambiguous_containment_evidence" "$baseline_state" ambiguous \
  > "$case_evidence/containment-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_FORWARD_ONLY_CONTAINMENT_PASS \
  "$ambiguous_containment_evidence/containment-result.txt"
snapshot_state "$data_dir" "$case_evidence/state.after-containment.json"
cmp -s "$case_evidence/state.before-containment.json" \
  "$case_evidence/state.after-containment.json"
guard_state_without_baseline "$case_evidence/state.after-containment.json" contained 0
assert_route_status /api/zar/restore/state 404
assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
assert_exact_artifact "$overlay_target" "$(sha256sum "$overlay_source" | awk '{print $1}')"
test ! -e "$hooks_dir/$route_name"
assert_exact_artifact \
  "$ambiguous_containment_evidence/route-hook.quarantined.js" "$route_sha"
assert_tree_modes
wait_for_health "$clone_health_url"

# Exercise deploy's receipt-bearing recovery itself (not only the separate
# containment command). The deploy failpoint waits on a real committed receipt,
# then recovery must quarantine the route and restart only contained state.
prepare_case deploy-receipt-forward-only-recovery
deploy_evidence=$case_evidence/deploy
make_invocation_evidence "$deploy_evidence"
start_deploy_async "$deploy_evidence" receipt-after-healthy-start \
  "$case_evidence/deploy-invocation.log"
route_ready=0
for _ in $(seq 1 300); do
  if ! kill -0 "$async_child_pid" >/dev/null 2>&1; then
    break
  fi
  if [[ -f $deploy_evidence/receipt-failpoint-ready.txt ]] && \
     grep -qx ready-for-client "$deploy_evidence/receipt-failpoint-ready.txt" && \
     [[ $(curl -sS -o /dev/null -w '%{http_code}' \
       "$clone_base_url/api/zar/restore/state") == 401 ]]; then
    route_ready=1
    break
  fi
  sleep 0.1
done
if [[ $route_ready != 1 ]]; then
  set +e
  wait "$async_child_pid"
  receipt_deploy_rc=$?
  set -e
  async_child_pid=
  die "receipt recovery route did not become ready (deploy rc=$receipt_deploy_rc)"
fi
private_canary_state=$case_root/receipt-recovery-private-state.json
receipt_recovery_commit_evidence=$case_evidence/canary-commit.json
python3 "$canary" commit \
  --base-url "$clone_base_url" \
  --clone-unit "$clone_unit" \
  --confirm-disposable-clone \
  --state "$private_canary_state" \
  --output "$receipt_recovery_commit_evidence"
printf 'client-complete\n' > "$deploy_evidence/receipt-client-complete.txt"
chmod 0600 "$deploy_evidence/receipt-client-complete.txt"
set +e
wait "$async_child_pid"
receipt_deploy_rc=$?
set -e
async_child_pid=
test "$receipt_deploy_rc" = 1 || \
  die "receipt recovery deploy returned unexpected rc=$receipt_deploy_rc"
grep -qx 'recovery=receipt-forward-only-containment' \
  "$deploy_evidence/deploy-recovery.txt"
wait_for_health "$clone_health_url"
assert_route_status /api/zar/restore/state 404
assert_route_status /api/zar/restore/commit 404
assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
assert_exact_artifact "$overlay_target" "$(sha256sum "$overlay_source" | awk '{print $1}')"
test ! -e "$hooks_dir/$route_name"
assert_exact_artifact "$deploy_evidence/contained-route-hook.js" "$route_sha"
snapshot_state "$data_dir" "$case_evidence/state.after-recovery.json"
guard_state_without_baseline "$case_evidence/state.after-recovery.json" contained 1
rm -f -- "$private_canary_state"
test ! -e "$private_canary_state"
private_canary_state=

# Receipt-bearing case: commit a valid seven-collection snapshot (including
# cash), restart the real systemd service, replay the exact request, and prove
# that all destructive rollback paths refuse without mutation.
prepare_case success-receipt-forward-only
deploy_evidence=$case_evidence/deploy
make_invocation_evidence "$deploy_evidence"
run_deploy "$deploy_evidence" > "$case_evidence/deploy-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_DEPLOY_PASS "$deploy_evidence/deploy-result.txt"
assert_deployed 0 "$case_evidence/state.after-deploy.json"

private_canary_state=$case_root/canary-private-state.json
readonly canary_commit_evidence=$case_evidence/canary-commit.json
readonly canary_replay_evidence=$case_evidence/canary-replay.json
python3 "$canary" commit \
  --base-url "$clone_base_url" \
  --clone-unit "$clone_unit" \
  --confirm-disposable-clone \
  --state "$private_canary_state" \
  --output "$canary_commit_evidence"
test "$(stat -c '%U:%G:%a' "$private_canary_state")" = root:root:600
snapshot_state "$data_dir" "$case_evidence/state.after-commit.json"
guard_state_without_baseline "$case_evidence/state.after-commit.json" contained 1

systemctl restart "$clone_unit"
wait_for_health "$clone_health_url"
snapshot_state "$data_dir" "$case_evidence/state.after-real-restart.json"
cmp -s "$case_evidence/state.after-commit.json" \
  "$case_evidence/state.after-real-restart.json"

python3 "$canary" replay \
  --base-url "$clone_base_url" \
  --clone-unit "$clone_unit" \
  --confirm-disposable-clone \
  --state "$private_canary_state" \
  --output "$canary_replay_evidence"
snapshot_state "$data_dir" "$case_evidence/state.after-replay.json"
cmp -s "$case_evidence/state.after-commit.json" "$case_evidence/state.after-replay.json"
guard_state_without_baseline "$case_evidence/state.after-replay.json" contained 1

# Assert both evidence documents are allow-listed and none of the private
# email/password/token/request body values leaked into them.
python3 - "$private_canary_state" "$canary_commit_evidence" \
  "$canary_replay_evidence" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    private = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    commit = json.load(source)
with open(sys.argv[3], encoding="utf-8") as source:
    replay = json.load(source)

allowed_top = {"schemaVersion", "action", "status", "generatedAtUtc", "receipt", "postCommitState", "privacy"}
allowed_receipt = {
    "protocolVersion", "requestId", "workspaceId", "snapshotHash", "beforeHash",
    "afterHash", "counts", "committedAt", "replayed",
}
for document, action, replayed in ((commit, "commit", False), (replay, "replay", True)):
    assert set(document) == allowed_top
    assert document["action"] == action and document["status"] == "pass"
    assert set(document["receipt"]) == allowed_receipt
    assert document["receipt"]["replayed"] is replayed
    assert document["receipt"]["counts"] == {
        "people": 1,
        "deals": 1,
        "settlements": 1,
        "coinTypes": 1,
        "currencyTypes": 1,
        "paymentAllocations": 1,
        "cashEntries": 1,
        "total": 7,
    }

commit_metadata = dict(commit["receipt"])
replay_metadata = dict(replay["receipt"])
commit_metadata.pop("replayed")
replay_metadata.pop("replayed")
assert commit_metadata == replay_metadata
assert commit["postCommitState"] == replay["postCommitState"]

serialized_evidence = json.dumps([commit, replay], ensure_ascii=False, sort_keys=True)
private_values = [
    private["identity"], private["password"], private["token"],
    json.dumps(private["requestBody"], ensure_ascii=False, sort_keys=True),
]
assert all(value not in serialized_evidence for value in private_values)
forbidden = {"email", "identity", "password", "token", "payload", "notes", "requestbody", "confirmationpassword"}

def walk(value):
    if isinstance(value, dict):
        for key, item in value.items():
            assert key.casefold() not in forbidden
            walk(item)
    elif isinstance(value, list):
        for item in value:
            walk(item)

walk(commit)
walk(replay)
PY

[[ $(realpath -m -- "$private_canary_state") == "$work_root"/* ]] || \
  die 'private canary state escaped the clone tree'
rm -f -- "$private_canary_state"
test ! -e "$private_canary_state"
printf 'private_canary_state=deleted\n' > "$case_evidence/private-state-cleanup.txt"
private_canary_state=

snapshot_artifacts() {
  local output=$1
  {
    printf 'migration %s %s\n' \
      "$(sha256sum "$migrations_dir/$migration_name" | awk '{print $1}')" \
      "$(stat -c '%U:%G:%a' "$migrations_dir/$migration_name")"
    printf 'helper %s %s\n' \
      "$(sha256sum "$hooks_dir/$helper_name" | awk '{print $1}')" \
      "$(stat -c '%U:%G:%a' "$hooks_dir/$helper_name")"
    printf 'route %s %s\n' \
      "$(sha256sum "$hooks_dir/$route_name" | awk '{print $1}')" \
      "$(stat -c '%U:%G:%a' "$hooks_dir/$route_name")"
    printf 'overlay %s %s\n' \
      "$(sha256sum "$overlay_target" | awk '{print $1}')" \
      "$(stat -c '%U:%G:%a' "$overlay_target")"
  } > "$output"
  chmod 0600 "$output"
}

snapshot_service() {
  local output=$1
  systemctl show "$clone_unit" \
    -p ActiveState -p SubState -p NRestarts -p MainPID -p ExecStart > "$output"
  chmod 0600 "$output"
}

rollback_refusal_evidence=$case_evidence/rollback-refusal
make_invocation_evidence "$rollback_refusal_evidence"
snapshot_state "$data_dir" "$case_evidence/state.before-rollback-refusal.json"
snapshot_artifacts "$case_evidence/artifacts.before-rollback-refusal.txt"
snapshot_service "$case_evidence/service.before-rollback-refusal.txt"
set +e
run_rollback "$rollback_refusal_evidence" "$baseline_state" \
  > "$case_evidence/rollback-refusal-invocation.log" 2>&1
rollback_refusal_rc=$?
set -e
test "$rollback_refusal_rc" = 78 || \
  die "receipt-bearing rollback returned unexpected rc=$rollback_refusal_rc"
grep -qx TRANSACTIONAL_RESTORE_ROLLBACK_REFUSED_RECEIPTS \
  "$rollback_refusal_evidence/rollback-refused.txt"
snapshot_state "$data_dir" "$case_evidence/state.after-rollback-refusal.json"
snapshot_artifacts "$case_evidence/artifacts.after-rollback-refusal.txt"
snapshot_service "$case_evidence/service.after-rollback-refusal.txt"
cmp -s "$case_evidence/state.before-rollback-refusal.json" \
  "$case_evidence/state.after-rollback-refusal.json"
cmp -s "$case_evidence/artifacts.before-rollback-refusal.txt" \
  "$case_evidence/artifacts.after-rollback-refusal.txt"
cmp -s "$case_evidence/service.before-rollback-refusal.txt" \
  "$case_evidence/service.after-rollback-refusal.txt"
cmp -s "$case_evidence/state.after-replay.json" \
  "$case_evidence/state.after-rollback-refusal.json"
wait_for_health "$clone_health_url"
assert_route_status /api/zar/restore/state 401

# Prove the migration's raw down guard independently of the wrapper.
systemctl stop "$clone_unit"
if systemctl is-active --quiet "$clone_unit"; then
  die 'clone remained active before raw down refusal test'
fi
if ss -H -ltn "sport = :$clone_port" | grep -q .; then
  die 'clone listener remained active before raw down refusal'
fi
snapshot_state "$data_dir" "$case_evidence/state.before-raw-down.json"
snapshot_artifacts "$case_evidence/artifacts.before-raw-down.txt"
set +e
(
  cd /opt/zar/server
  printf 'y\n' | runuser -u zarapp -- "$pocketbase" migrate down 1 \
    --dir="$data_dir" --migrationsDir="$migrations_dir"
) > "$case_evidence/raw-down-refusal.log" 2>&1
raw_down_rc=$?
set -e
test "$raw_down_rc" -ne 0 || die 'raw migrate down unexpectedly succeeded with a receipt'
grep -Fq 'Refusing to remove transactional restore after a restore receipt exists.' \
  "$case_evidence/raw-down-refusal.log"
snapshot_state "$data_dir" "$case_evidence/state.after-raw-down.json"
snapshot_artifacts "$case_evidence/artifacts.after-raw-down.txt"
cmp -s "$case_evidence/state.before-raw-down.json" \
  "$case_evidence/state.after-raw-down.json"
cmp -s "$case_evidence/artifacts.before-raw-down.txt" \
  "$case_evidence/artifacts.after-raw-down.txt"
cmp -s "$case_evidence/state.after-replay.json" "$case_evidence/state.after-raw-down.json"
systemctl start "$clone_unit"
wait_for_health "$clone_health_url"
snapshot_state "$data_dir" "$case_evidence/state.after-raw-down-restart.json"
cmp -s "$case_evidence/state.after-replay.json" \
  "$case_evidence/state.after-raw-down-restart.json"

# Forward-only containment removes only the route. Migration, helper, overlay,
# receipt metadata and all domain hashes/counts must remain byte-for-byte equal
# at the sanitized state level.
containment_evidence=$case_evidence/containment
make_invocation_evidence "$containment_evidence"
run_containment "$containment_evidence" "$baseline_state" \
  > "$case_evidence/containment-invocation.log" 2>&1
grep -qx TRANSACTIONAL_RESTORE_FORWARD_ONLY_CONTAINMENT_PASS \
  "$containment_evidence/containment-result.txt"
snapshot_state "$data_dir" "$case_evidence/state.after-containment.json"
cmp -s "$case_evidence/state.after-replay.json" \
  "$case_evidence/state.after-containment.json"
guard_state_without_baseline "$case_evidence/state.after-containment.json" contained 1
assert_route_status /api/zar/restore/state 404
test "$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  "$clone_base_url/api/zar/restore/commit")" = 404
assert_exact_artifact "$migrations_dir/$migration_name" "$migration_sha"
assert_exact_artifact "$hooks_dir/$helper_name" "$helper_sha"
assert_exact_artifact "$overlay_target" "$(sha256sum "$overlay_source" | awk '{print $1}')"
test ! -e "$hooks_dir/$route_name"
assert_exact_artifact "$containment_evidence/route-hook.quarantined.js" "$route_sha"
assert_tree_modes
wait_for_health "$clone_health_url"

# Final production checks are read-only and must match the original sanitized
# state exactly: exact 11-rule profile, candidate history zero, candidate files
# absent, database integrity and both public services healthy.
readonly production_postflight_state=$evidence/production-postflight-state.json
capture_production_state "$production_postflight_state"
cmp -s "$production_preflight_state" "$production_postflight_state" || \
  die 'production sanitized state changed during the clone rehearsal'
assert_production_artifacts_absent
if find "$evidence" -type l -print -quit | grep -q .; then
  die 'sanitized evidence contains a symlink'
fi

printf '%s\n' \
  'status=pass' \
  'production_candidate_file=absent' \
  'production_candidate_history=0' \
  'production_rate_rules=11' \
  'deployed_rate_rules=13' \
  'failpoints=6' \
  'nonempty_evidence_refusal=pass' \
  'evidence_symlink_refusal_all_entrypoints=pass' \
  'untrusted_evidence_parent_refusal_all_entrypoints=pass' \
  'untrusted_input_refusal=pass' \
  'unvalidated_recovery_stays_stopped=pass' \
  'deploy_receipt_recovery=pass' \
  'pre_receipt_rollback=pass' \
  'rollback_failure_recovery=pass' \
  'containment_pre_stop_failure_fail_closed=pass' \
  'containment_failure_fail_closed=pass' \
  'ambiguous_forward_only_containment=pass' \
  'receipt_restart_replay=pass' \
  'receipt_rollback_refusal=pass' \
  'receipt_raw_down_refusal=pass' \
  'forward_only_containment=pass' \
  'private_canary_state=deleted' \
  > "$evidence/rehearsal-result.txt"
chmod 0600 "$evidence/rehearsal-result.txt"

success=1
echo "TRANSACTIONAL_RESTORE_CLONE_REHEARSAL_PASS evidence=$evidence"
