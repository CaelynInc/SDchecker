# Build Sentinel standalone .exe only (no installer)
# Run from project root: .\build_exe.ps1
# Requires: Python, PyInstaller

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
$distDir = Join-Path $projectRoot "dist"
$buildDir = Join-Path $projectRoot "build"

# Ensure clean dist/build
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

