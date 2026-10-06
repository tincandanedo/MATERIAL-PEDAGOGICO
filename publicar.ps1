# publicar.ps1 — Exporta un notebook marimo y lo publica en GitHub Pages
# Colocar este archivo (y publicar.bat) en la carpeta raíz del repo MATERIEL-PEDAGOGIQUE,
# junto a las carpetas sitio, sitio_muro, maison_panne.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

$repo = $PSScriptRoot
Set-Location $repo

function Fin($msg) { Write-Host ""; Write-Host $msg -ForegroundColor Red; Read-Host "Presiona Enter para cerrar"; exit 1 }

# 0. Verificaciones
if (-not (Test-Path (Join-Path $repo ".git"))) { Fin "Este script debe estar en la carpeta raíz del repo (la que contiene .git)." }

$marimo = $null
if (Get-Command marimo -ErrorAction SilentlyContinue) { $marimo = @("marimo") }
elseif (Get-Command uvx -ErrorAction SilentlyContinue) { $marimo = @("uvx", "marimo") }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $marimo = @("python", "-m", "marimo") }
else { Fin "No encuentro marimo, uvx ni python en este equipo." }

# 1. Elegir el notebook
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title = "Elige el notebook marimo (.py) que quieres publicar"
$dlg.Filter = "Notebook marimo (*.py)|*.py"
$dlg.InitialDirectory = [Environment]::GetFolderPath("MyDocuments")
if ($dlg.ShowDialog() -ne "OK") { Fin "Cancelado." }
$nb = $dlg.FileName

# 2. Nombre de la carpeta de destino (= parte final de la URL)
$defecto = [IO.Path]::GetFileNameWithoutExtension($nb)
$nombre = [Microsoft.VisualBasic.Interaction]::InputBox(
  "Nombre de la carpeta en el sitio (será la URL).`nEj.: maison_panne, sitio_muro",
  "Carpeta de destino", $defecto)
if ([string]::IsNullOrWhiteSpace($nombre)) { Fin "Cancelado." }
$nombre = $nombre.Trim() -replace '\s+', '_'
$destino = Join-Path $repo $nombre

# 3. Traer cambios remotos para evitar conflictos al subir
Write-Host "`n[1/4] Actualizando el repo..." -ForegroundColor Cyan
git pull --rebase --autostash
if ($LASTEXITCODE -ne 0) { Fin "git pull falló. Revisa el repo en VS Code." }

# 4. Exportar
Write-Host "`n[2/4] Exportando $([IO.Path]::GetFileName($nb)) -> $nombre ..." -ForegroundColor Cyan
$exe = $marimo[0]; $pre = @(); if ($marimo.Count -gt 1) { $pre = @($marimo[1..($marimo.Count-1)]) }
& $exe @pre export html-wasm "$nb" -o "$destino" --mode run -f
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $destino "index.html"))) { Fin "La exportación falló." }
if (-not (Test-Path (Join-Path $repo ".nojekyll"))) { New-Item (Join-Path $repo ".nojekyll") -ItemType File | Out-Null }

# 5. Commit y push
Write-Host "`n[3/4] Guardando (commit)..." -ForegroundColor Cyan
git add -A -- "$nombre" ".nojekyll"
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) { Write-Host "No hay cambios nuevos que publicar." -ForegroundColor Yellow }
else {
  git commit -m "Publicar $nombre"
  Write-Host "`n[4/4] Subiendo a GitHub (push)..." -ForegroundColor Cyan
  git push
  if ($LASTEXITCODE -ne 0) { Fin "git push falló." }
}

# 6. Enlace final
$remoto = git remote get-url origin
$usuario = ([regex]::Match($remoto, 'github\.com[:/]([^/]+)/')).Groups[1].Value
$url = "https://$usuario.github.io/MATERIEL-PEDAGOGIQUE/$nombre/"
Write-Host "`nListo. GitHub tarda ~1 minuto en publicar (a veces más)." -ForegroundColor Green
Write-Host "Enlace: $url" -ForegroundColor Green
Set-Clipboard $url
Write-Host "(El enlace ya está copiado al portapapeles.)"
Start-Process "https://github.com/$usuario/materiel-pedagogique/actions"
Read-Host "`nPresiona Enter para cerrar"
