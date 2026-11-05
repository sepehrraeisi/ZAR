#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
readonly pinned_expected_manifest_sha=3102b85888016d479bf579c2e52e2fe6b0bee65910737dad7fc00a06bd9db4c3

# Forward-only containment: disable only the HTTP route while preserving the
# migration, helper, rate policy, membership lock and every receipt.

data_dir=
migrations_dir=
hooks_dir=
overlay_source=
overlay_target=
pocketbase=
service=
evidence=
baseline_state=
state_tool=
state_guard=
expected_manifest=
health_url=
admin_url=
disposable_clone=0
reason=
failpoint=

usage() {
  cat >&2 <<'USAGE'
Usage: guarded_transactional_restore_contain.sh \
  --data-dir ABSOLUTE_PATH --migrations-dir ABSOLUTE_PATH \
  --hooks-dir ABSOLUTE_PATH --unit-overlay-source ABSOLUTE_FILE \
  --unit-overlay-target ABSOLUTE_FILE --pocketbase ABSOLUTE_FILE \
  --service SYSTEMD_UNIT --evidence ABSOLUTE_DIRECTORY \
  --baseline-state ABSOLUTE_FILE --state-tool ABSOLUTE_FILE \
  --state-guard ABSOLUTE_FILE --expected-manifest ABSOLUTE_FILE \
  --health-url LOOPBACK_URL \
  (--confirm-receipt-present | --confirm-ambiguous-outcome) \
  [--admin-url URL_EXPECTED_TO_RETURN_404] [--confirm-disposable-clone] \
  [--failpoint before-contained-stop|after-contained-start]
USAGE
  exit 64
}

while (($#)); do
  case "$1" in
    --data-dir) data_dir=${2:-}; shift 2 ;;
    --migrations-dir) migrations_dir=${2:-}; shift 2 ;;
    --hooks-dir) hooks_dir=${2:-}; shift 2 ;;
    --unit-overlay-source) overlay_source=${2:-}; shift 2 ;;
    --unit-overlay-target) overlay_target=${2:-}; shift 2 ;;
    --pocketbase) pocketbase=${2:-}; shift 2 ;;
    --service) service=${2:-}; shift 2 ;;
    --evidence) evidence=${2:-}; shift 2 ;;
    --baseline-state) baseline_state=${2:-}; shift 2 ;;
    --state-tool) state_tool=${2:-}; shift 2 ;;
    --state-guard) state_guard=${2:-}; shift 2 ;;
    --expected-manifest) expected_manifest=${2:-}; shift 2 ;;
    --health-url) health_url=${2:-}; shift 2 ;;
    --admin-url) admin_url=${2:-}; shift 2 ;;
    --confirm-disposable-clone) disposable_clone=1; shift ;;
    --confirm-receipt-present) [[ -z $reason ]] || usage; reason=receipt; shift ;;
    --confirm-ambiguous-outcome) [[ -z $reason ]] || usage; reason=ambiguous; shift ;;
    --failpoint) failpoint=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done

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

