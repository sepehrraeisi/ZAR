# ZAR+ off-site backup pull (owner PC -> independent copy of server snapshots)
# Read-only on the server: uses `sudo -n cat` over the existing zar-vps SSH alias.
# Scheduling: schtasks /Create /TN "ZAR Offsite Backup Pull" /SC DAILY /ST 08:00 /F ^
#   /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0pull-offsite-backups.ps1\""
# Acceptance per snapshot: byte-identical SHA-256 vs server SHA256SUMS + SQLite quick_check ok.

param(
    [string]$DestRoot = "$env:USERPROFILE\Documents\ZAR-OffsiteBackups",
    [string]$SshAlias = "zar-vps",
    [string]$RemoteRoot = "/backups/zar-daily",
    [int]$KeepLast = 14
)

$ErrorActionPreference = "Stop"
$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$logLines = New-Object System.Collections.Generic.List[string]
function Log($msg) {
    $line = "[$stamp] $msg"
    $logLines.Add($line)
    Write-Host $line
}

$status = @{
    utcTime  = $stamp
    ok       = $false
    pulled   = @()
    verified = @()
    errors   = @()
    latestLocalSnapshot = $null
}

try {
    New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null

    # 1) List remote snapshots (read-only)
    $remote = (ssh $SshAlias "sudo -n ls -1 $RemoteRoot" 2>$error) |
        Where-Object { $_ -match "^zar-\d{8}T\d{6}Z$" } | Sort-Object
    if (-not $remote -or $remote.Count -eq 0) { throw "no remote snapshots listed via ssh" }
    Log ("remote snapshots: " + $remote.Count)

    # 2) Determine which are missing locally
    $localDirs = Get-ChildItem -Directory -Path $DestRoot -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^zar-\d{8}T\d{6}Z$" } | Select-Object -ExpandProperty Name
    $missing = $remote | Where-Object { $localDirs -notcontains $_ }
    Log ("missing locally: " + ($missing -join ", "))

    foreach ($snap in $missing) {
        $dest = Join-Path $DestRoot $snap
        New-Item -ItemType Directory -Force -Path $dest | Out-Null

        foreach ($file in @("SHA256SUMS", "METADATA", "data.db")) {
            $remotePath = "$RemoteRoot/$snap/$file"
            $localPath = Join-Path $dest $file
            # cmd redirect keeps the stream byte-exact (PowerShell pipes would re-encode)
            cmd /c "ssh $SshAlias `"sudo -n cat $remotePath`" > `"$localPath`"" 2>$null
            if (-not (Test-Path $localPath)) { throw "download failed: $remotePath" }
            if ($file -ne "data.db") {
                $size = (Get-Item $localPath).Length
                if ($size -le 0) { throw "downloaded empty: $remotePath" }
            }
        }

        # 3) Verify SHA-256 against the server's own SHA256SUMS
        $sums = Get-Content (Join-Path $dest "SHA256SUMS")
        foreach ($line in $sums) {
            if ($line -match "^([0-9a-f]{64})\s+(\S+)$") {
                $expected = $Matches[1]; $name = $Matches[2]
                $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $dest $name)).Hash.ToLowerInvariant()
                if ($actual -ne $expected) { throw "SHA-256 mismatch for $snap/$name" }
                Log "verified $snap/$name"
                $status.verified += "$snap/$name"
            }
        }

        # 4) SQLite integrity (quick_check) on the pulled data.db
        $db = Join-Path $dest "data.db"
        $check = python -c "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); r=c.execute('PRAGMA quick_check').fetchone(); c.close(); sys.exit(0 if r and r[0]=='ok' else 2)" $db
        if ($LASTEXITCODE -ne 0) { throw "sqlite quick_check failed for $snap/data.db" }
        Log "quick_check ok: $snap/data.db"

        $status.pulled += $snap
    }

    # 5) Retention: keep only the newest $KeepLast local snapshots
    $allLocal = Get-ChildItem -Directory -Path $DestRoot |
        Where-Object { $_.Name -match "^zar-\d{8}T\d{6}Z$" } | Sort-Object Name
    if ($allLocal.Count -gt $KeepLast) {
        $allLocal | Select-Object -First ($allLocal.Count - $KeepLast) | ForEach-Object {
            Remove-Item -Recurse -Force $_.FullName
            Log "pruned old snapshot $($_.Name)"
        }
    }

    $status.ok = $true
    $status.latestLocalSnapshot = ($allLocal | Select-Object -Last 1).Name
    Log "SUCCESS: off-site copy in sync (latest: $($status.latestLocalSnapshot))"
}
catch {
    $status.errors += $_.Exception.Message
    Log "ERROR: $($_.Exception.Message)"
}
finally {
    $status | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $DestRoot "last-pull-status.json") -Encoding UTF8
    Add-Content (Join-Path $DestRoot "pull-log.txt") ($logLines -join [Environment]::NewLine) -Encoding UTF8
}

if (-not $status.ok) { exit 1 }
