# ZAR+ external probe (owner PC): best-effort outside-in availability check.
# Runs every 15 min via Task Scheduler. On failure: Windows popup + log.
# Note: the PC is not always-on; this complements, not replaces, the on-VPS
# health check (zar-health-check.timer) which emails real alerts.
$ErrorActionPreference = "Stop"
$logDir = "$env:USERPROFILE\ZAR-Ops"
$log = "$logDir\external-probe.log"
$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
try {
    $resp = Invoke-WebRequest -Uri "https://app.titangold.ir/api/health" -TimeoutSec 20 -UseBasicParsing
    if ($resp.StatusCode -ne 200) { throw "HTTP $($resp.StatusCode)" }
    if ($resp.Content -notmatch "healthy") { throw "unexpected health body" }
    Add-Content $log "[$stamp] OK"
    exit 0
}
catch {
    $err = $_.Exception.Message
    Add-Content $log "[$stamp] FAIL: $err"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "ZAR+ is NOT reachable from this PC right now.`n`n$err`n`nLogged at $stamp",
        "ZAR+ availability alert", "OK", "Warning") | Out-Null
    exit 1
}