assert_root_trusted_empty_dir() {
  local dir=$1 current mode
  [[ -d $dir && ! -L $dir ]] || return 1
  [[ $(stat -c '%u:%g:%a' "$dir") == 0:0:700 ]] || return 1
  current=$dir
  while :; do
    [[ -d $current && ! -L $current ]] || return 1
    [[ $(stat -c '%u:%g' "$current") == 0:0 ]] || return 1
    mode=$(stat -c '%a' "$current")
    (( (8#$mode & 022) == 0 )) || return 1
    [[ $current == / ]] && break
    current=$(dirname -- "$current")
  done
  [[ -z $(find "$dir" -mindepth 1 -maxdepth 1 -print -quit) ]]
}

pin_evidence_dir() {
  evidence_path=$evidence
  evidence_identity=$(stat -c '%d:%i' "$evidence_path") || return 1
  exec {evidence_fd}<"$evidence_path" || return 1
  [[ $(stat -Lc '%d:%i' "/proc/$$/fd/$evidence_fd") == "$evidence_identity" ]] || return 1
  evidence=/proc/$$/fd/$evidence_fd
}

write_new_evidence_file() {
  local name=$1 content=$2
  python3 - "$evidence_path" "$evidence_identity" "$name" "$content" <<'PY'
import os
import sys

directory, identity, name, content = sys.argv[1:]
if not name or "/" in name or name in {".", ".."}:
    raise SystemExit(1)
expected_device, expected_inode = (int(value) for value in identity.split(":"))
directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
try:
    current = os.fstat(directory_fd)
    if (current.st_dev, current.st_ino) != (expected_device, expected_inode):
        raise SystemExit(1)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
    output_fd = os.open(name, flags, 0o600, dir_fd=directory_fd)
    try:
        os.write(output_fd, content.encode("utf-8", errors="backslashreplace"))
        os.fsync(output_fd)
    finally:
        os.close(output_fd)
finally:
    os.close(directory_fd)
PY
}

[[ $EUID -eq 0 ]] || { echo 'must run as root' >&2; exit 77; }
[[ $reason == receipt || $reason == ambiguous ]] || usage
for value in "$data_dir" "$migrations_dir" "$hooks_dir" "$overlay_source" \
  "$overlay_target" "$pocketbase" "$evidence" "$baseline_state" \
  "$state_tool" "$state_guard" "$expected_manifest"; do
  [[ $value == /* && $value != / ]] || usage
  [[ $(realpath -m "$value") == "$value" ]] || usage
  [[ $value != *"'"* && $value != *$'\n'* ]] || usage
done
[[ $service == zar-*.service ]] || usage
[[ $health_url =~ ^http://127\.0\.0\.1:([0-9]+)/api/health$ ]] || usage
readonly port=${BASH_REMATCH[1]}
if [[ $disposable_clone == 1 ]]; then
  [[ $service == zar-restore-clone-*.service ]] || usage
  [[ $data_dir == /opt/zar/server/restore-clone.*/* ]] || usage
  [[ $migrations_dir == /opt/zar/server/restore-clone.*/* ]] || usage
  [[ $hooks_dir == /opt/zar/server/restore-clone.*/* ]] || usage
  [[ $overlay_target == /run/systemd/system/zar-restore-clone-*.service.d/20-transactional-restore.conf ]] || usage
  [[ $port != 8090 ]] || usage
else
  [[ -z $failpoint ]] || usage
  [[ $service == zar-server.service ]] || usage
  [[ $data_dir == /opt/zar/server/pb_data ]] || usage
  [[ $migrations_dir == /opt/zar/server/pb_migrations ]] || usage
  [[ $hooks_dir == /opt/zar/server/pb_hooks ]] || usage
  [[ $overlay_target == /etc/systemd/system/zar-server.service.d/20-transactional-restore.conf ]] || usage
  [[ $port == 8090 ]] || usage
fi
case "$failpoint" in
  ''|before-contained-stop|after-contained-start) ;;
  *) usage ;;
esac
for file in "$overlay_source" "$pocketbase" "$baseline_state" "$state_tool" \
  "$state_guard" "$expected_manifest"; do
  assert_root_trusted_file "$file" || usage
done
if ! assert_root_trusted_empty_dir "$evidence"; then
  echo 'evidence directory must be empty, root-owned 0700, and below trusted parents' >&2
  exit 73
fi
if ! pin_evidence_dir; then
  echo 'evidence directory identity could not be pinned' >&2
  exit 73
fi

exec 9>/run/lock/zar-transactional-restore-change.lock
flock -n 9 || { echo 'another transactional-restore change is running' >&2; exit 75; }
exec 8>/run/lock/zar-rate-limit-change.lock
flock -n 8 || { echo 'another ZAR rate-limit change is running' >&2; exit 75; }
install -d -o root -g root -m 0700 /run/zar-backup
exec 7>/run/zar-backup/lock
flock -n 7 || { echo 'a ZAR backup is running' >&2; exit 75; }
test "$(sha256sum "$expected_manifest" | awk '{print $1}')" = \
  "$pinned_expected_manifest_sha"

json_get() {
  python3 - "$1" "$2" <<'PY'
import json,sys
value=json.load(open(sys.argv[1],encoding='utf-8'))
for part in sys.argv[2].split('.'):
    value=value[part]
if not isinstance(value,(str,int,float,bool)) and value is not None:
    raise SystemExit(1)
print(str(value).lower() if isinstance(value,bool) else value)
PY
}

readonly migration_name=$(json_get "$expected_manifest" artifacts.migration.name)
readonly migration_sha=$(json_get "$expected_manifest" artifacts.migration.sha256)
readonly helper_name=$(json_get "$expected_manifest" artifacts.helperHook.name)
readonly helper_sha=$(json_get "$expected_manifest" artifacts.helperHook.sha256)
readonly route_name=$(json_get "$expected_manifest" artifacts.routeHook.name)
readonly route_sha=$(json_get "$expected_manifest" artifacts.routeHook.sha256)
readonly production_overlay_sha=$(json_get "$expected_manifest" artifacts.productionUnitOverlay.sha256)
readonly overlay_runtime_sha=$(sha256sum "$overlay_source" | awk '{print $1}')
readonly state_tool_sha=$(json_get "$expected_manifest" artifacts.stateTool.sha256)
readonly state_guard_sha=$(json_get "$expected_manifest" artifacts.stateGuard.sha256)
readonly pocketbase_sha=$(json_get "$expected_manifest" pocketBaseSha256)
readonly production_unit_sha=$(json_get "$expected_manifest" productionBaseline.unitSha256)
readonly production_hardening_sha=$(json_get "$expected_manifest" productionBaseline.hardeningDropInSha256)
readonly migration_path=$migrations_dir/$migration_name
readonly helper_path=$hooks_dir/$helper_name
readonly route_path=$hooks_dir/$route_name
readonly db=$data_dir/data.db
readonly auxiliary_db=$data_dir/auxiliary.db
readonly started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
containment_in_progress=0
route_moved=0

snapshot_state() {
  local output=$1
  local data_copy=$evidence/.state-data.$$.db
  local auxiliary_copy=$evidence/.state-auxiliary.$$.db
  rm -f -- "$data_copy" "$auxiliary_copy"
  if ! sqlite3 "$db" ".backup '$data_copy'" || \
     ! sqlite3 "$auxiliary_db" ".backup '$auxiliary_copy'" || \
     ! python3 "$state_tool" --database "$data_copy" \
       --auxiliary "$auxiliary_copy" > "$output"; then
    rm -f -- "$data_copy" "$auxiliary_copy" "$output"
    return 1
  fi
  chmod 0600 "$output"
  rm -f -- "$data_copy" "$auxiliary_copy"
}

artifact_exact() {
  [[ -f $1 && ! -L $1 ]] && \
    [[ $(sha256sum "$1" | awk '{print $1}') == "$2" ]]
}

assert_effective_exec() {
  local service_exec=$1 actual
  [[ $service_exec == *"path=$pocketbase ;"* ]]
  [[ $service_exec == *"argv[]=$pocketbase serve "* ]]
  actual=$(grep -o -- '--http=[^ ;]*' <<<"$service_exec" || true)
  [[ $actual == "--http=127.0.0.1:$port" ]]
  actual=$(grep -o -- '--dir=[^ ;]*' <<<"$service_exec" || true)
  [[ $actual == "--dir=$data_dir" ]]
  actual=$(grep -o -- '--migrationsDir=[^ ;]*' <<<"$service_exec" || true)
  [[ $actual == "--migrationsDir=$migrations_dir" ]]
  actual=$(grep -o -- '--hooksDir=[^ ;]*' <<<"$service_exec" || true)
  [[ $actual == "--hooksDir=$hooks_dir" ]]
  actual=$(grep -o -- '--hooksWatch=[^ ;]*' <<<"$service_exec" || true)
  [[ $actual == '--hooksWatch=false' ]]
}

receipt_count() {
  python3 - "$1" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['restoreReceipts']['count'])
PY
}

