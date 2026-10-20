# STATUS PROJECT — PixelOS X6840

Terakhir update: 2026-10-20 (run #5 — target Android 16)

## Ringkas
| Item | Status |
|---|---|
| Device tree | pushed (commit `da90e0c`) |
| Vendor blobs | uploaded (Release blobs-v1) |
| Kernel prebuilt | ada (34.77 MB, ARM64 valid, SHA256 AE1703…) |
| Workflow CI | aktif, manual dispatch |
| Target | **PixelOS `sixteen` (Android 16)** |
| Build terkini | run #5 (`sixteen`, userdebug, commit da90e0c) |

## Keputusan arah
- **Skenario C** (disetujui user): coba Android 16 dulu; fallback ke `fifteen` (A15) kalau mentok.
- Alasan: GSI Android 16 (AxionOS 2.8) **terbukti boot** di device ini (slot `_a`, Boot completed ~105 s)
  → platform A16 + vendor API 35 kompatibel di HP ini.
- Bukti: `E:\opencode-backup-20261003-080644\sessions-md\2026-09-17_Infinix_Smart_20_Evolution_X_GSI_800_MB.md`
  dan `E:\PixelOS-X6840\FINDINGS-HDD.md`.

## Riwayat build
| Run | Target | Hasil | Error | Perbaikan |
|---|---|---|---|---|
| #1 | — | cancelled | trigger ganda | — |
| #2 | fifteen | failure | branch `pixelos-15.2` tidak ada | ganti ke `fifteen`, JDK, artifact path |
| #3 | fifteen | cancelled (sengaja) | — | BoardConfig+rootdir+sepolicy belum lengkap |
| #4 | fifteen | cancelled | pindah target ke A16 | — |
| #5 | **sixteen** | jalan | — | API 36, runner ubuntu-24.04, JDK 21, jobs halved |

## Link
- Repo   : https://github.com/mcfreakky41/pixelos_device_infinix_X6840
- Release: https://github.com/mcfreakky41/pixelos_device_infinix_X6840/releases/tag/blobs-v1
- Actions: https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions

## Cara cek build
```
gh run list -R mcfreakky41/pixelos_device_infinix_X6840
```
atau via API (script: scripts/check-build.ps1)

## Yang sudah dilengkapi (commit da90e0c)
- BoardConfig.mk: DEVICE_PATH, ukuran partisi byte-exact, boot/init_boot/vendor_boot,
  kernel offsets, A/B partition list, AVB vbmeta_system+vendor, bootconfig
- device.mk: API 36, ART tuning 4GB, DSDS/VoLTE, fstab copy, dynamic partitions
- pixelos_X6840.mk: inherit `vendor/aosp/config/common_full_phone.mk`
- rootdir/etc/fstab.mt6768 (ext4 build, turunan stock fstab.mt6768)
- sepolicy/vendor/mtk.te (minimal, self-contained)
- vendorsetup.sh (lunch combo)
- workflow: default branch `sixteen`, ubuntu-24.04, openjdk-21, -j$(nproc)/2

## Perkiraan error berikutnya (siap diantisipasi)
1. **VINTF mismatch** — manifest vendor (API 35) vs compatibility matrix system (API 36)
2. **Missing separator/`Android.bp`** untuk rootdir
3. **Blob yang butuh `Android.bp`** (mis. lib yang harus dikompilasi, bukan di-copy)
4. **Kekurangan HAL A16** di vendor API 35 (mis. `system_dlkm` versi baru)

## Catatan penting
- HP JANGAN di-reboot sampai ROM siap flash
- Semua operasi device = read-only
- super.img (9 GB) = backup lokal saja (header gDla, tidak bisa lpunpack)
- vendor/bin: 100% 64-bit (0 file 32-bit) → arm64-only sudah benar
- Kernel backup HDD **IDENTIK** dengan kernel proyek (verified SHA256)
- Prosedur flash terbukti (dari era GSI):
  `adb reboot fastboot` → `fastboot flash system <img>` → `fastboot erase userdata` → `fastboot reboot`
