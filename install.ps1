# Claude Contas - installer / instalador
#
# Run in PowerShell (no admin needed) / Rode no PowerShell (sem administrador):
#   irm https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main/install.ps1 | iex
#
# Running it again updates the tool and repairs the shortcuts. Your sign-ins are kept.
# Rodar de novo atualiza a ferramenta e conserta os atalhos. Os logins sao mantidos.

& {
    $ErrorActionPreference = 'Stop'
    $raw  = 'https://raw.githubusercontent.com/VinguardCP/claude-desktop-multi-account-windows/main'
    $base = Join-Path $env:LOCALAPPDATA 'ClaudeContas'
    $dest = Join-Path $base 'claude-contas.ps1'
    $pt   = (Get-Culture).Name -like 'pt*'
    function T($a, $b) { if ($pt) { [regex]::Unescape($a) } else { $b } }

    Write-Host ''
    Write-Host 'Claude Contas' -ForegroundColor Cyan
    Write-Host (T 'Instalando...' 'Installing...')

    $pkg = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*Claude*' -and $_.Publisher -like '*Anthropic*' } | Select-Object -First 1
    $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\claude-desktop.exe'
    if (-not $pkg -and -not (Test-Path $alias) -and -not (Test-Path (Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'))) {
        Write-Host (T 'O Claude Desktop n\u00e3o est\u00e1 instalado. Instale em https://claude.com/download, abra uma vez e rode este comando de novo.' 'Claude Desktop is not installed. Install it from https://claude.com/download, open it once and run this command again.') -ForegroundColor Yellow
        return
    }

    New-Item -ItemType Directory -Path $base -Force | Out-Null
    $local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'claude-contas.ps1' } else { $null }
    if ($local -and (Test-Path $local)) {
        Copy-Item $local $dest -Force
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $tmp = Join-Path $env:TEMP ('claude-contas-' + [guid]::NewGuid().ToString('N') + '.ps1')
        Invoke-WebRequest -UseBasicParsing -Uri "$raw/claude-contas.ps1" -OutFile $tmp -TimeoutSec 30
        $errs = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($tmp, [ref]$null, [ref]$errs)
        if ($errs -and $errs.Count -gt 0) { throw (T 'O arquivo baixado veio com erro. Tente de novo em alguns minutos.' 'The downloaded file is broken. Try again in a few minutes.') }
        Move-Item $tmp $dest -Force
    }
    Unblock-File $dest -ErrorAction SilentlyContinue

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dest -Instalar

    Write-Host ''
    Write-Host (T 'Pronto! Como usar:' 'Done! How to use it:') -ForegroundColor Green
    Write-Host (T '  - Conta principal: o Claude normal, como sempre.' '  - Main account: the regular Claude, as always.')
    Write-Host (T '  - Outras contas: atalhos "Claude - <nome>" na \u00c1rea de Trabalho e no menu Iniciar.' '  - Other accounts: "Claude - <name>" shortcuts on the Desktop and Start menu.')
    Write-Host (T '  - Para gerenciar (nova conta, login, testar, consertar): menu Iniciar > "Claude Contas (menu)".' '  - To manage (new account, sign in, test, repair): Start menu > "Claude Contas (menu)".')
}
