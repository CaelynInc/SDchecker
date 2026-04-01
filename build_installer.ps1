# Build Sentinel standalone .exe and (optionally) installer
# Run from project root: .\build_installer.ps1
# Requires: Python, PyInstaller. If Inno Setup (iscc) is available, also builds installer.

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$distDir = Join-Path $projectRoot "dist"
$buildDir = Join-Path $projectRoot "build"

# Ensure clean dist
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
if (Test-Path $buildDir) { Remove-Item $buildDir -Recurse -Force }
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

Write-Host "Installing PyInstaller..."
python -m pip install -q pyinstaller

Write-Host "Building Sentinel.exe..."
Set-Location $projectRoot
python -m PyInstaller --onefile `
    --windowed `
    --name "Sentinel" `
    --paths . `
    --hidden-import "sentinel.drive" `
    --hidden-import "sentinel.config" `
    --hidden-import "sentinel.core" `
    --hidden-import "sentinel.sweep" `
    --hidden-import "sentinel.recommendation" `
    --hidden-import "sentinel.api" `
    --hidden-import "sentinel.eula" `
    sentinel_ui.py

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed."
    exit 1
}

$exe = Join-Path $distDir "Sentinel.exe"
if (Test-Path $exe) {
    Write-Host "Build complete: $exe"
} else {
    Write-Host "Build may have failed - exe not found."
    exit 1
}

# Inno Setup installer. Prefer PATH, then fall back to default install paths.
# Version is synced from sentinel/__init__.py.
$isccCmd = Get-Command iscc -ErrorAction SilentlyContinue
$isccPath = if ($isccCmd) { $isccCmd.Source } else { $null }
if (-not $isccPath) {
    $candidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $isccPath = $candidate
            break
        }
    }
}

if ($isccPath) {
    $initPy = Join-Path $projectRoot "sentinel" "__init__.py"
    $issPath = Join-Path $projectRoot "installer.iss"
    if (Test-Path $initPy) {
        $line = Get-Content $initPy | Where-Object { $_ -match '__version__\s*=\s*"([^"]+)"' }
        if ($line -match '__version__\s*=\s*"([^"]+)"') {
            $ver = $Matches[1]
            (Get-Content $issPath) -replace '#define MyAppVersion "[^"]*"', "#define MyAppVersion `"$ver`"" | Set-Content $issPath
        }
    }
    Write-Host "Building installer..."
    & $isccPath $issPath
    if ($LASTEXITCODE -eq 0) {
        $installer = Join-Path $projectRoot "Output" "Sentinel_Setup.exe"
        if (Test-Path $installer) {
            Write-Host "Installer complete: $installer"
        }
    }
} else {
    Write-Host "Inno Setup not found (iscc). Install from https://jrsoftware.org/isinfo.php to build installer."
    Write-Host "Standalone exe is ready: $exe"
}
