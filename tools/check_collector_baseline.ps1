param([switch]$AllowObserverLifecycleHooks, [string]$Revision = '')
$ErrorActionPreference = 'Stop'
$path = 'android/app/src/main/kotlin/com/eartime/eartime_app/tracking/AudioTrackingService.kt'
$baseline = @(git show "0a8be43:$path")
if ($LASTEXITCODE -ne 0) { throw 'Cannot read protected collector baseline' }
if ($Revision) {
    $current = @(git show "${Revision}:$path")
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read candidate collector' }
} else { $current = @(Get-Content -LiteralPath $path) }
if (($current -join "`n") -ceq ($baseline -join "`n")) {
    Write-Output 'Collector source equals 0a8be43 (Git-normalized lines). Physical G remains unvalidated.'
    exit 0
}
if (-not $AllowObserverLifecycleHooks) { throw 'Collector source differs from 0a8be43; equality check FAILED' }
$hooks = @{
    '    private var inventoryObserver: SupportedAudioObserver? = null' = 1
    '            inventoryObserver?.close()' = 1
    '        if (inventoryObserver?.isClosed != false) inventoryObserver = SupportedAudioObserver.start(applicationContext)' = 1
    '        inventoryObserver?.close()' = 1
}
foreach ($line in $hooks.Keys) {
    if (@($current | Where-Object { $_ -ceq $line }).Count -ne $hooks[$line]) {
        throw 'Collector has an unexpected observer hook count or spelling'
    }
}
$withoutHooks = @($current | Where-Object { -not $hooks.ContainsKey($_) })
if (($withoutHooks -join "`n") -cne ($baseline -join "`n")) {
    throw 'Collector has changes beyond the four reviewed lifecycle additions'
}
Write-Output 'Source equality: FALSE. Exactly four observer lifecycle additions; all existing collector lines match 0a8be43. Physical G remains unvalidated.'
