# ZAR+ external probe (owner PC): best-effort outside-in availability check.
# Runs every 15 min via Task Scheduler. On failure: Windows popup + log.
# Note: the PC is not always-on; this complements, not replaces, the on-VPS
# health check (zar-health-check.timer) which emails real alerts.
#
# Checks:
#   1) https://app.titangold.ir/api/health → 200 + healthy body
#   2) TLS leaf for app.titangold.ir has > 14 days remaining (client view)
#   3) Newest local off-site snapshot under Documents\ZAR-OffsiteBackups
#      is younger than 50h (daily pull; PC may miss one night)
$ErrorActionPreference = "Stop"
$logDir = "$env:USERPROFILE\ZAR-Ops"
$log = "$logDir\external-probe.log"
$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$hostName = "app.titangold.ir"
$offsiteRoot = Join-Path $env:USERPROFILE "Documents\ZAR-OffsiteBackups"
$tlsMinDays = 14
$offsiteMaxAgeHours = 50

function Get-TlsDaysRemaining([string]$TargetHost, [int]$Port = 443) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $tcp.ReceiveTimeout = 15000
        $tcp.SendTimeout = 15000
        $tcp.Connect($TargetHost, $Port)
        $ssl = New-Object System.Net.Security.SslStream($tcp.GetStream(), $false, { $true })
        try {
            $ssl.AuthenticateAsClient($TargetHost)
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
            $remaining = [Math]::Floor(($cert.NotAfter.ToUniversalTime() - [DateTime]::UtcNow).TotalDays)
            return [pscustomobject]@{
                DaysRemaining = [int]$remaining
                NotAfterUtc   = $cert.NotAfter.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        }
        finally {
            $ssl.Dispose()
        }
    }
    finally {
        $tcp.Dispose()
    }
}

function Get-OffsiteBackupAgeHours([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root)) {
        throw "offsite root missing: $Root"
    }
    $latest = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction Stop |
        Where-Object { $_.Name -match '^zar-\d{8}T\d{6}Z$' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) {
        throw "no zar-* snapshot directories under $Root"
    }
    if ($latest.Name -notmatch '^zar-(\d{8})T(\d{6})Z$') {
        throw "unparseable snapshot name: $($latest.Name)"
    }
    $stampUtc = [DateTime]::ParseExact(
        "$($Matches[1])$($Matches[2])",
        "yyyyMMddHHmmss",
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    )
    $ageHours = [Math]::Round(([DateTime]::UtcNow - $stampUtc).TotalHours, 1)
    return [pscustomobject]@{
        Name     = $latest.Name
        AgeHours = $ageHours
    }
}

try {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null

    $resp = Invoke-WebRequest -Uri "https://$hostName/api/health" -TimeoutSec 20 -UseBasicParsing
    if ($resp.StatusCode -ne 200) { throw "HTTP $($resp.StatusCode)" }
    if ($resp.Content -notmatch "healthy") { throw "unexpected health body" }

    $tls = Get-TlsDaysRemaining $hostName
    if ($tls.DaysRemaining -le $tlsMinDays) {
        throw "TLS expires in $($tls.DaysRemaining)d (threshold >${tlsMinDays}d; notAfter=$($tls.NotAfterUtc))"
    }

    $offsite = Get-OffsiteBackupAgeHours $offsiteRoot
    if ($offsite.AgeHours -ge $offsiteMaxAgeHours) {
        throw "offsite backup $($offsite.Name) is $($offsite.AgeHours)h old (threshold ${offsiteMaxAgeHours}h)"
    }

    Add-Content $log "[$stamp] OK health=200 tlsDays=$($tls.DaysRemaining) offsite=$($offsite.Name) ageHours=$($offsite.AgeHours)"
    exit 0
}
catch {
    $err = $_.Exception.Message
    Add-Content $log "[$stamp] FAIL: $err"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "ZAR+ external probe FAILED.`n`n$err`n`nLogged at $stamp",
        "ZAR+ availability alert", "OK", "Warning") | Out-Null
    exit 1
}
