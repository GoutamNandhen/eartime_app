param([string]$PreviousRef = 'HEAD', [switch]$SelfTest)
$ErrorActionPreference = 'Stop'

function Read-AppVersion([string]$Text) {
    $lines = [regex]::Matches($Text, '(?m)^version: ([^\r\n]+)\r?$')
    if ($lines.Count -ne 1) { throw 'Exactly one top-level version scalar is required.' }
    $value = $lines[0].Groups[1].Value.Trim()
    $match = [regex]::Match($value, '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(dev|rc)\.[1-9][0-9]*)?\+([1-9][0-9]*)$')
    if (!$match.Success) { throw 'Invalid EarTime version format.' }
    [long]$code = 0
    if (![long]::TryParse($match.Groups[6].Value, [ref]$code) -or $code -gt 2100000000) { throw 'Invalid Android build number.' }
    return [pscustomobject]@{ Value = $value; Code = $code }
}

function Assert-VersionProgress($Current, $Previous) {
    if ($Current.Code -lt $Previous.Code -or ($Current.Value -ne $Previous.Value -and $Current.Code -le $Previous.Code)) {
        throw 'A changed version must increase the build number; published numbers must never be reused or decreased.'
    }
}

if ($SelfTest) {
    $count = 0
    foreach ($valid in @('1.0.0+1', '1.1.0-dev.1+2', '1.1.0-rc.1+3', '1.1.0+2100000000')) {
        $null = Read-AppVersion "version: $valid"; $count++
    }
    $null = Read-AppVersion "name: eartime_app`r`nversion: 1.1.0-dev.1+2`r`nenvironment:`r`n"; $count++
    foreach ($bad in @('1.0+1', '01.0.0+1', '1.0.0+0', '1.0.0+01', '1.0.0+2100000001', '1.0.0-dev.0+2', '1.0.0+9223372036854775808', "1.0.0+1`nversion: 1.0.1+2")) {
        $failed = $false
        try { $null = Read-AppVersion "version: $bad" } catch { $failed = $true }
        if (!$failed) { throw 'Invalid version was accepted.' }; $count++
    }
    $base = Read-AppVersion 'version: 1.0.0+1'
    Assert-VersionProgress $base $base; $count++
    Assert-VersionProgress (Read-AppVersion 'version: 1.1.0-dev.1+2') $base; $count++
    foreach ($bad in @('1.0.1+1', '1.0.0+1')) {
        $failed = $false
        try { Assert-VersionProgress (Read-AppVersion "version: $bad") (Read-AppVersion 'version: 1.1.0-dev.1+2') } catch { $failed = $true }
        if (!$failed) { throw 'Reused or decreasing build number was accepted.' }; $count++
    }
    Write-Output "App version self-tests passed: $count cases."
    exit 0
}

$root = Split-Path -Parent $PSScriptRoot
$current = Read-AppVersion (Get-Content -LiteralPath (Join-Path $root 'pubspec.yaml') -Raw)
$previousText = & git -C $root show "${PreviousRef}:pubspec.yaml"
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the comparison version; no version validation performed.' }
$previous = Read-AppVersion ($previousText -join "`n")
Assert-VersionProgress $current $previous
Write-Output "App version gate passed: $($current.Value), compared with $($previous.Value)."
