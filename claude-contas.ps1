#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Contas - several Claude Desktop accounts side by side on Windows.
    Claude Contas - várias contas do Claude Desktop lado a lado no Windows.

.DESCRIPTION
    Each extra account is a separate data folder opened with --user-data-dir.
    The app is started through the version-independent alias claude-desktop.exe
    that the Claude MSIX package registers, so app updates do not break the
    shortcuts. Run without parameters for the interactive menu.

.EXAMPLE
    claude-contas.ps1                                  # interactive menu
    claude-contas.ps1 -Instalar                        # guided install (asks everything)
    claude-contas.ps1 -Instalar -Sim -Contas "Trabalho,Cliente" -Icones logo -Agendar "12:00" -ComSkill -SemEntrar
                                                       # install without questions (used by PROMPT.md)
    claude-contas.ps1 -Abrir Trabalho                  # open an account (what the shortcuts do)
    claude-contas.ps1 -Entrar Trabalho                 # guided sign-in for an account
    claude-contas.ps1 -Diagnostico                     # health report
    claude-contas.ps1 -Testar                          # live self-test with a throwaway folder
    claude-contas.ps1 -Reparar                         # rebuild shortcuts and icons
    claude-contas.ps1 -Atualizar                       # update this tool from GitHub
    claude-contas.ps1 -Agendar "12:00,18:30"           # automatic maintenance at logon + these times
    claude-contas.ps1 -Desagendar                      # remove the scheduled task
    claude-contas.ps1 -Renomear Work -Para Trabalho    # rename an account (sign-in is kept)
    claude-contas.ps1 -Idioma en                       # force English (or pt); also CLAUDE_CONTAS_IDIOMA
    claude-contas.ps1 -Manutencao                      # what the scheduled task runs
#>
[CmdletBinding()]
param(
    [string]$Abrir,
    [string]$Entrar,
    [string]$Adicionar,
    [string]$Remover,
    [string]$Renomear,
    [string]$Para,
    [string]$Pasta,
    [switch]$Diagnostico,
    [switch]$Testar,
    [switch]$Reparar,
    [switch]$Atualizar,
    [switch]$Instalar,
    [switch]$Manutencao,
    [string]$Agendar,
    [switch]$Desagendar,
    [string]$Contas,
    [ValidateSet('', 'logo', 'numerado')][string]$Icones = '',
    [string]$NomePrincipal,
    [switch]$ComSkill,
    [switch]$SemSkill,
    [switch]$SemAgendador,
    [switch]$SemEntrar,
    [switch]$Sim,
    [switch]$Silencioso,
    [ValidateSet('', 'pt', 'en')][string]$Idioma = '',
    [switch]$Versao
)

$ErrorActionPreference = 'Stop'
$ToolVersion = '2.2.2'
$REPO     = 'VinguardCP/claude-desktop-multi-account-windows'
$REPO_RAW = "https://raw.githubusercontent.com/$REPO/main"

$Base        = Join-Path $env:LOCALAPPDATA 'ClaudeContas'
$ScriptPath  = Join-Path $Base 'claude-contas.ps1'
$ConfigFile  = Join-Path $Base 'contas.json'
$LogFile     = Join-Path $Base 'claude-contas.log'
$IconDir     = Join-Path $Base 'icones'
$PerfisDir   = Join-Path $env:USERPROFILE 'ClaudeContas'
$AliasPath   = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\claude-desktop.exe'
$TaskName    = 'Claude Contas - Manutencao'
$SkillDir    = Join-Path $env:USERPROFILE '.claude\skills\claude-contas'
$MaxNumero   = 9
# Account colors by number. 1 = main account (Claude orange).
$CorNumero   = @{ 1 = '#D97757'; 2 = '#2F6FED'; 3 = '#1E9E5A'; 4 = '#8E44CF'; 5 = '#C0392B'
                  6 = '#0E8C8C'; 7 = '#B7950B'; 8 = '#5D6D7E'; 9 = '#D63384' }
$NoQuestions = [bool]($Sim -or $Silencioso)

# ---------------------------------------------------------------- text / log
# Language: -Idioma, then CLAUDE_CONTAS_IDIOMA, then the Windows language.
$lang = if ($Idioma) { $Idioma } elseif ($env:CLAUDE_CONTAS_IDIOMA) { $env:CLAUDE_CONTAS_IDIOMA } else { '' }
$UsePT = if ($lang) { $lang -like 'pt*' } else { ((Get-UICulture).Name -like 'pt*') -or ((Get-Culture).Name -like 'pt*') }
function T([string]$textPt, [string]$textEn) { if ($UsePT) { $textPt } else { $textEn } }

function Write-Log([string]$msg) {
    try {
        if (-not (Test-Path $Base)) { New-Item -ItemType Directory -Path $Base -Force | Out-Null }
        $line = '{0} [v{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $ToolVersion, $msg
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
        if ((Get-Item $LogFile).Length -gt 1MB) {
            $keep = Get-Content $LogFile -Tail 2000
            Set-Content -Path $LogFile -Value $keep -Encoding UTF8
        }
    } catch { }
}

function Say([string]$msg, [string]$color = 'Gray') { if (-not $Silencioso) { Write-Host $msg -ForegroundColor $color } }
function Ok([string]$msg)   { Say ('  [OK]   ' + $msg) 'Green' }
function Warn([string]$msg) { Say ('  [!]    ' + $msg) 'Yellow' }
function Bad([string]$msg)  { Say ('  [ERRO] ' + $msg) 'Red' }

# Question with a default. Without a console (-Sim/-Silencioso) the default wins.
function Ask([string]$question, [string]$default = '') {
    if ($NoQuestions) { return $default }
    $suffix = if ($default) { " [$default]" } else { '' }
    $a = Read-Host ($question + $suffix)
    if ([string]::IsNullOrWhiteSpace($a)) { return $default }
    return $a.Trim()
}
function AskYes([string]$question, [bool]$default = $true) {
    $d = if ($default) { T 'S' 'Y' } else { 'N' }
    $a = Ask ($question + (T ' (S/N)' ' (Y/N)')) $d
    return ($a -match '^[sSyY]')
}

function Show-Popup([string]$msg, [string]$title = 'Claude Contas', [string]$kind = 'Information') {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [void][System.Windows.Forms.MessageBox]::Show($msg, $title, 'OK', $kind)
    } catch { Write-Host $msg }
}

# Small tray balloon, used by the scheduled maintenance (no window, no focus steal).
function Show-Balloon([string]$msg, [string]$kind = 'Info') {
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $n = New-Object System.Windows.Forms.NotifyIcon
        $ico = Join-Path $IconDir 'menu.ico'
        $n.Icon = if (Test-Path $ico) { New-Object System.Drawing.Icon $ico } else { [System.Drawing.SystemIcons]::Information }
        $n.BalloonTipTitle = 'Claude Contas'
        $n.BalloonTipText = $msg
        $n.BalloonTipIcon = $kind
        $n.Visible = $true
        $n.ShowBalloonTip(8000)
        Start-Sleep -Seconds 9
        $n.Dispose()
    } catch { Write-Log "balao falhou: $($_.Exception.Message)" }
}

# ---------------------------------------------------------------- config
function Get-Config {
    $cfg = [pscustomobject]@{
        principal = [pscustomobject]@{ nome = 'Principal'; numero = 1; cor = $CorNumero[1] }
        contas = @(); estiloIcone = 'logo'; autoAtualizar = $true; ultimaChecagem = ''
        agendador = [pscustomobject]@{ ativo = $false; horarios = @() }
        ultimaVersaoClaude = ''; ultimoTeste = ''
    }
    if (Test-Path $ConfigFile) {
        try {
            $raw = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($raw.principal)                  { $cfg.principal = $raw.principal }
            if ($raw.contas)                     { $cfg.contas = @($raw.contas) }
            if ($raw.estiloIcone)                { $cfg.estiloIcone = [string]$raw.estiloIcone }
            if ($null -ne $raw.autoAtualizar)    { $cfg.autoAtualizar = [bool]$raw.autoAtualizar }
            if ($raw.ultimaChecagem)             { $cfg.ultimaChecagem = [string]$raw.ultimaChecagem }
            if ($raw.agendador)                  { $cfg.agendador = $raw.agendador }
            if ($raw.ultimaVersaoClaude)         { $cfg.ultimaVersaoClaude = [string]$raw.ultimaVersaoClaude }
            if ($raw.ultimoTeste)                { $cfg.ultimoTeste = [string]$raw.ultimoTeste }
        } catch { Write-Log "config ilegivel: $($_.Exception.Message)" }
    }
    # v2.0.0 configs: give every account a number (2..9) and the matching color.
    $used = @(1)
    foreach ($c in $cfg.contas) {
        if (-not ($c.PSObject.Properties.Name -contains 'numero') -or -not $c.numero) {
            $n = 2; while ($used -contains $n -and $n -lt $MaxNumero) { $n++ }
            $c | Add-Member -NotePropertyName numero -NotePropertyValue $n -Force
            $c | Add-Member -NotePropertyName cor -NotePropertyValue $CorNumero[$n] -Force
        }
        $used += [int]$c.numero
    }
    return $cfg
}

