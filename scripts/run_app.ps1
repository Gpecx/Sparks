# Roda o SPARK localmente para visualizacao rapida.
# Uso: na raiz do projeto, no PowerShell:
#   .\scripts\run_app.ps1            -> abre no Chrome (web), com hot reload
#   .\scripts\run_app.ps1 -Windows   -> roda como app desktop Windows
#
# Para parar: tecle 'q' no terminal (ou Ctrl+C).
# Tudo roda SO no seu PC - nada e exposto na internet.

param(
    [switch]$Windows
)

$ErrorActionPreference = 'Stop'
Set-Location -Path (Split-Path -Parent $PSScriptRoot)

Write-Host "==> Garantindo dependencias (flutter pub get)..." -ForegroundColor Cyan
flutter pub get

if ($Windows) {
    Write-Host "==> Iniciando como app desktop Windows..." -ForegroundColor Green
    flutter run -d windows
}
else {
    Write-Host "==> Iniciando no Chrome (web)..." -ForegroundColor Green
    Write-Host "    Quando abrir, navegue ate a aba FERRAMENTAS para ver as novas calculadoras." -ForegroundColor DarkGray
    flutter run -d chrome
}
