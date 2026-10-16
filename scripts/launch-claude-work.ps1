# EXPERIMENTAL - not tested on every setup.
# Finds where Claude Desktop (MSIX package) is installed and launches a second
# instance that uses the "Claude-Work" data folder inside the user profile.

$dataFolder = Join-Path $env:USERPROFILE "Claude-Work"

# Look for the installed MSIX package
$package = Get-AppxPackage -Name "Claude" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $package) {
    $package = Get-AppxPackage -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*Claude*" } |
        Select-Object -First 1
}

if (-not $package) {
    Write-Host "Could not find Claude installed as an MSIX package."
    Write-Host "Use the manual method with the .bat file instead (see the README)."
    exit 1
}

$exe = Join-Path $package.InstallLocation "app\claude.exe"

if (-not (Test-Path $exe)) {
    Write-Host "Found the package, but not claude.exe at: $exe"
    Write-Host "Use the manual method with the .bat file instead (see the README)."
    exit 1
}

Start-Process -FilePath $exe -ArgumentList "--user-data-dir=`"$dataFolder`""