function Save-Config($cfg) {
    if (-not (Test-Path $Base)) { New-Item -ItemType Directory -Path $Base -Force | Out-Null }
    $cfg | ConvertTo-Json -Depth 6 | Set-Content -Path $ConfigFile -Encoding UTF8
}

function Find-Conta($cfg, [string]$nome) {
    $cfg.contas | Where-Object { $_.nome -eq $nome } | Select-Object -First 1
}

function Test-IsPrincipal($cfg, [string]$nome) {
    return ($nome -eq $cfg.principal.nome -or $nome -eq 'Principal' -or $nome -eq 'Main')
}

function Get-NextNumero($cfg) {
    $used = @(1) + @($cfg.contas | ForEach-Object { [int]$_.numero })
    for ($n = 2; $n -le $MaxNumero; $n++) { if ($used -notcontains $n) { return $n } }
    return (($cfg.contas.Count) % ($MaxNumero - 1)) + 2
}

function Get-Slug([string]$nome) {
    $n = $nome.Normalize([Text.NormalizationForm]::FormD)
    $n = -join ($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    $n = ($n -replace '[^A-Za-z0-9]+', '-').Trim('-')
    if (-not $n) { $n = 'conta' }
    return $n
}

# ---------------------------------------------------------------- Claude install
function Get-ClaudePackage {
    $p = Get-AppxPackage -Name 'Claude' -ErrorAction SilentlyContinue |
         Where-Object { $_.Publisher -like '*Anthropic*' } | Select-Object -First 1
    if (-not $p) {
        $p = Get-AppxPackage -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -like '*Claude*' -and $_.Publisher -like '*Anthropic*' } |
             Select-Object -First 1
    }
    return $p
}

# How to start Claude Desktop. Order: alias (survives updates) -> exe inside the
# current package version -> legacy (non-MSIX) install.
function Get-ClaudeLauncher {
    if (Test-Path $AliasPath) { return [pscustomobject]@{ Path = $AliasPath; Kind = 'alias' } }
    $pkg = Get-ClaudePackage
    if ($pkg) {
        foreach ($rel in 'app\claude.exe', 'app\Claude.exe') {
            $exe = Join-Path $pkg.InstallLocation $rel
            if (Test-Path $exe) { return [pscustomobject]@{ Path = $exe; Kind = 'package' } }
        }
    }
    $legacy = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
    if (Test-Path $legacy) { return [pscustomobject]@{ Path = $legacy; Kind = 'legacy' } }
    return $null
}

function Get-ClaudeVersion {
    $p = Get-ClaudePackage
    if ($p) { return [string]$p.Version }
    $legacy = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'AnthropicClaude') -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
              Sort-Object Name -Descending | Select-Object -First 1
    if ($legacy) { return $legacy.Name -replace '^app-', '' }
    return ''
}

# Claude Desktop processes only (the Claude Code CLI is also claude.exe).
function Get-DesktopProcesses {
    Get-CimInstance Win32_Process -Filter "Name='claude.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExecutablePath -and (
                $_.ExecutablePath -like '*\WindowsApps\Claude_*' -or
                $_.ExecutablePath -like '*\WindowsApps\claude-desktop.exe' -or
                $_.ExecutablePath -like '*\AnthropicClaude\*')
        }
}

function Get-MainProcesses { Get-DesktopProcesses | Where-Object { $_.CommandLine -notmatch '--type=' } }

