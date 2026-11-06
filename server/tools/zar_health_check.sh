#!/usr/bin/env bash
# ZAR+ internal health check: on failure, email the owner via the local
# self-hosted Postfix. Read-only checks only; never repairs anything.
# Install: /usr/local/sbin/zar-health-check (root:root 0755)
set -uo pipefail

ALERT_TO="raeisi.sep@gmail.com"
FROM="noreply@titangold.ir"
STATE_DIR="/var/lib/zar-health"
STATE_FILE="$STATE_DIR/last-alerts"
DEDUPE_SECONDS=$((6 * 3600))

failures=()
now=$(date +%s)

report() {
    local check=$1 detail=$2
    failures+=("$check: $detail")
}

# 1) core services
for unit in zar-server.service caddy.service zar-backup.timer; do
    if [ "$(systemctl is-active "$unit")" != "active" ]; then
        report "$unit" "unit is $(systemctl is-active "$unit")"
    fi
done

# 2) loopback health endpoint
health_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://127.0.0.1:8090/api/health || echo 000)
[ "$health_code" = "200" ] || report "health-endpoint" "loopback /api/health returned $health_code (expected 200)"

# 3) PocketBase must listen on loopback only
if ss -tln | awk '{print $4}' | grep -E '(^|\.)8090$' | grep -qv '127.0.0.1'; then
    report "listener" "port 8090 is listening on a non-loopback address"
fi

# 4) disk usage
usage=$(df --output=pcent / | tail -1 | tr -dc 0-9)
[ -n "$usage" ] && [ "$usage" -lt 85 ] || report "disk" "root filesystem usage ${usage:-unknown}% (threshold 85%)"

# 5) latest backup age < 26h
latest_backup=$(ls -1t /backups/zar-daily 2>/dev/null | grep -E '^zar-[0-9]{8}T[0-9]{6}Z$' | head -1)
if [ -z "$latest_backup" ]; then
    report "backup" "no snapshot directory found in /backups/zar-daily"
else
    ts=$(echo "$latest_backup" | sed -E 's/zar-([0-9]{8})T([0-9]{6})Z/\1\2/')
    bt=$(date -d "${ts:0:4}-${ts:4:2}-${ts:6:2} ${ts:8:2}:${ts:10:2}:${ts:12:2} UTC" +%s 2>/dev/null)
    age=$(( now - bt ))
    [ "$age" -lt $((26 * 3600)) ] || report "backup" "latest snapshot $latest_backup is $((age / 3600))h old (threshold 26h)"
fi

# 6) TLS certificate of app.titangold.ir (> 14 days left)
expires_at=$(echo | openssl s_client -connect 127.0.0.1:443 -servername app.titangold.ir 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$expires_at" ]; then
    exp=$(date -d "$expires_at" +%s 2>/dev/null)
    days=$(( (exp - now) / 86400 ))
    [ "$days" -gt 14 ] || report "tls" "app.titangold.ir certificate expires in $days days"
else
    report "tls" "could not read local TLS certificate"
fi

# 7) restart sanity
restarts=$(systemctl show zar-server -p NRestarts --value)
[ -n "$restarts" ] && [ "$restarts" -lt 3 ] || report "restarts" "zar-server NRestarts=$restarts (possible restart loop)"

# email alerts, deduped per failing check
mkdir -p "$STATE_DIR"
touch "$STATE_FILE"
if [ "${#failures[@]}" -gt 0 ]; then
    body="ZAR+ health check FAILED on $(hostname) at $(date -u +%FT%TZ)."$'\n\n'
    sent_any=0
    for f in "${failures[@]}"; do
        key=${f%%: *}
        last=$(grep -E "^${key}=" "$STATE_FILE" | tail -1 | cut -d= -f2)
        if [ -z "$last" ] || [ $(( now - last )) -ge $DEDUPE_SECONDS ]; then
            body+="- $f"$'\n'
            sed -i "/^${key}=/d" "$STATE_FILE"
            echo "${key}=${now}" >> "$STATE_FILE"
            sent_any=1
        fi
    done
    if [ "$sent_any" = "1" ]; then
        python3 - "$ALERT_TO" "$FROM" "$body" <<'PYEOF'
import smtplib, sys
from email.message import EmailMessage
to, frm, body = sys.argv[1], sys.argv[2], sys.argv[3]
m = EmailMessage()
m["From"] = frm
m["To"] = to
m["Subject"] = "ZAR+ ALERT: health check failed"
m.set_content(body)
with smtplib.SMTP("127.0.0.1", 25, timeout=30) as s:
    s.send_message(m)
PYEOF
    fi
    exit 1
fi
exit 0