service_start_and_wait() {
  systemctl start "$service"
  for _ in $(seq 1 150); do
    if systemctl is-active --quiet "$service" && \
       curl -fsS "$health_url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

recover_on_error() {
  local rc=${1:-$?}
  trap - ERR HUP INT TERM
  set +e
  local failure_command=$BASH_COMMAND failure_state=
  if [[ $containment_in_progress == 1 ]]; then
    systemctl stop "$service" >/dev/null 2>&1 || true
    if systemctl is-active --quiet "$service" || \
       ss -H -ltn "sport = :$port" | grep -q .; then
      systemctl kill --kill-who=all --signal=SIGKILL "$service" \
        >/dev/null 2>&1 || true
      systemctl stop "$service" >/dev/null 2>&1 || true
    fi
    if artifact_exact "$route_path" "$route_sha" && \
       [[ ! -e $evidence/route-hook.quarantined.js ]]; then
      mv -- "$route_path" "$evidence/route-hook.quarantined.js"
      route_moved=1
    fi
    if systemctl is-active --quiet "$service" || \
       ss -H -ltn "sport = :$port" | grep -q .; then
      echo 'containment failed and service inactivity could not be verified' >&2
    elif [[ ! -e $route_path ]] && \
         artifact_exact "$evidence/route-hook.quarantined.js" "$route_sha"; then
      failure_state=service-stopped-route-quarantined
    else
      echo 'containment failed closed with service stopped; route state needs operator inspection' >&2
    fi
  fi
  write_new_evidence_file containment-failure.txt \
    "$(printf 'rc=%s\ncommand=%s\n' "$rc" "$failure_command"; \
      [[ -z $failure_state ]] || printf 'failure_state=%s\n' "$failure_state")" || true
  echo "TRANSACTIONAL_RESTORE_CONTAINMENT_FAILED rc=$rc" >&2
  exit "$rc"
}
trap recover_on_error ERR
trap 'recover_on_error 130' HUP INT TERM

test "$(stat -c '%U:%G:%a' "$baseline_state")" = root:root:600
artifact_exact "$pocketbase" "$pocketbase_sha"
artifact_exact "$state_tool" "$state_tool_sha"
artifact_exact "$state_guard" "$state_guard_sha"
if [[ $disposable_clone == 0 ]]; then
  artifact_exact "$overlay_source" "$production_overlay_sha"
  [[ $overlay_runtime_sha == "$production_overlay_sha" ]]
  artifact_exact /etc/systemd/system/zar-server.service "$production_unit_sha"
  artifact_exact /etc/systemd/system/zar-server.service.d/10-hardening.conf \
    "$production_hardening_sha"
fi
artifact_exact "$migration_path" "$migration_sha"
artifact_exact "$helper_path" "$helper_sha"
artifact_exact "$route_path" "$route_sha"
artifact_exact "$overlay_target" "$overlay_runtime_sha"
systemctl is-active --quiet "$service"
test "$(systemctl show "$service" -p User --value)" = zarapp
test "$(systemctl show "$service" -p Group --value)" = zarapp
service_exec=$(systemctl show "$service" -p ExecStart --value)
assert_effective_exec "$service_exec"
if [[ $disposable_clone == 0 ]]; then
  systemctl is-active --quiet caddy
fi
curl -fsS "$health_url" >/dev/null
snapshot_state "$evidence/state.containment-before.json"
python3 "$state_guard" --state "$evidence/state.containment-before.json" \
  --expected "$expected_manifest" --profile contained
if [[ $reason == receipt && $(receipt_count "$evidence/state.containment-before.json") == 0 ]]; then
  echo 'receipt-present containment requires at least one receipt' >&2
  exit 78
fi

systemctl show "$service" -p NRestarts --value > "$evidence/nrestarts.containment-before.txt"
containment_in_progress=1
[[ $failpoint != before-contained-stop ]] || false
systemctl stop "$service"
if systemctl is-active --quiet "$service"; then false; fi
if ss -H -ltn "sport = :$port" | grep -q .; then
  false
fi
snapshot_state "$evidence/state.containment-stopped.json"
cmp -s "$evidence/state.containment-before.json" \
  "$evidence/state.containment-stopped.json"
artifact_exact "$route_path" "$route_sha"
mv -- "$route_path" "$evidence/route-hook.quarantined.js"
route_moved=1
artifact_exact "$evidence/route-hook.quarantined.js" "$route_sha"
service_start_and_wait
[[ $failpoint != after-contained-start ]] || false
test "$(curl -sS -o /dev/null -w '%{http_code}' \
  "http://127.0.0.1:$port/api/zar/restore/state")" = 404
test "$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  "http://127.0.0.1:$port/api/zar/restore/commit")" = 404
if [[ -n $admin_url ]]; then
  test "$(curl -sS -o /dev/null -w '%{http_code}' "$admin_url")" = 404
fi
snapshot_state "$evidence/state.containment-after.json"
cmp -s "$evidence/state.containment-before.json" \
  "$evidence/state.containment-after.json"
python3 "$state_guard" --state "$evidence/state.containment-after.json" \
  --expected "$expected_manifest" --profile contained
artifact_exact "$migration_path" "$migration_sha"
artifact_exact "$helper_path" "$helper_sha"
artifact_exact "$overlay_target" "$overlay_runtime_sha"
test ! -e "$route_path"
test "$(systemctl show "$service" -p NRestarts --value)" = \
  "$(cat "$evidence/nrestarts.containment-before.txt")"
journalctl -q -u "$service" -p err --since "$started_utc" --no-pager > \
  "$evidence/containment-error-journal.txt"
test ! -s "$evidence/containment-error-journal.txt"
if [[ $disposable_clone == 0 ]]; then
  systemctl is-active --quiet caddy
fi
printf 'TRANSACTIONAL_RESTORE_FORWARD_ONLY_CONTAINMENT_PASS\n' | \
  tee "$evidence/containment-result.txt"
containment_in_progress=0
