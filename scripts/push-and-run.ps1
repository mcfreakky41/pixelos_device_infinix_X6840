# push-and-run.ps1 - commit + push device tree, lalu dispatch build run di GitHub Actions.
#
# Pakai (pesan commit WAJIB diisi, supaya tidak ada pesan lama yang ikut terpakai):
#   powershell -ExecutionPolicy Bypass -File scripts\push-and-run.ps1 -Msg "fix(device): ..."
#
# Opsional: -Repo <folder repo> (default: folder induk dari scripts\), -Remote, -Branch.
# Aman diulang: kalau tak ada perubahan, commit dilewati.
param(
  [Parameter(Mandatory = $true)][string]$Msg,
  [string]$Repo   = (Split-Path -Parent $PSScriptRoot),
  [string]$Remote = "mcfreakky41/pixelos_device_infinix_X6840",
  [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

# --- git tersedia? ---
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
  Write-Host "!! git tidak ditemukan di PATH. Pasang Git for Windows dulu." -ForegroundColor Red
  exit 1
}
$git = $gitCmd.Source

Set-Location $Repo

Write-Host "== git status ==" -ForegroundColor Cyan
& $git status --short

$dirty = (& $git status --porcelain)
if ($dirty) {
  Write-Host "== add + commit ==" -ForegroundColor Cyan
  & $git add -A
  if ($LASTEXITCODE -ne 0) { Write-Host "!! git add gagal (exit $LASTEXITCODE)" -ForegroundColor Red; exit $LASTEXITCODE }
  & $git commit -m $Msg
  if ($LASTEXITCODE -ne 0) { Write-Host "!! git commit gagal (exit $LASTEXITCODE)" -ForegroundColor Red; exit $LASTEXITCODE }
} else {
  Write-Host ">> tidak ada perubahan untuk di-commit" -ForegroundColor Yellow
}

Write-Host "== push ==" -ForegroundColor Cyan
# git menulis progres ke stderr; $LASTEXITCODE tetap penentu sukses.
& $git push origin $Branch
$pushExit = $LASTEXITCODE
if ($pushExit -ne 0) {
  Write-Host "!! push gagal (exit $pushExit)" -ForegroundColor Red
  exit $pushExit
}

Write-Host "== head commit ==" -ForegroundColor Cyan
& $git log -1 --oneline

Write-Host "== dispatch workflow ==" -ForegroundColor Cyan
$ghOk = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
if ($ghOk) {
  gh workflow run build.yml -R $Remote --ref $Branch
  Start-Sleep -Seconds 5
  gh run list -R $Remote --limit 3
} else {
  Write-Host ">> 'gh' tidak ada. Buat run lewat UI:" -ForegroundColor Yellow
  Write-Host "   https://github.com/$Remote/actions/workflows/build.yml"
  Write-Host "   (Run workflow -> branch main -> Run workflow)"
}

Write-Host ""
Write-Host "== selesai ==" -ForegroundColor Green