function Test-SameFolder([string]$cmd, [string]$folder) {
    if (-not $cmd) { return $false }
    $f = [regex]::Escape($folder.TrimEnd('\'))
    return $cmd -match ('--user-data-dir="?' + $f + '\\?("|\s|$)')
}

function Get-InstanceOf([string]$folder) {
    Get-MainProcesses | Where-Object { Test-SameFolder $_.CommandLine $folder }
}

function Get-DefaultInstance {
    Get-MainProcesses | Where-Object { $_.CommandLine -notmatch '--user-data-dir' }
}

function Start-ClaudeWith([string]$folder, [string]$url, [string[]]$extra = @()) {
    $l = Get-ClaudeLauncher
    if (-not $l) { throw (T 'O Claude Desktop não está instalado.' 'Claude Desktop is not installed.') }
    $argList = @()
    if ($folder) { $argList += ('--user-data-dir="{0}"' -f $folder) }
    $argList += $extra
    if ($url)    { $argList += '--'; $argList += ('"{0}"' -f $url) }
    # Claude writes Node/Chromium warnings to the console it inherits. Send them to
    # files so they do not flood the menu window. Old files are removed when free.
    $outDir = Join-Path $Base 'saida'
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Get-ChildItem $outDir -Filter '*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddMinutes(-10) } |
        ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    $tag = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + (Get-Random -Maximum 99999)
    $redir = @{ RedirectStandardOutput = (Join-Path $outDir "$tag-out.log"); RedirectStandardError = (Join-Path $outDir "$tag-err.log") }
    if ($argList.Count -gt 0) { Start-Process -FilePath $l.Path -ArgumentList $argList @redir }
    else                      { Start-Process -FilePath $l.Path @redir }
    Write-Log ("start kind={0} folder={1} url={2}" -f $l.Kind, $folder, [bool]$url)
}

function Stop-Tree([int]$procId) {
    try { & taskkill.exe /PID $procId /T /F 2>$null | Out-Null } catch { }
}

# ---------------------------------------------------------------- logs of a profile
function Get-ProfileLog([string]$folder) {
    foreach ($c in 'logs\main.log', 'Logs\main.log') {
        $p = Join-Path $folder $c
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-ProfileState([string]$folder) {
    $st = [pscustomobject]@{ Exists = (Test-Path $folder); LastStart = $null; Chosen = $null
                             LoggedIn = $null; AccountId = $null; LastSeen = $null
                             CookieAtStart = $null; SignedInAtExit = $null }
    $log = Get-ProfileLog $folder
    if (-not $log) { return $st }
    $st.LastSeen = (Get-Item $log).LastWriteTime
    $lines = @(Get-Content $log -Tail 4000 -ErrorAction SilentlyContinue)
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        $ln = $lines[$i]
        if ($null -eq $st.LoggedIn) {
            if ($ln -match 'account active and logged in') { $st.LoggedIn = $true }
            elseif ($ln -match 'User is logged out|User logged out') { $st.LoggedIn = $false }
        }
        if (-not $st.AccountId -and $ln -match 'accountId[=:] ?''?([0-9a-f-]{36})') { $st.AccountId = $Matches[1] }
        if ($null -eq $st.Chosen -and $ln -match '\[user-data-move\] (\w+)') { $st.Chosen = $Matches[1] }
        if (-not $st.LastStart -and $ln -match '^(\S+ \S+) \[info\] Starting app') { $st.LastStart = $Matches[1] }
        if ($null -eq $st.CookieAtStart -and $ln -match 'sign_in_cookie_present: (true|false)') { $st.CookieAtStart = ($Matches[1] -eq 'true') }
        if ($null -eq $st.SignedInAtExit -and $ln -match 'signed_in_at_last_exit: (true|false)') { $st.SignedInAtExit = ($Matches[1] -eq 'true') }
        if ($st.LastStart -and $null -ne $st.LoggedIn -and $st.AccountId -and $st.Chosen) { break }
    }
    return $st
}

function Get-DefaultAccountId {
    $log = Join-Path $env:LOCALAPPDATA 'Claude\logs\main.log'
    if (-not (Test-Path $log)) { return $null }
    $hit = Get-Content $log -Tail 4000 -ErrorAction SilentlyContinue |
           Select-String 'accountId[=:] ?''?([0-9a-f-]{36})' | Select-Object -Last 1
    if ($hit) { return $hit.Matches[0].Groups[1].Value }
    return $null
}

# ---------------------------------------------------------------- icons
# Two styles:
#   logo     - the installed Claude logo with a colored badge and the account initial
#              (built locally from the app's own asset; never redistributed).
#   numerado - the project's own numbered icons (icons/conta-N.ico in the repo).
function Get-BaseIconPng {
    $cached = Join-Path $IconDir 'claude-base.png'
    if (Test-Path $cached) { return $cached }
    $pkg = Get-ClaudePackage
    if ($pkg) {
        foreach ($n in 'Square44x44Logo.targetsize-256_altform-unplated.png',
                       'Square44x44Logo.targetsize-256.png', 'Square150x150Logo.scale-200.png') {
            $src = Join-Path $pkg.InstallLocation "assets\$n"
            if (Test-Path $src) {
                New-Item -ItemType Directory -Path $IconDir -Force | Out-Null
                Copy-Item $src $cached -Force
                return $cached
            }
        }
    }
    return $null
}

function Write-Ico([string]$path, $pngs) {
    $fs = [System.IO.File]::Create($path)
    $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$pngs.Count)
    $offset = 6 + 16 * $pngs.Count
    foreach ($p in $pngs) {
        $s = $p[0]; $data = $p[1]; $b = if ($s -ge 256) { 0 } else { $s }
        $bw.Write([byte]$b); $bw.Write([byte]$b)
        $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([UInt16]1); $bw.Write([UInt16]32)
        $bw.Write([UInt32]$data.Length); $bw.Write([UInt32]$offset)
        $offset += $data.Length
    }
    foreach ($p in $pngs) { $bw.Write([byte[]]$p[1]) }
    $bw.Close(); $fs.Close()
}

function New-BadgeIcon([string]$file, [string]$cor, [string]$letter) {
    Add-Type -AssemblyName System.Drawing
    New-Item -ItemType Directory -Path $IconDir -Force | Out-Null
    $ico = Join-Path $IconDir ($file + '.ico')
    $basePng = Get-BaseIconPng
    $color = [System.Drawing.ColorTranslator]::FromHtml($cor)
    $pngs = @()
    foreach ($size in 256, 48, 32, 16) {
        $bmp = New-Object System.Drawing.Bitmap $size, $size
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAliasGridFit'
        if ($basePng) {
            $img = [System.Drawing.Image]::FromFile($basePng)
            $g.DrawImage($img, 0, 0, $size, $size); $img.Dispose()
            $d = [int]($size * 0.56); $x = $size - $d; $y = $size - $d
        } else { $d = $size; $x = 0; $y = 0 }
        $brush = New-Object System.Drawing.SolidBrush $color
        $g.FillEllipse($brush, $x, $y, $d - 1, $d - 1)
        if ($basePng -and $size -ge 32) {
            $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([Math]::Max(1, $size / 40))
            $g.DrawEllipse($pen, $x, $y, $d - 1, $d - 1); $pen.Dispose()
        }
        $font = New-Object System.Drawing.Font 'Segoe UI', ([float]($d * 0.52)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $fmt = New-Object System.Drawing.StringFormat
        $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
        $rect = New-Object System.Drawing.RectangleF $x, ($y + $d * 0.03), $d, $d
        $g.DrawString($letter, $font, [System.Drawing.Brushes]::White, $rect, $fmt)
        $g.Dispose()
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
        $pngs += , @($size, $ms.ToArray())
    }
    Write-Ico $ico $pngs
    return $ico
}

# Numbered icon from the repo: local clone first, then GitHub, then a badge fallback.
function Get-NumberedIcon([int]$numero) {
    New-Item -ItemType Directory -Path $IconDir -Force | Out-Null
    $dest = Join-Path $IconDir "numerado-$numero.ico"
    $name = "conta-$numero.ico"
    $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot "icons\$name" } else { $null }
    if ($local -and (Test-Path $local)) { Copy-Item $local $dest -Force; return $dest }
    if (Test-Path $dest) { return $dest }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri "$REPO_RAW/icons/$name" -OutFile $dest -TimeoutSec 20
        return $dest
    } catch {
        Write-Log "icone numerado $numero indisponivel: $($_.Exception.Message)"
        return (New-BadgeIcon "numerado-$numero" $CorNumero[$numero] ([string]$numero))
    }
}

function Get-AccountIcon($cfg, [string]$nome, [int]$numero, [string]$cor) {
    if ($cfg.estiloIcone -eq 'numerado') { return (Get-NumberedIcon $numero) }
    return (New-BadgeIcon ('conta-' + (Get-Slug $nome)) $cor $nome.Trim().Substring(0, 1).ToUpper())
}

# ---------------------------------------------------------------- shortcuts
# Desktop / Start menu folders. Windows can return an empty path (redirected or
# broken profile folders); fall back to the standard locations then.
function Get-SpecialFolder([string]$which) {
    $p = [Environment]::GetFolderPath($which)
    if ($p) { return $p }
    switch ($which) {
        'Desktop'  { foreach ($c in @((Join-Path $env:USERPROFILE 'OneDrive\Desktop'), (Join-Path $env:USERPROFILE 'Desktop'))) { if (Test-Path $c) { return $c } }; return (Join-Path $env:USERPROFILE 'Desktop') }
        'Programs' { return (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs') }
    }
    return $env:USERPROFILE
}

function Get-ShortcutPaths([string]$nome) {
    $file = "Claude - $nome.lnk"
    $desktop = (Get-SpecialFolder 'Desktop')
    $start   = Join-Path ((Get-SpecialFolder 'Programs')) 'Claude Contas'
    return @((Join-Path $desktop $file), (Join-Path $start $file))
}

function New-Shortcut([string]$lnk, [string]$scriptArgs, [string]$icon, [string]$desc, [switch]$Visible) {
    New-Item -ItemType Directory -Path (Split-Path $lnk) -Force | Out-Null
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnk)
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $scriptArgs"
    $conhost = Join-Path $env:SystemRoot 'System32\conhost.exe'
    if (-not $Visible -and [Environment]::OSVersion.Version.Build -ge 17763 -and (Test-Path $conhost)) {
        $sc.TargetPath = $conhost
        $sc.Arguments  = "--headless `"$ps`" $psArgs"
    } else {
        $sc.TargetPath = $ps
        $sc.Arguments  = $(if ($Visible) { $psArgs } else { "-WindowStyle Hidden $psArgs" })
        if (-not $Visible) { $sc.WindowStyle = 7 }
    }
    $sc.WorkingDirectory = $Base
    if ($icon -and (Test-Path $icon)) { $sc.IconLocation = "$icon,0" }
    $sc.Description = $desc
    $sc.Save()
}

function Set-AccountShortcuts($cfg, $conta) {
    $ico = Get-AccountIcon $cfg $conta.nome ([int]$conta.numero) $conta.cor
    foreach ($lnk in Get-ShortcutPaths $conta.nome) {
        New-Shortcut $lnk ("-Abrir `"{0}`"" -f $conta.nome) $ico (T "Abre o Claude na conta $($conta.nome)" "Opens Claude with the $($conta.nome) account")
    }
}

function Set-PrincipalShortcuts($cfg) {
    $p = $cfg.principal
    # On the orange Claude logo an orange badge would disappear: use graphite there.
    $ico = Get-AccountIcon $cfg $p.nome 1 $(if ($cfg.estiloIcone -eq 'logo') { '#262624' } else { $p.cor })
    foreach ($lnk in Get-ShortcutPaths $p.nome) {
        New-Shortcut $lnk ("-Abrir `"{0}`"" -f $p.nome) $ico (T 'Abre o Claude na conta principal' 'Opens Claude with the main account')
    }
}

function Set-MenuShortcut {
    $lnk = Join-Path (Join-Path ((Get-SpecialFolder 'Programs')) 'Claude Contas') 'Claude Contas (menu).lnk'
    $ico = New-BadgeIcon 'menu' '#555555' '+'
    New-Shortcut $lnk '' $ico (T 'Gerenciar contas do Claude' 'Manage Claude accounts') -Visible
}

function Remove-AccountShortcuts([string]$nome) {
    foreach ($lnk in Get-ShortcutPaths $nome) { Remove-Item $lnk -Force -ErrorAction SilentlyContinue }
    Remove-Item (Join-Path $IconDir ('conta-' + (Get-Slug $nome) + '.ico')) -Force -ErrorAction SilentlyContinue
}

# Shortcuts made with version 1 (.bat with a fixed version path).
function Get-LegacyShortcuts {
    $found = @()
    $ws = New-Object -ComObject WScript.Shell
    foreach ($dir in @((Get-SpecialFolder 'Desktop'), (Get-SpecialFolder 'Programs'))) {
        Get-ChildItem $dir -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $t = $ws.CreateShortcut($_.FullName).TargetPath
                if ($t -like '*.bat' -and (Test-Path $t) -and ((Get-Content $t -Raw) -match 'user-data-dir')) { $found += $_.FullName }
                elseif ($t -like '*\WindowsApps\Claude_*\claude.exe') { $found += $_.FullName }
                # v1 shortcut whose .bat was deleted or moved: a dead "Claude ..." icon.
                elseif ($t -like '*.bat' -and -not (Test-Path $t) -and $_.Name -like 'Claude*') { $found += $_.FullName }
            } catch { }
        }
    }
    # v1 .bat saved straight on the Desktop (its version path dies with every Claude update).
    Get-ChildItem (Get-SpecialFolder 'Desktop') -Filter '*.bat' -ErrorAction SilentlyContinue | ForEach-Object {
        try { if ((Get-Content $_.FullName -Raw) -match 'user-data-dir' -and (Get-Content $_.FullName -Raw) -match 'claude\.exe') { $found += $_.FullName } } catch { }
    }
    return $found
}

# ---------------------------------------------------------------- self-update
function Get-RemoteScript {
    $tmp = Join-Path $env:TEMP ('claude-contas-' + [guid]::NewGuid().ToString('N') + '.ps1')
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -UseBasicParsing -Uri "$REPO_RAW/claude-contas.ps1" -OutFile $tmp -TimeoutSec 20
    $text = Get-Content $tmp -Raw -Encoding UTF8
    if ($text -notmatch "\`$ToolVersion\s*=\s*'([0-9.]+)'") { Remove-Item $tmp -Force; throw 'versao nao encontrada no arquivo remoto' }
    $remoteVer = $Matches[1]
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) { Remove-Item $tmp -Force; throw "arquivo remoto com erro de sintaxe: $($errs[0].Message)" }
    return [pscustomobject]@{ Path = $tmp; Version = $remoteVer }
}

# Returns the new version when it updated, $null otherwise.
function Update-Tool([switch]$Quiet) {
    try {
        $r = Get-RemoteScript
        if ([version]$r.Version -gt [version]$ToolVersion) {
            Copy-Item $r.Path $ScriptPath -Force
            Remove-Item $r.Path -Force
            Write-Log "atualizado de $ToolVersion para $($r.Version)"
            if (-not $Quiet) { Ok (T "Ferramenta atualizada: $ToolVersion -> $($r.Version)" "Tool updated: $ToolVersion -> $($r.Version)") }
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -Reparar -Silencioso | Out-Null
            if (Test-Path (Join-Path $SkillDir 'SKILL.md')) { [void](Install-Skill -Quiet) }
            return $r.Version
        }
        Remove-Item $r.Path -Force
        if (-not $Quiet) { Ok (T "Você já tem a versão mais nova ($ToolVersion)." "You already have the latest version ($ToolVersion).") }
    } catch {
        Write-Log "falha ao atualizar: $($_.Exception.Message)"
        if (-not $Quiet) { Warn (T "Não consegui checar atualização: $($_.Exception.Message)" "Could not check for updates: $($_.Exception.Message)") }
    }
    return $null
}

function Invoke-DailyUpdateCheck {
    $cfg = Get-Config
    if (-not $cfg.autoAtualizar) { return }
    $last = [datetime]::MinValue
    [void][datetime]::TryParse($cfg.ultimaChecagem, [ref]$last)
    if (((Get-Date) - $last).TotalHours -lt 24) { return }
    $cfg.ultimaChecagem = (Get-Date).ToString('s'); Save-Config $cfg
    [void](Update-Tool -Quiet)
}

# ---------------------------------------------------------------- Claude Code skill
function Test-ClaudeCode {
    return ((Test-Path (Join-Path $env:USERPROFILE '.claude')) -or [bool](Get-Command claude -ErrorAction SilentlyContinue))
}

function Install-Skill([switch]$Quiet) {
    try {
        New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null
        $dest = Join-Path $SkillDir 'SKILL.md'
        $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'claude-code-skill\claude-contas\SKILL.md' } else { $null }
        if ($local -and (Test-Path $local)) { Copy-Item $local $dest -Force }
        else {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -UseBasicParsing -Uri "$REPO_RAW/claude-code-skill/claude-contas/SKILL.md" -OutFile $dest -TimeoutSec 20
        }
        if (-not $Quiet) { Ok (T "Skill /claude-contas instalada no Claude Code ($dest)" "Skill /claude-contas installed for Claude Code ($dest)") }
        Write-Log 'skill instalada'
        return $true
    } catch {
        Warn ((T 'Não consegui instalar a skill: ' 'Could not install the skill: ') + $_.Exception.Message)
        return $false
    }
}

# ---------------------------------------------------------------- scheduled maintenance
function Get-ValidTimes([string]$text) {
    $out = @()
    foreach ($p in ($text -split '[,; ]+')) {
        if (-not $p) { continue }
        if ($p -match '^(\d{1,2})(?:[:hH](\d{2})?)?$') {
            $h = [int]$Matches[1]; $m = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
            if ($h -le 23 -and $m -le 59) { $out += ('{0:00}:{1:00}' -f $h, $m); continue }
        }
        Warn ((T 'Horário ignorado (use HH:MM): ' 'Time ignored (use HH:MM): ') + $p)
    }
    return @($out | Select-Object -Unique)
}

function Register-Agendador([string[]]$horarios) {
    $ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $conhost = Join-Path $env:SystemRoot 'System32\conhost.exe'
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Manutencao -Silencioso"
    if ([Environment]::OSVersion.Version.Build -ge 17763 -and (Test-Path $conhost)) {
        $action = New-ScheduledTaskAction -Execute $conhost -Argument "--headless `"$ps`" $psArgs" -WorkingDirectory $Base
    } else {
        $action = New-ScheduledTaskAction -Execute $ps -Argument "-WindowStyle Hidden $psArgs" -WorkingDirectory $Base
    }
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $triggers = @()
    $logon = New-ScheduledTaskTrigger -AtLogOn -User $user
    $logon.Delay = 'PT2M'
    $triggers += $logon
    foreach ($h in $horarios) { $triggers += New-ScheduledTaskTrigger -Daily -At $h }
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $desc = T 'Mantém o Claude Contas atualizado e confere se as contas extras continuam abrindo depois de cada atualização do Claude.' 'Keeps Claude Contas up to date and checks that the extra accounts still open after each Claude update.'
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description $desc -Force | Out-Null
    $cfg = Get-Config
    $cfg.agendador = [pscustomobject]@{ ativo = $true; horarios = @($horarios) }
    Save-Config $cfg
    Write-Log ("agendador: ao entrar no Windows + {0}" -f ($horarios -join ', '))
    $when = if ($horarios.Count) { (T 'ao ligar o computador e às ' 'at sign-in and at ') + ($horarios -join ', ') } else { T 'ao ligar o computador' 'at sign-in' }
    Ok ((T 'Atualização automática agendada: ' 'Automatic update scheduled: ') + $when)
}

function Unregister-Agendador {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    $cfg = Get-Config
    $cfg.agendador = [pscustomobject]@{ ativo = $false; horarios = @() }
    Save-Config $cfg
    Write-Log 'agendador removido'
    Ok (T 'Atualização automática agendada desligada.' 'Scheduled automatic update turned off.')
}

function Get-AgendadorInfo {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $t) { return $null }
    $i = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    $times = @($t.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskDailyTrigger' } |
               ForEach-Object { ([datetime]$_.StartBoundary).ToString('HH:mm') })
    return [pscustomobject]@{ Horarios = $times; Ultima = $i.LastRunTime; Proxima = $i.NextRunTime; Resultado = $i.LastTaskResult }
}

# What the scheduled task runs: quiet, no windows, balloon only when it matters.
function Invoke-Manutencao {
    Write-Log 'manutencao: inicio'
    $cfg = Get-Config
    $updated = $null
    if ($cfg.autoAtualizar) {
        $updated = Update-Tool -Quiet
        $cfg = Get-Config
        $cfg.ultimaChecagem = (Get-Date).ToString('s'); Save-Config $cfg
    }
    if ($updated) {
        # Let the new version do the rest of the maintenance.
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -Manutencao -Silencioso
        Show-Balloon ((T 'Ferramenta atualizada para a versão ' 'Tool updated to version ') + $updated)
        return
    }
    # Shortcuts deleted by hand or by a cleanup tool come back.
    $missing = @($cfg.contas | Where-Object { @(Get-ShortcutPaths $_.nome | Where-Object { -not (Test-Path $_) }).Count -gt 0 })
    if ($missing.Count -gt 0 -or -not (Test-Path (Get-ShortcutPaths $cfg.principal.nome)[0])) { Invoke-Reparar }

    $ver = Get-ClaudeVersion
    if (-not (Get-ClaudeLauncher)) {
        Write-Log 'manutencao: Claude Desktop nao encontrado'
        Show-Balloon (T 'O Claude Desktop não foi encontrado. Reinstale em claude.com/download.' 'Claude Desktop was not found. Reinstall it from claude.com/download.') 'Warning'
        return
    }
    # New Claude version since the last good test: test it now.
    if ($ver -and $ver -ne $cfg.ultimaVersaoClaude) {
        $ok = Invoke-Testar
        $cfg = Get-Config
        $cfg.ultimoTeste = ('{0} {1} {2}' -f (Get-Date).ToString('s'), $ver, $(if ($ok) { 'ok' } else { 'falhou' }))
        if ($ok) { $cfg.ultimaVersaoClaude = $ver }
        Save-Config $cfg
        if (-not $ok) {
            Show-Balloon ((T "O Claude atualizou ($ver) e as contas extras pararam de abrir. Abra o Claude Code e rode /claude-contas." "Claude updated ($ver) and the extra accounts stopped opening. Open Claude Code and run /claude-contas.")) 'Warning'
        }
    }
    Write-Log "manutencao: fim (Claude $ver)"
}

# ---------------------------------------------------------------- commands
function Invoke-Abrir([string]$nome) {
    $cfg = Get-Config
    if (-not (Get-ClaudeLauncher)) {
        Show-Popup (T 'Não encontrei o Claude Desktop. Instale em claude.com/download e tente de novo.' 'Claude Desktop was not found. Install it from claude.com/download and try again.') 'Claude Contas' 'Error'
        return
    }
    if (Test-IsPrincipal $cfg $nome) {
        Start-ClaudeWith $null $null
        Write-Log "abrir principal"
        Invoke-DailyUpdateCheck
        return
    }
    $conta = Find-Conta $cfg $nome
    if (-not $conta) {
        Show-Popup (T "A conta '$nome' não está cadastrada. Abra 'Claude Contas (menu)' no menu Iniciar." "Account '$nome' is not set up. Open 'Claude Contas (menu)' from the Start menu.") 'Claude Contas' 'Warning'
        return
    }
    $already = @(Get-InstanceOf $conta.pasta).Count -gt 0
    $t0 = Get-Date
    Start-ClaudeWith $conta.pasta $null
    if ($already) { Write-Log "abrir '$nome': ja aberta, janela trazida para frente"; Invoke-DailyUpdateCheck; return }

    $ok = $false
    for ($i = 0; $i -lt 40 -and -not $ok; $i++) {
        Start-Sleep -Milliseconds 500
        $log = Get-ProfileLog $conta.pasta
        if ($log -and (Get-Item $log).LastWriteTime -ge $t0.AddSeconds(-2)) {
            $hit = Get-Content $log -Tail 300 | Select-String '\[user-data-move\] (\w+)' | Select-Object -Last 1
            if ($hit) { $ok = $true; Write-Log "abrir '$nome': ok ($($hit.Matches[0].Groups[1].Value))" }
        }
    }
    if (-not $ok -and @(Get-InstanceOf $conta.pasta).Count -gt 0) { $ok = $true; Write-Log "abrir '$nome': processo ativo, sem confirmacao no log" }
    if (-not $ok) {
        Write-Log "abrir '$nome': FALHOU"
        Show-Popup (T "A conta '$nome' não abriu.`n`nAbra 'Claude Contas (menu)' no menu Iniciar e escolha 'Testar' ou 'Atualizar'. Se continuar, rode a skill /claude-contas no Claude Code." "The '$nome' account did not open.`n`nOpen 'Claude Contas (menu)' from the Start menu and choose 'Test' or 'Update'. If it keeps failing, run the /claude-contas skill in Claude Code.") 'Claude Contas' 'Warning'
    }
    Invoke-DailyUpdateCheck
}

function Invoke-Entrar([string]$nome) {
    $cfg = Get-Config
    if (Test-IsPrincipal $cfg $nome) {
        Say (T 'A conta principal entra pelo próprio Claude normal, sem assistente.' 'The main account signs in through the regular Claude, no helper needed.') 'Yellow'
        return
    }
    $conta = Find-Conta $cfg $nome
    if (-not $conta) { Bad (T "Conta '$nome' não cadastrada." "Account '$nome' is not set up."); return }

    Say ''
    Say (T "== Entrar na conta '$nome' ==" "== Sign in to '$nome' ==") 'Cyan'
    Say (T @"
Por que este assistente existe: no login pelo Google ou pelo link do e-mail, o
navegador devolve o acesso ao app por um link claude://. O Windows sempre entrega
esse link ao Claude principal, e aí o login cai na conta errada ou é descartado.
Este assistente fecha o Claude principal enquanto você entra, pega o link e
entrega à janela da conta '$nome'.
"@ @"
Why this helper exists: with Google or email-link sign-in, the browser hands the
session back to the app through a claude:// link. Windows always delivers that
link to the main Claude, so the sign-in lands in the wrong account or is dropped.
This helper closes the main Claude while you sign in, catches the link and hands
it to the '$nome' window.
"@)
    Say ''
    $running = @(Get-MainProcesses)
    $hadDefault = @(Get-DefaultInstance).Count -gt 0
    if ($running.Count -gt 0) {
        if (-not (AskYes (T 'Vou fechar todas as janelas do Claude agora. Continuar?' 'All Claude windows will be closed now. Continue?'))) { return }
        foreach ($p in $running) { Stop-Tree $p.ProcessId }
        Start-Sleep -Seconds 3
    }
    Start-ClaudeWith $conta.pasta $null
    Start-Sleep -Seconds 3
    Write-Host ''
    Write-Host (T "Pronto. Na janela do Claude que abriu, entre com a conta '$nome' (Google, e-mail ou SSO)." "Done. In the Claude window that opened, sign in with the '$nome' account (Google, email or SSO).") -ForegroundColor Green
    Write-Host (T 'Se o navegador perguntar se pode abrir o Claude, clique em Abrir. Aguardando (até 15 min, Ctrl+C cancela)...' 'If the browser asks to open Claude, click Open. Waiting (up to 15 min, Ctrl+C cancels)...')
    Write-Log "entrar '$nome': aguardando login"

    $seen = @{}
    Get-Process -Name claude -ErrorAction SilentlyContinue | ForEach-Object { $seen[$_.Id] = $true }
    $deadline = (Get-Date).AddMinutes(15)
    $forwarded = 0
    $t0 = Get-Date
    $done = $false
    while ((Get-Date) -lt $deadline -and -not $done) {
        Start-Sleep -Milliseconds 120
        foreach ($p in @(Get-Process -Name claude -ErrorAction SilentlyContinue)) {
            if ($seen.ContainsKey($p.Id)) { continue }
            $seen[$p.Id] = $true
            $ci = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue
            if (-not $ci -or -not $ci.CommandLine) { continue }
            $cmd = $ci.CommandLine
            if ($cmd -match '--type=' -or $cmd -match '--user-data-dir') { continue }
            if ($cmd -match '(claude://[^"\s]+)') {
                $url = $Matches[1]
                Stop-Tree $p.Id
                Start-ClaudeWith $conta.pasta $url
                $forwarded++
                $kind = ($url -replace '^claude://([^/?#]+/?[^/?#]*).*$', '$1')
                Write-Log "entrar '$nome': link encaminhado ($kind)"
                Write-Host ('  [OK]   ' + (T "Link de login capturado e entregue à conta '$nome' ($kind)." "Sign-in link caught and handed to '$nome' ($kind).")) -ForegroundColor Green
            }
        }
        $log = Get-ProfileLog $conta.pasta
        if ($log -and (Get-Item $log).LastWriteTime -gt $t0) {
            $hit = Get-Content $log -Tail 400 | Where-Object { $_ -match 'account active and logged in' } | Select-Object -Last 1
            if ($hit -and $hit -match '^(\S+ \S+)') {
                $when = [datetime]::MinValue
                if ([datetime]::TryParse($Matches[1], [ref]$when) -and $when -ge $t0.AddSeconds(-1)) { $done = $true }
            }
        }
    }
    Write-Host ''
    if ($done) {
        # Chromium writes cookies to disk in batches about every 30 s. Killing Claude
        # (Task Manager, taskkill /F) before that loses the fresh sign-in cookie, and the
        # account asks to sign in again on the next launch. Wait for the write.
        Write-Host ''
        Write-Host (T 'Login feito. Aguarde: o Claude grava o login no disco a cada ~30 segundos. Não feche nada agora.' 'Signed in. Please wait: Claude writes the sign-in to disk about every 30 seconds. Do not close anything now.') -ForegroundColor Cyan
        for ($s = 45; $s -gt 0; $s -= 5) { Write-Host ("  ... {0} s" -f $s); Start-Sleep -Seconds 5 }
        $st = Get-ProfileState $conta.pasta
        $def = Get-DefaultAccountId
        Write-Host ('  [OK]   ' + (T "Conta '$nome' logada." "'$nome' is signed in.")) -ForegroundColor Green
        if ($st.AccountId -and $def -and $st.AccountId -eq $def) {
            Write-Host ('  [!]    ' + (T "Atenção: '$nome' entrou na MESMA conta do Claude principal. Use outro e-mail para esta conta." "Warning: '$nome' signed in to the SAME account as the main Claude. Use a different email for it.")) -ForegroundColor Yellow
        }
        Write-Host ('  [OK]   ' + (T 'Login gravado. Para fechar uma conta, use o ícone do Claude perto do relógio > Sair, em vez do Gerenciador de Tarefas.' 'Sign-in saved. To close an account, use the Claude icon near the clock > Quit instead of Task Manager.')) -ForegroundColor Green
        Write-Log "entrar '$nome': sucesso (links encaminhados: $forwarded)"
    } else {
        Write-Host (T 'Não vi o login concluir. Se a janela já mostra suas conversas, está tudo certo; senão, rode de novo.' 'Did not see the sign-in finish. If the window already shows your chats, all good; otherwise run it again.') -ForegroundColor Yellow
        Write-Log "entrar '$nome': sem confirmacao (links encaminhados: $forwarded)"
    }
    if ($hadDefault) {
        Write-Host (T 'Reabrindo o Claude principal...' 'Reopening the main Claude...')
        Start-ClaudeWith $null $null
    }
}

function Invoke-Adicionar([string]$nome, [string]$pastaExistente) {
    $nome = $nome.Trim()
    if (-not $nome -or $nome -notmatch '^[\p{L}\p{N} _.-]{1,40}$') { Bad (T 'Nome inválido. Use letras, números, espaço, ponto ou hífen (até 40).' 'Invalid name. Use letters, digits, space, dot or hyphen (up to 40).'); return $null }
    $cfg = Get-Config
    if (Test-IsPrincipal $cfg $nome) { Bad (T "'$nome' é o nome da conta principal. Escolha outro." "'$nome' is the main account's name. Pick another."); return $null }
    if (Find-Conta $cfg $nome) { Warn (T "A conta '$nome' já existe." "Account '$nome' already exists."); return (Find-Conta $cfg $nome) }
    $pasta = if ($pastaExistente) { $pastaExistente } else { Join-Path $PerfisDir (Get-Slug $nome) }
    New-Item -ItemType Directory -Path $pasta -Force | Out-Null
    $num = Get-NextNumero $cfg
    $conta = [pscustomobject]@{ nome = $nome; pasta = $pasta; numero = $num; cor = $CorNumero[$num]; criadaEm = (Get-Date).ToString('s') }
    $cfg.contas = @($cfg.contas) + $conta
    Save-Config $cfg
    Set-AccountShortcuts $cfg $conta
    Write-Log "adicionada '$nome' (#$num) em $pasta"
    Ok (T "Conta '$nome' criada (nº $num). Atalho 'Claude - $nome' na Área de Trabalho e no menu Iniciar." "Account '$nome' created (#$num). Shortcut 'Claude - $nome' on the Desktop and Start menu.")
    return $conta
}

function Invoke-Remover([string]$nome) {
    $cfg = Get-Config
    $conta = Find-Conta $cfg $nome
    if (-not $conta) { Bad (T "Conta '$nome' não encontrada." "Account '$nome' not found."); return }
    foreach ($p in @(Get-InstanceOf $conta.pasta)) { Stop-Tree $p.ProcessId }
    Remove-AccountShortcuts $nome
    $cfg.contas = @($cfg.contas | Where-Object { $_.nome -ne $nome })
    Save-Config $cfg
    Ok (T "Conta '$nome' removida do menu e atalhos apagados." "Account '$nome' removed and shortcuts deleted.")
    if (AskYes (T "Apagar também a pasta com login e histórico local ($($conta.pasta))?" "Also delete the folder with sign-in and local history ($($conta.pasta))?") $false) {
        Start-Sleep -Seconds 2
        Remove-Item $conta.pasta -Recurse -Force -ErrorAction SilentlyContinue
        Ok (T 'Pasta apagada.' 'Folder deleted.')
    }
    Write-Log "removida '$nome'"
}

function Invoke-Renomear([string]$antigo, [string]$novo) {
    $cfg = Get-Config
    $novo = $novo.Trim()
    if (-not $novo -or $novo -notmatch '^[\p{L}\p{N} _.-]{1,40}$') { Bad (T 'Nome inválido.' 'Invalid name.'); return }
    if (Test-IsPrincipal $cfg $antigo) {
        Remove-AccountShortcuts $cfg.principal.nome
        $cfg.principal.nome = $novo; Save-Config $cfg
        Set-PrincipalShortcuts $cfg
    } else {
        $c = Find-Conta $cfg $antigo
        if (-not $c) { Bad (T "Conta '$antigo' não encontrada." "Account '$antigo' not found."); return }
        Remove-AccountShortcuts $antigo
        $c.nome = $novo; Save-Config $cfg
        Set-AccountShortcuts $cfg $c
    }
    Ok (T "Renomeada: '$antigo' -> '$novo' (o login continua o mesmo)." "Renamed: '$antigo' -> '$novo' (the sign-in is kept).")
    Write-Log "renomeada '$antigo' -> '$novo'"
}

function Invoke-Diagnostico {
    $problems = 0
    Say ''
    Say (T "== Diagnóstico - Claude Contas v$ToolVersion ==" "== Diagnostics - Claude Contas v$ToolVersion ==") 'Cyan'
    $pkg = Get-ClaudePackage
    if ($pkg) { Ok ("Claude Desktop {0} ({1})" -f $pkg.Version, $pkg.PackageFamilyName) }
    elseif (Test-Path (Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe')) { Warn (T 'Claude Desktop em instalação antiga (não MSIX).' 'Claude Desktop is a legacy (non-MSIX) install.') }
    else { Bad (T 'Claude Desktop não encontrado. Instale em claude.com/download.' 'Claude Desktop not found. Install from claude.com/download.'); $problems++ }

    $l = Get-ClaudeLauncher
    if ($l -and $l.Kind -eq 'alias') { Ok (T 'Inicializador: apelido claude-desktop.exe (não muda com atualizações)' 'Launcher: claude-desktop.exe alias (unaffected by updates)') }
    elseif ($l) { Warn ((T 'Inicializador: ' 'Launcher: ') + "$($l.Kind) -> $($l.Path)") }
    else { Bad (T 'Nenhum jeito de iniciar o Claude foi encontrado.' 'No way to start Claude was found.'); $problems++ }

    if (Test-Path $ScriptPath) { Ok ((T 'Ferramenta instalada em ' 'Tool installed at ') + $ScriptPath) }
    else { Warn (T 'Ferramenta não instalada na pasta padrão (rode o instalador).' 'Tool not installed in the default folder (run the installer).') }

    $cfg = Get-Config
    $ag = Get-AgendadorInfo
    if ($ag) {
        $h = if ($ag.Horarios.Count) { ', ' + ($ag.Horarios -join ', ') } else { '' }
        $ult = if ($ag.Ultima -and $ag.Ultima.Year -gt 2000) { $ag.Ultima.ToString('dd/MM HH:mm') } else { '-' }
        Ok ((T 'Atualização agendada: ao entrar no Windows' 'Scheduled update: at sign-in') + $h + (T "  (última execução: $ult)" "  (last run: $ult)"))
    } elseif ($cfg.agendador.ativo) { Warn (T 'O agendador estava ligado mas a tarefa sumiu - use Agendador no menu' 'The scheduler was on but the task is gone - use Scheduler in the menu'); $problems++ }
    else { Say (T '  [-]    Atualização agendada: desligada (só atualiza ao abrir um atalho)' '  [-]    Scheduled update: off (updates only when a shortcut is opened)') }
    if (Test-Path (Join-Path $SkillDir 'SKILL.md')) { Ok (T 'Skill /claude-contas instalada no Claude Code' 'Skill /claude-contas installed in Claude Code') }
    if ($cfg.ultimoTeste) { Say ((T '  [-]    Último autoteste: ' '  [-]    Last self-test: ') + $cfg.ultimoTeste) }
    Say ((T '  [-]    Estilo dos ícones: ' '  [-]    Icon style: ') + $cfg.estiloIcone)

    $def = Get-DefaultAccountId
    $mains = @(Get-MainProcesses)
    Say ''
    Say ((T 'Janelas do Claude abertas agora: ' 'Claude instances running now: ') + $mains.Count)
    Say ''
    Say ("  1. {0} {1}" -f $cfg.principal.nome, (T '(Claude normal)' '(regular Claude)')) 'White'
    if (Test-Path (Get-ShortcutPaths $cfg.principal.nome)[0]) { Ok (T 'atalho ok' 'shortcut ok') } else { Warn (T 'sem atalho na Área de Trabalho - use Consertar' 'no Desktop shortcut - use Fix'); $problems++ }
    Say ''
    $ids = @{}
    if ($def) { $ids[$def] = $cfg.principal.nome }
    foreach ($c in ($cfg.contas | Sort-Object { [int]$_.numero })) {
        Say ("  {0}. {1}  ->  {2}" -f $c.numero, $c.nome, $c.pasta) 'White'
        $st = Get-ProfileState $c.pasta
        if (-not $st.Exists) { Bad (T 'pasta não existe' 'folder missing'); $problems++; continue }
        $lnkOk = @(Get-ShortcutPaths $c.nome | Where-Object { Test-Path $_ }).Count
        if ($lnkOk -eq 2) { Ok (T 'atalhos ok' 'shortcuts ok') } else { Warn (T "faltam atalhos ($lnkOk de 2) - use Consertar" "missing shortcuts ($lnkOk of 2) - use Fix"); $problems++ }
        if ($st.LastStart) { Ok ((T 'última abertura: ' 'last opened: ') + $st.LastStart + "  ($($st.Chosen))") } else { Warn (T 'nunca aberta' 'never opened') }
        if ($st.Chosen -and $st.Chosen -ne 'stay_chosen_folder') { Bad ((T 'o app NÃO respeitou a pasta escolhida: ' 'the app did NOT keep the chosen folder: ') + $st.Chosen); $problems++ }
        if ($st.LoggedIn -eq $true) { Ok (T 'logada' 'signed in') }
        elseif ($st.LoggedIn -eq $false) {
            Warn (T 'deslogada - use Entrar' 'signed out - use Sign in'); $problems++
            if ($st.SignedInAtExit -eq $true -and $st.CookieAtStart -eq $false) {
                Warn (T 'o login foi perdido porque o Claude foi encerrado à força (Gerenciador de Tarefas) segundos depois de entrar, antes de gravar o login no disco. Entre de novo e espere 1 minuto antes de fechar; para fechar, use o ícone perto do relógio > Sair.' 'the sign-in was lost because Claude was force-closed (Task Manager) seconds after signing in, before it wrote the sign-in to disk. Sign in again and wait 1 minute before closing; to close, use the icon near the clock > Quit.')
            }
        }
        if ($st.AccountId) {
            if ($ids.ContainsKey($st.AccountId)) { Warn ((T 'é a MESMA conta que ' 'it is the SAME account as ') + "'$($ids[$st.AccountId])'"); $problems++ }
            else { $ids[$st.AccountId] = $c.nome }
        }
        Say ''
    }
    foreach ($x in @(Get-LegacyShortcuts)) { Warn ((T 'atalho antigo (v1) que quebra a cada atualização: ' 'old v1 shortcut that breaks on every update: ') + $x); $problems++ }
    if ($problems -eq 0) { Say (T 'Tudo certo.' 'All good.') 'Green' }
    else { Say ((T 'Pontos de atenção: ' 'Things to look at: ') + $problems) 'Yellow' }
    return $problems
}

# Live test: open a throwaway profile next to whatever is running and confirm the
# app keeps it apart. It is closed as soon as the app logs which folder it took,
# which happens before the window is shown (about 0.4 s vs 0.9 s).
function Invoke-Testar {
    Say ''
    Say (T '== Autoteste (abre e fecha uma instância de teste) ==' '== Self-test (opens and closes a test instance) ==') 'Cyan'
    $l = Get-ClaudeLauncher
    if (-not $l) { Bad (T 'Claude Desktop não encontrado.' 'Claude Desktop not found.'); return $false }
    $tmp = Join-Path $env:TEMP ('claude-contas-teste-' + (Get-Random))
    Start-ClaudeWith $tmp $null @('--startup')
    $result = $null
    for ($i = 0; $i -lt 120 -and -not $result; $i++) {
        Start-Sleep -Milliseconds 150
        $log = Get-ProfileLog $tmp
        if ($log) {
            $hit = Get-Content $log -Tail 300 -ErrorAction SilentlyContinue | Select-String '\[user-data-move\] (\w+)' | Select-Object -Last 1
            if ($hit) { $result = $hit.Matches[0].Groups[1].Value }
        }
    }
    $proc = @(Get-InstanceOf $tmp)
    foreach ($p in $proc) { Stop-Tree $p.ProcessId }
    Start-Sleep -Seconds 2
    foreach ($p in @(Get-InstanceOf $tmp)) { Stop-Tree $p.ProcessId }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    $ver = Get-ClaudeVersion
    if ($result -eq 'stay_chosen_folder' -and $proc.Count -gt 0) {
        Ok (T "O Claude $ver abre uma instância separada com pasta própria. O método funciona." "Claude $ver opens a separate instance with its own folder. The method works.")
        Write-Log "testar: OK ($ver, $($l.Kind))"
        return $true
    }
    $why = if (-not $result) { T 'a instância de teste não gravou nada na pasta escolhida (o app ignorou --user-data-dir ou não abriu)' 'the test instance wrote nothing to the chosen folder (the app ignored --user-data-dir or did not start)' } else { "user-data-move = $result" }
    Bad ((T "Falhou no Claude $ver" "Failed on Claude $ver") + ": $why")
    Say (T 'Rode a skill /claude-contas no Claude Code para investigar a versão nova do app.' 'Run the /claude-contas skill in Claude Code to investigate the new app version.') 'Yellow'
    Write-Log "testar: FALHOU ($ver, $($l.Kind)): $why"
    return $false
}

function Invoke-Reparar {
    Say ''
    Say (T '== Consertar atalhos ==' '== Fix shortcuts ==') 'Cyan'
    New-Item -ItemType Directory -Path $Base -Force | Out-Null
    $self = $PSCommandPath
    if ($self -and (Test-Path $self) -and ((Resolve-Path $self).Path -ne $ScriptPath)) {
        Copy-Item $self $ScriptPath -Force
        Ok ((T 'Ferramenta copiada para ' 'Tool copied to ') + $ScriptPath)
    }
    Remove-Item (Join-Path $IconDir 'claude-base.png') -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $IconDir 'numerado-*.ico') -Force -ErrorAction SilentlyContinue
    $cfg = Get-Config
    Save-Config $cfg
    Set-MenuShortcut
    Ok (T "Atalho 'Claude Contas (menu)' no menu Iniciar" "'Claude Contas (menu)' shortcut in the Start menu")
    Set-PrincipalShortcuts $cfg
    Ok ((T 'Atalhos refeitos: ' 'Shortcuts rebuilt: ') + "Claude - $($cfg.principal.nome)")
    foreach ($c in $cfg.contas) {
        if (-not (Test-Path $c.pasta)) { New-Item -ItemType Directory -Path $c.pasta -Force | Out-Null }
        Set-AccountShortcuts $cfg $c
        Ok ((T 'Atalhos refeitos: ' 'Shortcuts rebuilt: ') + "Claude - $($c.nome)")
    }
    foreach ($x in @(Get-LegacyShortcuts)) {
        if (AskYes ((T 'Apagar atalho antigo (v1) ' 'Delete old v1 shortcut ') + "$x ?") $true) { Remove-Item $x -Force; Ok ((T 'Removido: ' 'Removed: ') + $x) }
    }
    Write-Log 'reparar: concluido'
}

function Set-IconStyle([string]$estilo) {
    $cfg = Get-Config
    $cfg.estiloIcone = $estilo
    Save-Config $cfg
    Invoke-Reparar
}

function Invoke-Instalar {
    Say ''
    Say "Claude Contas v$ToolVersion" 'Cyan'
    Invoke-Reparar
    $cfg = Get-Config

    # 1. main account name
    if ($NomePrincipal) { $cfg.principal.nome = $NomePrincipal; Save-Config $cfg }
    elseif (-not $NoQuestions -and $cfg.contas.Count -eq 0) {
        $n = Ask (T 'Nome da conta principal (a que você já usa no Claude)' 'Name for the main account (the one you already use)') $cfg.principal.nome
        if ($n -ne $cfg.principal.nome) { Invoke-Renomear $cfg.principal.nome $n }
    }

    # 2. v1 folder
    $cfg = Get-Config
    $legacyFolder = Join-Path $env:USERPROFILE 'Claude-Work'
    if ((Test-Path $legacyFolder) -and -not ($cfg.contas | Where-Object { $_.pasta -eq $legacyFolder })) {
        Say ''
        Say (T "Encontrei a pasta da versão 1 ($legacyFolder)." "Found the version 1 folder ($legacyFolder).") 'Cyan'
        $n = Ask (T 'Nome para essa conta' 'Name for that account') 'Work'
        [void](Invoke-Adicionar $n $legacyFolder)
    }

    # 3. accounts
    $cfg = Get-Config
    if ($Contas) {
        foreach ($n in ($Contas -split '[,;]')) { if ($n.Trim()) { [void](Invoke-Adicionar $n.Trim() $null) } }
    } elseif (-not $NoQuestions -and $cfg.contas.Count -eq 0) {
        Say ''
        $q = Ask (T 'Quantas contas EXTRAS além da principal? (1 a 8)' 'How many EXTRA accounts besides the main one? (1 to 8)') '1'
        $qtd = 1; [void][int]::TryParse($q, [ref]$qtd); $qtd = [Math]::Max(1, [Math]::Min(8, $qtd))
        $sug = if ($UsePT) { @('Trabalho', 'Pessoal', 'Cliente', 'Conta 4', 'Conta 5', 'Conta 6', 'Conta 7', 'Conta 8') } else { @('Work', 'Personal', 'Client', 'Account 4', 'Account 5', 'Account 6', 'Account 7', 'Account 8') }
        for ($i = 0; $i -lt $qtd; $i++) {
            $n = Ask ((T 'Nome da conta extra ' 'Name of extra account ') + ($i + 1)) $sug[$i]
            [void](Invoke-Adicionar $n $null)
        }
    } elseif (-not $NoQuestions) {
        Say ''
        Say ((T 'Contas extras já cadastradas: ' 'Extra accounts already set up: ') + (($cfg.contas | ForEach-Object { $_.nome }) -join ', '))
        if (AskYes (T 'Adicionar mais uma?' 'Add another one?') $false) {
            $n = Ask (T 'Nome da nova conta' 'New account name') ''
            if ($n) { [void](Invoke-Adicionar $n $null) }
        }
    }

    # 4. icon style
    $cfg = Get-Config
    $estilo = $Icones
    if (-not $estilo -and -not $NoQuestions) {
        Say ''
        Say (T 'Estilo dos ícones dos atalhos:' 'Shortcut icon style:')
        Say (T '  1. Logo do Claude com selo colorido e a inicial da conta (recomendado)' '  1. Claude logo with a colored badge and the account initial (recommended)')
        Say (T '  2. Ícones numerados coloridos do projeto (1 = principal, 2, 3...)' '  2. The project''s colored numbered icons (1 = main, 2, 3...)')
        $e = Ask (T 'Escolha' 'Choose') '1'
        $estilo = if ($e -eq '2') { 'numerado' } else { 'logo' }
    }
    if ($estilo -and $estilo -ne $cfg.estiloIcone) { Set-IconStyle $estilo }

    # 5. scheduler
    if ($SemAgendador) { }
    elseif ($Agendar) { $h = Get-ValidTimes $Agendar; Register-Agendador $h }
    elseif ($Sim) { Register-Agendador @() }
    elseif (-not $NoQuestions) {
        Say ''
        Say (T 'Atualização automática: o Windows roda uma checagem rápida e silenciosa ao ligar o computador e nos horários que você escolher (ex.: no almoço). Ela atualiza esta ferramenta e testa as contas quando o Claude muda de versão.' 'Automatic update: Windows runs a quick, silent check at sign-in and at the times you choose (e.g. lunch). It updates this tool and tests the accounts when Claude changes version.')
        if (AskYes (T 'Ligar a atualização automática?' 'Turn on automatic update?') $true) {
            $h = Ask (T 'Horários extras, separados por vírgula (ex.: 12:00, 18:30). Enter = só ao ligar' 'Extra times, comma separated (e.g. 12:00, 18:30). Enter = only at sign-in') '12:00'
            Register-Agendador (Get-ValidTimes $h)
        }
    }

    # 6. Claude Code skill
    if ($ComSkill) { [void](Install-Skill) }
    elseif (-not $SemSkill -and -not $NoQuestions -and (Test-ClaudeCode)) {
        Say ''
        if (AskYes (T 'Você usa o Claude Code. Instalar a skill /claude-contas (conserta tudo se o Claude mudar)?' 'You use Claude Code. Install the /claude-contas skill (fixes things if Claude changes)?') $true) { [void](Install-Skill) }
    }

    # 7. sign in
    $cfg = Get-Config
    if (-not $SemEntrar -and -not $NoQuestions) {
        foreach ($c in ($cfg.contas | Sort-Object { [int]$_.numero })) {
            $st = Get-ProfileState $c.pasta
            if ($st.LoggedIn -ne $true) {
                Say ''
                if (AskYes (T "Entrar agora na conta '$($c.nome)'?" "Sign in to '$($c.nome)' now?") $true) { Invoke-Entrar $c.nome }
            }
        }
    }
    Write-Log ("instalar: concluido ({0} contas extras, icones {1})" -f $cfg.contas.Count, $cfg.estiloIcone)
    Say ''
    Ok (T 'Instalação concluída.' 'Installation finished.')
}

function Invoke-AgendadorMenu {
    $ag = Get-AgendadorInfo
    Say ''
    if ($ag) {
        $h = if ($ag.Horarios.Count) { $ag.Horarios -join ', ' } else { T 'nenhum' 'none' }
        Say ((T 'Ligado: ao entrar no Windows + horários: ' 'On: at sign-in + times: ') + $h)
        $prox = if ($ag.Proxima -and $ag.Proxima.Year -gt 2000) { $ag.Proxima.ToString('dd/MM HH:mm') } else { '-' }
        Say ((T 'Próxima execução: ' 'Next run: ') + $prox)
    } else { Say (T 'Desligado.' 'Off.') }
    Say ''
    Say (T '  1. Ligar / mudar horários   2. Desligar   3. Rodar agora   Enter. Voltar' '  1. Turn on / change times   2. Turn off   3. Run now   Enter. Back')
    switch (Ask (T 'Escolha' 'Choose') '') {
        '1' { $h = Ask (T 'Horários separados por vírgula (ex.: 08:00, 12:00, 18:30). Enter = só ao ligar' 'Times, comma separated (e.g. 08:00, 12:00, 18:30). Enter = only at sign-in') ''; Register-Agendador (Get-ValidTimes $h) }
        '2' { Unregister-Agendador }
        '3' { if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Start-ScheduledTask -TaskName $TaskName; Ok (T 'Rodando em segundo plano. Veja o resultado no Diagnóstico daqui a pouco.' 'Running in the background. Check Diagnostics in a moment.') } else { Invoke-Manutencao } }
    }
}

function Show-Menu {
    while ($true) {
        $cfg = Get-Config
        Clear-Host
        Say "Claude Contas v$ToolVersion" 'Cyan'
        Say (T 'Várias contas do Claude Desktop lado a lado.' 'Several Claude Desktop accounts side by side.')
        Say ''
        $openDef = if (@(Get-DefaultInstance).Count -gt 0) { T ', aberta' ', open' } else { '' }
        Say ("  1. {0}  ({1}{2})" -f $cfg.principal.nome, (T 'principal' 'main'), $openDef)
        $lista = @($cfg.contas | Sort-Object { [int]$_.numero })
        foreach ($c in $lista) {
            $st = Get-ProfileState $c.pasta
            $s = if ($st.LoggedIn -eq $true) { T 'logada' 'signed in' } elseif ($st.LoggedIn -eq $false) { T 'deslogada' 'signed out' } else { T 'nunca aberta' 'never opened' }
            $open = if (@(Get-InstanceOf $c.pasta).Count -gt 0) { T ', aberta' ', open' } else { '' }
            Say ("  {0}. {1}  ({2}{3})" -f $c.numero, $c.nome, $s, $open)
        }
        $ag = if (Get-AgendadorInfo) { T 'ligada' 'on' } else { T 'desligada' 'off' }
        Say ''
        Say (T '  [A] Abrir uma conta        [E] Entrar (login) numa conta' '  [A] Open an account         [E] Sign in to an account')
        Say (T '  [N] Nova conta             [R] Remover conta     [M] Mudar nome' '  [N] New account             [R] Remove account    [M] Rename')
        Say (T "  [H] Atualização agendada ($ag)   [I] Estilo dos ícones" "  [H] Scheduled update ($ag)        [I] Icon style")
        Say (T '  [D] Diagnóstico            [T] Testar se o método funciona' '  [D] Diagnostics             [T] Test that the method works')
        Say (T '  [C] Consertar atalhos      [U] Atualizar agora   [K] Skill do Claude Code' '  [C] Fix shortcuts           [U] Update now        [K] Claude Code skill')
        Say (T '  [S] Sair' '  [S] Exit')
        Say ''
        $op = (Read-Host (T 'Escolha' 'Choose')).Trim().ToUpper()
        $pick = {
            param([switch]$WithMain)
            $k = Read-Host (T 'Número da conta' 'Account number')
            $idx = 0
            if (-not [int]::TryParse($k, [ref]$idx)) { return $null }
            if ($idx -eq 1) { if ($WithMain) { return $cfg.principal.nome } else { Warn (T 'A principal não precisa disso.' 'The main account does not need this.'); return $null } }
            $c = $cfg.contas | Where-Object { [int]$_.numero -eq $idx } | Select-Object -First 1
            if ($c) { return $c.nome }
            return $null
        }
        try {
            switch ($op) {
                'A' { $n = & $pick -WithMain; if ($n) { Invoke-Abrir $n } }
                'E' { $n = & $pick; if ($n) { Invoke-Entrar $n } }
                'N' { $n = Read-Host (T 'Nome da nova conta' 'New account name'); if ($n) { $c = Invoke-Adicionar $n $null; if ($c -and (AskYes (T 'Entrar nela agora?' 'Sign in now?') $true)) { Invoke-Entrar $c.nome } } }
                'R' { $n = & $pick; if ($n) { Invoke-Remover $n } }
                'M' { $n = & $pick -WithMain; if ($n) { $novo = Read-Host (T 'Novo nome' 'New name'); if ($novo) { Invoke-Renomear $n $novo } } }
                'H' { Invoke-AgendadorMenu }
                'I' { $e = Read-Host (T '1 = logo do Claude com selo, 2 = ícones numerados' '1 = Claude logo with badge, 2 = numbered icons'); if ($e -eq '2') { Set-IconStyle 'numerado' } elseif ($e -eq '1') { Set-IconStyle 'logo' } }
                'D' { [void](Invoke-Diagnostico) }
                'T' { [void](Invoke-Testar) }
                'C' { Invoke-Reparar }
                'U' { [void](Update-Tool) }
                'K' { [void](Install-Skill) }
                'S' { return }
                ''  { return }
                default { }
            }
        } catch { Bad $_.Exception.Message; Write-Log "menu erro: $($_.Exception.Message)" }
        Say ''
        [void](Read-Host (T 'Enter para voltar ao menu' 'Enter to go back to the menu'))
    }
}

# ---------------------------------------------------------------- entry point
try {
    if ($Versao)      { $ToolVersion; return }
    if ($Abrir)       { Invoke-Abrir $Abrir; return }
    if ($Entrar)      { Invoke-Entrar $Entrar; return }
    if ($Adicionar)   { [void](Invoke-Adicionar $Adicionar $Pasta); return }
    if ($Remover)     { Invoke-Remover $Remover; return }
    if ($Renomear)    { if (-not $Para) { throw (T 'Use -Renomear <nome atual> -Para <novo nome>.' 'Use -Renomear <current name> -Para <new name>.') }; Invoke-Renomear $Renomear $Para; return }
    if ($Diagnostico) { $n = Invoke-Diagnostico; exit ([Math]::Min($n, 1)) }
    if ($Testar)      { if (Invoke-Testar) { exit 0 } else { exit 1 } }
    if ($Reparar)     { Invoke-Reparar; return }
    if ($Atualizar)   { [void](Update-Tool); return }
    if ($Desagendar)  { Unregister-Agendador; return }
    if ($Instalar)    { Invoke-Instalar; return }
    if ($Agendar)     { Register-Agendador (Get-ValidTimes $Agendar); return }
    if ($Manutencao)  { Invoke-Manutencao; return }
    Show-Menu
} catch {
    Write-Log "erro: $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)"
    if ($Abrir -or $Manutencao) { if (-not $Manutencao) { Show-Popup ((T 'Erro ao abrir: ' 'Error while opening: ') + $_.Exception.Message) 'Claude Contas' 'Error' } }
    else { Bad $_.Exception.Message }
    exit 1
}
