[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SourceDirectory,

    [Parameter(Mandatory = $true)]
    [string] $DestinationDirectory,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string] $BundleName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'This interim bundle tool requires Windows DPAPI.'
}

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string] $Path)
    return [IO.Path]::GetFullPath($Path)
}

function Invoke-GpgWithSecret {
    param(
        [Parameter(Mandatory = $true)][string] $GpgPath,
        [Parameter(Mandatory = $true)][string[]] $Arguments,
        [Parameter(Mandatory = $true)][string] $Secret
    )

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GpgPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        $null = $startInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'Failed to start GnuPG.'
    }
    $process.StandardInput.WriteLine($Secret)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "GnuPG failed with exit $($process.ExitCode): $stderr$stdout"
    }
}

function Set-PrivateDirectoryAcl {
    param([Parameter(Mandatory = $true)][string] $Path)

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $arguments = @(
        $Path,
        '/inheritance:r',
        '/grant:r',
        "${identity}:(OI)(CI)F",
        'SYSTEM:(OI)(CI)F'
    )
    $output = & icacls.exe @arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to restrict recovery directory ACL: $output"
    }
}

function Remove-SafeTemporaryDirectory {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $resolved = Resolve-FullPath $Path
    $tempRoot = (Resolve-FullPath ([IO.Path]::GetTempPath())).TrimEnd('\') + '\'
    $leaf = Split-Path -Leaf $resolved
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        -not $leaf.StartsWith('zar-recovery-', [StringComparison]::Ordinal)) {
        throw "Refusing to remove unexpected temporary path: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

$source = Resolve-FullPath $SourceDirectory
$destination = Resolve-FullPath $DestinationDirectory
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Recovery source directory not found: $source"
}
foreach ($required in @('data.db', 'pb_migrations')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $required))) {
        throw "Recovery source is missing required item: $required"
    }
}

$gpg = Get-Command gpg -ErrorAction Stop
$tar = Get-Command tar -ErrorAction Stop
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Set-PrivateDirectoryAcl -Path $destination

$bundlePath = Join-Path $destination "$BundleName.tar.gpg"
$keyPath = Join-Path $destination "$BundleName.key.dpapi"
$evidencePath = Join-Path $destination "$BundleName.evidence.json"
foreach ($outputPath in @($bundlePath, $keyPath, $evidencePath)) {
    if (Test-Path -LiteralPath $outputPath) {
        throw "Refusing to overwrite existing recovery artifact: $outputPath"
    }
}

$temporary = Join-Path ([IO.Path]::GetTempPath()) "zar-recovery-$([Guid]::NewGuid().ToString('N'))"
$staging = Join-Path $temporary 'staging'
$plainArchive = Join-Path $temporary "$BundleName.tar"
$verificationArchive = Join-Path $temporary 'verification.tar'
$verificationDirectory = Join-Path $temporary 'verification'

try {
    New-Item -ItemType Directory -Path $staging | Out-Null
    New-Item -ItemType Directory -Path $verificationDirectory | Out-Null
    Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
        if ($_.Name -notin @('data.db-wal', 'data.db-shm')) {
            Copy-Item -LiteralPath $_.FullName -Destination $staging -Recurse
        }
    }

    $readme = @'
ZAR+ interim encrypted recovery bundle.

The .key.dpapi file can be unwrapped only by the same Windows user on the
same Windows installation. This is a temporary pre-customer control, not an
independent off-site disaster-recovery solution. Keep both files private.
'@
    [IO.File]::WriteAllText(
        (Join-Path $staging 'RECOVERY-README.txt'),
        $readme,
        [Text.UTF8Encoding]::new($false)
    )

    $manifestFiles = @(
        Get-ChildItem -LiteralPath $staging -File -Recurse |
            Sort-Object FullName |
            ForEach-Object {
                $relative = $_.FullName.Substring($staging.Length + 1).Replace('\', '/')
                [ordered]@{
                    path = $relative
                    length = $_.Length
                    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
                }
            }
    )
    $manifest = [ordered]@{
        schemaVersion = 1
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        bundleName = $BundleName
        encryption = 'GnuPG symmetric AES256; passphrase wrapped with Windows DPAPI CurrentUser'
        files = $manifestFiles
    }
    [IO.File]::WriteAllText(
        (Join-Path $staging 'MANIFEST.json'),
        (($manifest | ConvertTo-Json -Depth 8) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )

    & $tar.Source -cf $plainArchive -C $staging .
    if ($LASTEXITCODE -ne 0) {
        throw "tar archive creation failed with exit $LASTEXITCODE"
    }

    $randomBytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
    $passphrase = [Convert]::ToBase64String($randomBytes)
    [Array]::Clear($randomBytes, 0, $randomBytes.Length)
    $securePassphrase = ConvertTo-SecureString $passphrase -AsPlainText -Force
    $protectedPassphrase = ConvertFrom-SecureString $securePassphrase
    [IO.File]::WriteAllText(
        $keyPath,
        "$protectedPassphrase`n",
        [Text.UTF8Encoding]::new($false)
    )

    Invoke-GpgWithSecret -GpgPath $gpg.Source -Secret $passphrase -Arguments @(
        '--batch',
        '--yes',
        '--pinentry-mode', 'loopback',
        '--passphrase-fd', '0',
        '--symmetric',
        '--cipher-algo', 'AES256',
        '--output', $bundlePath,
        $plainArchive
    )

    Invoke-GpgWithSecret -GpgPath $gpg.Source -Secret $passphrase -Arguments @(
        '--batch',
        '--yes',
        '--pinentry-mode', 'loopback',
        '--passphrase-fd', '0',
        '--decrypt',
        '--output', $verificationArchive,
        $bundlePath
    )
    $passphrase = $null

    & $tar.Source -xf $verificationArchive -C $verificationDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "tar verification extraction failed with exit $LASTEXITCODE"
    }

    $verifiedManifest = Get-Content -LiteralPath (Join-Path $verificationDirectory 'MANIFEST.json') -Raw |
        ConvertFrom-Json
    foreach ($file in $verifiedManifest.files) {
        $candidate = Join-Path $verificationDirectory ([string] $file.path)
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "Bundle verification is missing file: $($file.path)"
        }
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash.ToLowerInvariant()
        if ($actualHash -ne [string] $file.sha256) {
            throw "Bundle verification hash mismatch: $($file.path)"
        }
    }

    $evidence = [ordered]@{
        schemaVersion = 1
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        bundleName = $BundleName
        bundleFile = Split-Path -Leaf $bundlePath
        bundleLength = (Get-Item -LiteralPath $bundlePath).Length
        bundleSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $bundlePath).Hash.ToLowerInvariant()
        keyFile = Split-Path -Leaf $keyPath
        keySha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $keyPath).Hash.ToLowerInvariant()
        fileCount = @($verifiedManifest.files).Count
        decryptAndManifestVerification = 'pass'
        dpapiScope = 'CurrentUser / current Windows installation'
    }
    [IO.File]::WriteAllText(
        $evidencePath,
        (($evidence | ConvertTo-Json -Depth 5) + "`n"),
        [Text.UTF8Encoding]::new($false)
    )
    Set-PrivateDirectoryAcl -Path $destination

    [pscustomobject]@{
        Status = 'pass'
        Bundle = $bundlePath
        BundleSha256 = $evidence.bundleSha256
        ProtectedKey = $keyPath
        Evidence = $evidencePath
        VerifiedFiles = $evidence.fileCount
    }
}
finally {
    Remove-SafeTemporaryDirectory -Path $temporary
}
