# push-and-run.ps1 — commit + push device tree, lalu dispatch build run di GitHub Actions.
#
# Pakai:
#   powershell -ExecutionPolicy Bypass -File E:\PixelOS-X6840\repo\scripts\push-and-run.ps1
#
# Aman diulang: kalau tak ada perubahan, commit dilewati.

$ErrorActionPreference = "Stop"

$Repo   = "E:\PixelOS-X6840\repo"
$Remote = "mcfreakky41/pixelos_device_infinix_X6840"
$Branch = "main"
$Msg    = "fix(device): virtual_ab_ota launcher.mk tidak ada di A16 -> launch_with_vendor_ramdisk.mk (fix run #19)"

# --- git tersedia? ---
$git = "C:\Users\Administrator\pixelos-smart20\tools\git\cmd\git.exe"
if (-not (Test-Path $git)) { $git = "git" }

Set-Location $Repo

Write-Host "== git status ==" -ForegroundColor Cyan
& $git status --short

$dirty = (& $git status --porcelain)
if ($dirty) {
  Write-Host "== add + commit ==" -ForegroundColor Cyan
  & $git add -A
  & $git commit -m $Msg
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
