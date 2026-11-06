#!/usr/bin/env bash
set -Eeuo pipefail

# Guarded deployment for the transactional-restore migration and hooks.
# There are no target defaults. The production path is accepted only with its
# exact service/filesystem boundary; failpoints are clone-only.

umask 077
readonly pinned_expected_manifest_sha=3102b85888016d479bf579c2e52e2fe6b0bee65910737dad7fc00a06bd9db4c3

data_dir=
migrations_dir=
hooks_dir=
migration_source=
helper_source=
route_source=
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
failpoint=
disposable_clone=0

usage() {
  cat >&2 <<'USAGE'
Usage: guarded_transactional_restore_deploy.sh \
  --data-dir ABSOLUTE_PATH \
  --migrations-dir ABSOLUTE_PATH \
  --hooks-dir ABSOLUTE_PATH \
  --migration-source ABSOLUTE_FILE \
  --helper-source ABSOLUTE_FILE \
  --route-source ABSOLUTE_FILE \
  --unit-overlay-source ABSOLUTE_FILE \
  --unit-overlay-target ABSOLUTE_FILE \
  --pocketbase ABSOLUTE_FILE \
  --service SYSTEMD_UNIT \
  --evidence ABSOLUTE_DIRECTORY \
  --baseline-state ABSOLUTE_FILE \
  --state-tool ABSOLUTE_FILE \
  --state-guard ABSOLUTE_FILE \
  --expected-manifest ABSOLUTE_FILE \
  --health-url LOOPBACK_URL \
  [--admin-url URL_EXPECTED_TO_RETURN_404] \
  [--confirm-disposable-clone] \
  [--failpoint after-migration-install|after-migrate-up|after-helper-install|after-route-install|after-unit-overlay|unhealthy-start|unvalidated-state-after-route|receipt-after-healthy-start]
USAGE
  exit 64
}

