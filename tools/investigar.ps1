# Looks inside the installed Claude Desktop and reports whether the pieces the
# multi-account method depends on are still there. Used by the /claude-contas
# Claude Code skill when a new app version breaks something.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\investigar.ps1 [-Out <dir>]
#
# Needs Node.js (for tools\asar-extract.js). Read-only: copies the app archive to
# a temp folder and never touches the installed app or any profile.
param([string]$Out = (Join-Path $env:TEMP 'claude-contas-investigacao'))
$ErrorActionPreference = 'Stop'

$pkg = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Claude*' -and $_.Publisher -like '*Anthropic*' } | Select-Object -First 1
if (-not $pkg) { Write-Host 'Claude MSIX package not found.'; exit 1 }
Write-Host "Package : $($pkg.PackageFullName)"
Write-Host "Location: $($pkg.InstallLocation)"

$ver = Join-Path $Out $pkg.Version
$src = Join-Path $ver 'src'
if (-not (Test-Path $src)) {
    New-Item -ItemType Directory -Path $ver -Force | Out-Null
    Copy-Item (Join-Path $pkg.InstallLocation 'app\resources\app.asar') (Join-Path $ver 'app.asar')
    Copy-Item (Join-Path $pkg.InstallLocation 'AppxManifest.xml') (Join-Path $ver 'AppxManifest.xml')
    & node (Join-Path $PSScriptRoot 'asar-extract.js') (Join-Path $ver 'app.asar') $src
}
$build = Join-Path $src '.vite\build'
if (-not (Test-Path $build)) { $build = $src }
Write-Host "Extracted: $src"
Write-Host ''

$manifest = Get-Content (Join-Path $ver 'AppxManifest.xml') -Raw
$js = Get-ChildItem $build -Filter '*.js' -Recurse

function Find-Text([string]$pattern, [int]$ctx = 160) {
    foreach ($f in $js) {
        $t = [IO.File]::ReadAllText($f.FullName)
        $m = [regex]::Match($t, $pattern)
        if ($m.Success) {
            $a = [Math]::Max(0, $m.Index - $ctx); $b = [Math]::Min($t.Length, $m.Index + $m.Length + $ctx)
            return [pscustomobject]@{ File = $f.Name; Snippet = $t.Substring($a, $b - $a) }
        }
    }
    return $null
}

$checks = @(
    @{ Name = 'Version-independent alias claude-desktop.exe in AppxManifest'; Ok = ($manifest -match 'Alias="claude-desktop\.exe"'); Critical = $false
       Hint = 'Without it the tool falls back to the exe inside the package folder (still works, Get-ClaudeLauncher).' }
    @{ Name = 'Protocol claude:// registered by the package'; Ok = ($manifest -match 'Protocol Name="claude"'); Critical = $false; Hint = '' }
)
foreach ($c in $checks) {
    $s = if ($c.Ok) { '[OK]  ' } else { '[MISS]' }
    Write-Host "$s $($c.Name)"
    if (-not $c.Ok -and $c.Hint) { Write-Host "       $($c.Hint)" }
}

$markers = [ordered]@{
    'reads --user-data-dir (chosen folder)'           = 'getSwitchValue\("user-data-dir"\)'
    'label stay_chosen_folder (keeps our folder)'     = 'stay_chosen_folder'
    'single-instance lock per userData'               = 'requestSingleInstanceLock'
    'CLAUDE_USER_DATA_DIR env (ignored when signed)'  = 'CLAUDE_USER_DATA_DIR'
    'switches that make the app refuse to start'      = 'remote-debugging-port","remote-debugging-pipe'
    'Google sign-in tied to the instance that began'  = 'does not answer a sign-in this app started'
    'user-data-move logic (moves the default folder)' = '\[user-data-move\]'
    'argv rule for links (no arg after a link)'       = 'no argument may follow a link'
}
Write-Host ''
foreach ($k in $markers.Keys) {
    $hit = Find-Text $markers[$k]
    if ($hit) { Write-Host "[FOUND] $k  ($($hit.File))" -ForegroundColor Green }
    else      { Write-Host "[GONE]  $k" -ForegroundColor Yellow }
}

Write-Host ''
Write-Host 'Switch lists that make the app refuse to start (must NOT include user-data-dir):'
foreach ($f in $js) {
    $t = [IO.File]::ReadAllText($f.FullName)
    foreach ($m in [regex]::Matches($t, '\["remote-debugging-port"[^\]]*\]')) {
        Write-Host "  $($f.Name): $($m.Value)"
        if ($m.Value -match 'user-data-dir') { Write-Host '  >>> user-data-dir IS BLOCKED NOW: the method needs a new approach.' -ForegroundColor Red }
    }
}

Write-Host ''
Write-Host 'Context around --user-data-dir handling:'
$u = Find-Text 'getSwitchValue\("user-data-dir"\)' 400
if ($u) { Write-Host $u.Snippet } else { Write-Host '  (not found - search the extracted code for "user-data-dir" and "setPath(\"userData\"")' }
Write-Host ''
Write-Host "Next: grep -o '.{300}user-data-dir.{300}' in $build"
