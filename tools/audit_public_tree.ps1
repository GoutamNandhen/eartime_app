param([string]$Revision = '')
$ErrorActionPreference = 'Stop'

# Read the exact Git candidate, not ignored working files or credential stores.
if ($Revision) { $files = @(git ls-tree -r --name-only $Revision) }
else { $files = @(git ls-files --cached) }
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate the candidate Git tree' }

$syntheticAddresses = @(
    '00:00:00:00:00:00', '02:00:00:00:00:00', '02:11:22:33:44:55',
    '00:11:22:33:44:55', '11:22:33:44:55:66', 'AA:BB:CC:DD:EE:FF',
    'AA:BB:CC:DD:EE:01', 'AA:BB:CC:DD:EE:02', 'AA:BB:CC:DD:EE:03',
    'AA:BB:CC:DD:EE:04', 'AA:BB:CC:DD:EE:05'
)
$issues = [Collections.Generic.List[string]]::new()
$textCount = 0
foreach ($path in $files) {
    if ($path -match '(?i)(^|/)(?:\.local-checkpoints|build|coverage|research|decompiled|jadx|logs)(/|$)' -or
        $path -match '(?i)(?:\.(?:apk|aab|jks|keystore|p12|pem|key|db|sqlite|hprof|log|docx)|\.db-[^/]+|\.sqlite-[^/]+)$' -or
        $path -match '(?i)(^|/)(?:\.env(?:\..*)?|local\.properties|key\.properties|screen\.png|G_failure\.txt|g_experiment[^/]*|test_first_frame\.dart)$') {
        $issues.Add("Forbidden artifact path: $path")
        continue
    }
    if ($path -match '(?i)\.(png|ico)$') {
        if ($path -notmatch '(^android/app/src/main/res/mipmap-|Assets\.xcassets/(AppIcon|LaunchImage)\.|^windows/runner/resources/app_icon\.ico$)') {
            $issues.Add("Unreviewed binary asset: $path")
        }
        continue
    }
    $object = if ($Revision) { "${Revision}:$path" } else { ":$path" }
    $lines = @(git show $object)
    if ($LASTEXITCODE -ne 0) { throw "Cannot read candidate file: $path" }
    $content = $lines -join "`n"
    $textCount++
    if ($content.Contains([char]0)) { $issues.Add("NUL/binary data in text candidate: $path") }
    if ($content -match '(?i)(?:github_pat_[a-z0-9_]{15,}|gh[pousr]_[a-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY)') {
        $issues.Add("Credential-shaped content: $path")
    }
    if ($content -match '(?i)(?:[A-Z]:[\\/](?:Users|projects)[\\/]|(?<![.A-Za-z0-9])/(?:Users|home)/[^\s/]+/)') {
        $issues.Add("Machine-specific private path: $path")
    }
    foreach ($match in [regex]::Matches($content, '(?i)(?:[0-9a-f]{2}:){5}[0-9a-f]{2}')) {
        if ($match.Value.ToUpperInvariant() -notin $syntheticAddresses) {
            $issues.Add("Non-fixture device address: $path")
            break
        }
    }
}
if ($issues.Count) {
    $issues | ForEach-Object { Write-Output $_ }
    throw "Public-tree audit failed: $($issues.Count) finding(s). Matched values are not printed."
}
Write-Output "Public-tree audit passed: $($files.Count) files, $textCount text candidates; no prohibited matches."