while (($#)); do
  case "$1" in
    --data-dir) data_dir=${2:-}; shift 2 ;;
    --migrations-dir) migrations_dir=${2:-}; shift 2 ;;
    --hooks-dir) hooks_dir=${2:-}; shift 2 ;;
    --migration-source) migration_source=${2:-}; shift 2 ;;
    --helper-source) helper_source=${2:-}; shift 2 ;;
    --route-source) route_source=${2:-}; shift 2 ;;
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
    --failpoint) failpoint=${2:-}; shift 2 ;;
    --confirm-disposable-clone) disposable_clone=1; shift ;;
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
for value in "$data_dir" "$migrations_dir" "$hooks_dir" "$migration_source" \
  "$helper_source" "$route_source" "$overlay_source" "$overlay_target" \
  "$pocketbase" "$evidence" "$baseline_state" "$state_tool" "$state_guard" \
  "$expected_manifest"; do
  [[ $value == /* && $value != / ]] || usage
  [[ $(realpath -m "$value") == "$value" ]] || usage
  [[ $value != *"'"* && $value != *$'\n'* ]] || usage
done
[[ $service == zar-*.service ]] || usage
[[ $health_url =~ ^http://127\.0\.0\.1:([0-9]+)/api/health$ ]] || usage
readonly port=${BASH_REMATCH[1]}
case "$failpoint" in
  ''|after-migration-install|after-migrate-up|after-helper-install|after-route-install|after-unit-overlay|unhealthy-start|unvalidated-state-after-route|receipt-after-healthy-start) ;;
  *) usage ;;
esac

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

for file in "$migration_source" "$helper_source" "$route_source" \
  "$overlay_source" "$pocketbase" "$baseline_state" "$state_tool" \
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
readonly migration_path=$migrations_dir/$migration_name
readonly helper_path=$hooks_dir/$helper_name
readonly route_path=$hooks_dir/$route_name
readonly db=$data_dir/data.db
readonly auxiliary_db=$data_dir/auxiliary.db
readonly started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
created_hooks_dir=0
targets_verified=0
stopped=0
recovering=0

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

validate_state() {
  local state=$1 profile=$2
  shift 2
  python3 "$state_guard" --state "$state" --expected "$expected_manifest" \
    --profile "$profile" "$@"
}

artifact_exact() {
  local file=$1 expected_sha=$2
  [[ -f $file && ! -L $file ]] && \
    [[ $(sha256sum "$file" | awk '{print $1}') == "$expected_sha" ]]
}

receipt_count() {
  python3 - "$1" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1], encoding="utf-8"))["restoreReceipts"]["count"])
PY
}

assert_effective_exec() {
  local service_exec=$1 expect_hooks=$2 actual
  [[ $service_exec == *"path=$pocketbase ;"* ]]
  [[ $service_exec == *"argv[]=$pocketbase serve "* ]]
  actual=$(grep -o -- '--http=[^ ;]*' <<<"$service_exec" || true)
  [[ $actual == "--http=127.0.0.1:$port" ]]
  if [[ $expect_hooks == 1 || $disposable_clone == 1 ]]; then
    actual=$(grep -o -- '--dir=[^ ;]*' <<<"$service_exec" || true)
    [[ $actual == "--dir=$data_dir" ]]
    actual=$(grep -o -- '--migrationsDir=[^ ;]*' <<<"$service_exec" || true)
    [[ $actual == "--migrationsDir=$migrations_dir" ]]
  else
    [[ $service_exec != *'--dir='* ]]
    [[ $service_exec != *'--migrationsDir='* ]]
    [[ $(systemctl show "$service" -p WorkingDirectory --value) == /opt/zar/server ]]
  fi
  if [[ $expect_hooks == 1 ]]; then
    actual=$(grep -o -- '--hooksDir=[^ ;]*' <<<"$service_exec" || true)
    [[ $actual == "--hooksDir=$hooks_dir" ]]
    actual=$(grep -o -- '--hooksWatch=[^ ;]*' <<<"$service_exec" || true)
    [[ $actual == '--hooksWatch=false' ]]
  else
    [[ $service_exec != *'--hooksDir='* ]]
    [[ $service_exec != *'--hooksWatch='* ]]
  fi
}

service_start_and_wait() {
  systemctl start "$service"
  for _ in $(seq 1 150); do
    if systemctl is-active --quiet "$service" && \
       curl -fsS "$health_url" >/dev/null 2>&1; then
      stopped=0
      return 0
    fi
    sleep 0.1
  done
  return 1
}

force_service_stopped() {
  systemctl stop "$service" >/dev/null 2>&1 || true
  if systemctl is-active --quiet "$service" || \
     ss -H -ltn "sport = :$port" | grep -q .; then
    systemctl kill --kill-who=all --signal=SIGKILL "$service" \
      >/dev/null 2>&1 || true
    systemctl stop "$service" >/dev/null 2>&1 || true
  fi
  if systemctl is-active --quiet "$service" || \
     ss -H -ltn "sport = :$port" | grep -q .; then
    return 1
  fi
  stopped=1
}

remove_exact_file() {
  local file=$1 expected_sha=$2 destination=$3
  if [[ -e $file || -L $file ]]; then
    artifact_exact "$file" "$expected_sha" || return 1
    mv -- "$file" "$destination"
  fi
}

restore_baseline_files() {
  remove_exact_file "$route_path" "$route_sha" "$evidence/recovered-route-hook.js" || return 1
  remove_exact_file "$helper_path" "$helper_sha" "$evidence/recovered-helper-hook.js" || return 1
  remove_exact_file "$overlay_target" \
    "$overlay_runtime_sha" \
    "$evidence/recovered-unit-overlay.conf" || return 1
  remove_exact_file "$migration_path" "$migration_sha" \
    "$evidence/recovered-migration.js" || return 1
  if [[ $created_hooks_dir == 1 && -d $hooks_dir ]]; then
    rmdir -- "$hooks_dir"
  fi
  systemctl daemon-reload
}

recover_on_error() {
  local rc=${1:-$?}
  [[ $recovering == 0 ]] || exit "$rc"
  recovering=1
  local failed_command=$BASH_COMMAND failed_line=${BASH_LINENO[0]:-unknown}
  trap - ERR HUP INT TERM
  set +e
  write_new_evidence_file deploy-failure.txt \
    "$(printf 'rc=%s\nline=%s\ncommand=%s\n' "$rc" "$failed_line" "$failed_command")" || true
  if [[ $targets_verified == 1 ]]; then
    if ! force_service_stopped; then
      printf 'recovery=stop-unverified-no-mutation\n' > \
        "$evidence/deploy-recovery.txt"
      echo 'service stop could not be verified; refusing file changes or migrate down' >&2
      echo "TRANSACTIONAL_RESTORE_DEPLOY_FAILED rc=$rc" >&2
      exit "$rc"
    fi
    stopped=1
    if [[ $failpoint == unvalidated-state-after-route ]]; then
      printf '{}\n' > "$evidence/state.failure.json"
    else
      snapshot_state "$evidence/state.failure.json" >/dev/null 2>&1
    fi
    if validate_state "$evidence/state.failure.json" before >/dev/null 2>&1 && \
       cmp -s "$baseline_state" "$evidence/state.failure.json"; then
      if restore_baseline_files; then
        if service_start_and_wait; then
          printf 'recovery=baseline-without-down\n' > "$evidence/deploy-recovery.txt"
        elif ! force_service_stopped; then
          echo 'baseline recovery restart failed and service inactivity could not be verified' >&2
        fi
      fi
    elif validate_state "$evidence/state.failure.json" after \
         --baseline "$baseline_state" --expected-receipt-count 0 >/dev/null 2>&1; then
      remove_exact_file "$route_path" "$route_sha" \
        "$evidence/recovered-route-hook.js" || true
      remove_exact_file "$helper_path" "$helper_sha" \
        "$evidence/recovered-helper-hook.js" || true
      remove_exact_file "$overlay_target" \
        "$overlay_runtime_sha" \
        "$evidence/recovered-unit-overlay.conf" || true
      systemctl daemon-reload >/dev/null 2>&1 || true
      if [[ ! -e $route_path && ! -e $helper_path && ! -e $overlay_target ]] && \
         artifact_exact "$migration_path" "$migration_sha"; then
        (cd /opt/zar/server && printf 'y\n' | runuser -u zarapp -- \
          "$pocketbase" migrate down 1 --dir="$data_dir" \
          --migrationsDir="$migrations_dir") >/dev/null 2>&1
        snapshot_state "$evidence/state.recovered-down.json" >/dev/null 2>&1
        if validate_state "$evidence/state.recovered-down.json" rolled-back \
             --baseline "$baseline_state" --expected-receipt-count 0 >/dev/null 2>&1 && \
            remove_exact_file "$migration_path" "$migration_sha" \
              "$evidence/recovered-migration.js"; then
          if [[ $created_hooks_dir == 1 && -d $hooks_dir ]]; then
            rmdir --ignore-fail-on-non-empty "$hooks_dir"
          fi
          if service_start_and_wait; then
            printf 'recovery=guarded-down\n' > "$evidence/deploy-recovery.txt"
          elif ! force_service_stopped; then
            echo 'guarded-down restart failed and service inactivity could not be verified' >&2
          fi
        fi
      fi
    elif validate_state "$evidence/state.failure.json" contained >/dev/null 2>&1 && \
         [[ $(receipt_count "$evidence/state.failure.json") -gt 0 ]] && \
         artifact_exact "$migration_path" "$migration_sha" && \
         artifact_exact "$helper_path" "$helper_sha" && \
         artifact_exact "$overlay_target" "$overlay_runtime_sha" && \
         artifact_exact "$route_path" "$route_sha"; then
      mv -- "$route_path" "$evidence/contained-route-hook.js"
      if [[ ! -e $route_path ]] && \
         artifact_exact "$evidence/contained-route-hook.js" "$route_sha"; then
        if service_start_and_wait; then
          printf 'recovery=receipt-forward-only-containment\n' > \
            "$evidence/deploy-recovery.txt"
        else
          force_service_stopped || \
            echo 'receipt recovery restart failed and service inactivity could not be verified' >&2
          printf 'recovery=receipt-containment-restart-failed-service-stopped\n' > \
            "$evidence/deploy-recovery.txt"
        fi
      fi
    else
      # A failed/invalid state capture is not evidence that the database is
      # safe to serve. Quarantine an exact route when possible, but never
      # restart until an operator obtains a contained-profile state proof.
      if artifact_exact "$route_path" "$route_sha"; then
        mv -- "$route_path" "$evidence/unvalidated-route-hook.js"
      fi
      force_service_stopped || \
        echo 'unvalidated recovery could not verify service inactivity' >&2
      if [[ ! -e $route_path ]] && \
         artifact_exact "$evidence/unvalidated-route-hook.js" "$route_sha"; then
        printf 'recovery=unvalidated-state-stopped-route-quarantined\n' > \
          "$evidence/deploy-recovery.txt"
      else
        printf 'recovery=unvalidated-state-stopped-route-needs-inspection\n' > \
          "$evidence/deploy-recovery.txt"
      fi
    fi
  fi
  echo "TRANSACTIONAL_RESTORE_DEPLOY_FAILED rc=$rc" >&2
  exit "$rc"
}
trap recover_on_error ERR
trap 'recover_on_error 130' HUP INT TERM

test "$(stat -c '%U:%G:%a' "$baseline_state")" = root:root:600
test -f "$db"
test -f "$auxiliary_db"
artifact_exact "$migration_source" "$migration_sha"
artifact_exact "$helper_source" "$helper_sha"
artifact_exact "$route_source" "$route_sha"
artifact_exact "$pocketbase" "$pocketbase_sha"
artifact_exact "$state_tool" "$state_tool_sha"
artifact_exact "$state_guard" "$state_guard_sha"
if [[ $disposable_clone == 0 ]]; then
  artifact_exact "$overlay_source" "$production_overlay_sha"
  [[ $overlay_runtime_sha == "$production_overlay_sha" ]]
  artifact_exact /etc/systemd/system/zar-server.service \
    "$(json_get "$expected_manifest" productionBaseline.unitSha256)"
  artifact_exact /etc/systemd/system/zar-server.service.d/10-hardening.conf \
    "$(json_get "$expected_manifest" productionBaseline.hardeningDropInSha256)"
fi
test ! -e "$migration_path"
test ! -L "$migration_path"
test ! -e "$helper_path"
test ! -L "$helper_path"
test ! -e "$route_path"
test ! -L "$route_path"
test ! -e "$overlay_target"
test ! -L "$overlay_target"
test "$(stat -c '%U:%G:%a' "$migrations_dir")" = root:root:755
if [[ -e $hooks_dir || -L $hooks_dir ]]; then
  test -d "$hooks_dir"
  test ! -L "$hooks_dir"
  test "$(stat -c '%U:%G:%a' "$hooks_dir")" = root:root:755
fi
systemctl is-active --quiet "$service"
test "$(systemctl show "$service" -p User --value)" = zarapp
test "$(systemctl show "$service" -p Group --value)" = zarapp
service_exec=$(systemctl show "$service" -p ExecStart --value)
assert_effective_exec "$service_exec" 0
if [[ $disposable_clone == 0 ]]; then
  systemctl is-active --quiet caddy
fi
curl -fsS "$health_url" >/dev/null
snapshot_state "$evidence/state.preflight.json"
cmp -s "$baseline_state" "$evidence/state.preflight.json"
validate_state "$evidence/state.preflight.json" before --expected-receipt-count 0

targets_verified=1
systemctl show "$service" -p NRestarts --value > "$evidence/nrestarts.before.txt"
systemctl stop "$service"
if systemctl is-active --quiet "$service"; then
  false
fi
if ss -H -ltn "sport = :$port" | grep -q .; then
  false
fi
stopped=1
snapshot_state "$evidence/state.stopped-before.json"
cmp -s "$baseline_state" "$evidence/state.stopped-before.json"

install -o root -g root -m 0644 "$migration_source" "$migration_path"
artifact_exact "$migration_path" "$migration_sha"
[[ $failpoint != after-migration-install ]] || false

(cd /opt/zar/server && runuser -u zarapp -- "$pocketbase" migrate up \
  --dir="$data_dir" --migrationsDir="$migrations_dir")
snapshot_state "$evidence/state.after-migrate.json"
validate_state "$evidence/state.after-migrate.json" after \
  --baseline "$baseline_state" --expected-receipt-count 0
[[ $failpoint != after-migrate-up ]] || false

if [[ ! -e $hooks_dir ]]; then
  install -d -o root -g root -m 0755 "$hooks_dir"
  created_hooks_dir=1
fi
install -o root -g root -m 0644 "$helper_source" "$helper_path"
artifact_exact "$helper_path" "$helper_sha"
[[ $failpoint != after-helper-install ]] || false
install -o root -g root -m 0644 "$route_source" "$route_path"
artifact_exact "$route_path" "$route_sha"
[[ $failpoint != after-route-install ]] || false
[[ $failpoint != unvalidated-state-after-route ]] || false

install -d -o root -g root -m 0755 "$(dirname "$overlay_target")"
install -o root -g root -m 0644 "$overlay_source" "$overlay_target"
artifact_exact "$overlay_target" "$overlay_runtime_sha"
systemd-analyze verify "$service"
systemctl daemon-reload
[[ $failpoint != after-unit-overlay ]] || false

if [[ $failpoint == unhealthy-start ]]; then
  systemctl start "$service"
  sleep 0.2
  false
fi
service_start_and_wait
service_exec=$(systemctl show "$service" -p ExecStart --value)
assert_effective_exec "$service_exec" 1
test "$(curl -sS -o /dev/null -w '%{http_code}' \
  "http://127.0.0.1:$port/api/zar/restore/state")" = 401
if [[ -n $admin_url ]]; then
  test "$(curl -sS -o /dev/null -w '%{http_code}' "$admin_url")" = 404
fi
snapshot_state "$evidence/state.after-start.json"
validate_state "$evidence/state.after-start.json" after \
  --baseline "$baseline_state" --expected-receipt-count 0
if [[ $failpoint == receipt-after-healthy-start ]]; then
  printf 'ready-for-client\n' > "$evidence/receipt-failpoint-ready.txt"
  receipt_seen=0
  for _ in $(seq 1 300); do
    if [[ -f $evidence/receipt-client-complete.txt && \
          ! -L $evidence/receipt-client-complete.txt && \
          $(stat -c '%U:%G:%a' "$evidence/receipt-client-complete.txt") == root:root:600 ]] && \
       grep -qx client-complete "$evidence/receipt-client-complete.txt" && \
       snapshot_state "$evidence/state.waiting-for-receipt.json" \
         >/dev/null 2>&1 && \
       validate_state "$evidence/state.waiting-for-receipt.json" contained \
         >/dev/null 2>&1 && \
       [[ $(receipt_count "$evidence/state.waiting-for-receipt.json") -gt 0 ]]; then
      receipt_seen=1
      break
    fi
    sleep 0.1
  done
  [[ $receipt_seen == 1 ]] || false
  false
fi
test "$(systemctl show "$service" -p NRestarts --value)" = \
  "$(cat "$evidence/nrestarts.before.txt")"
journalctl -q -u "$service" -p err --since "$started_utc" --no-pager > \
  "$evidence/deploy-error-journal.txt"
test ! -s "$evidence/deploy-error-journal.txt"
printf 'TRANSACTIONAL_RESTORE_DEPLOY_PASS\n' | tee "$evidence/deploy-result.txt"
