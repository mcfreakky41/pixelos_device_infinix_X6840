# STATUS PROJECT - PixelOS X6840 (Infinix Smart 20)

Terakhir update: 2026-10-27 (run #70 sedang berjalan)

## Ringkas
| Item | Status |
|---|---|
| Device tree | di-commit ke branch `main` (commit `f7e798e`) |
| Vendor blobs | di-upload (GitHub Release `blobs-v1`) |
| Kernel prebuilt | ada (mt6768, arm64, prebuilt) |
| Workflow CI | aktif, manual dispatch via GitHub Actions |
| Runner | **ubuntu-24.04-arm** (108 GB free, native arm64 build) |
| Target | **PixelOS `sixteen` (Android 16)** |
| Release config | **bp2a** (PixelOS sixteen) |
| Build terkini | run #70 - sedang berjalan |
| Panduan flash | [`docs/FLASHING.md`](FLASHING.md) |

## Keputusan arah
- **Skenario C** (disetujui): coba Android 16 dulu; fallback ke Android 15 kalau benar-benar tidak bisa.
- Alasan: GSI Android 16 (AxionOS 2.8) **terbukti boot** di device ini.
- Platform A16 + vendor API 35 kompatibel di Infinix Smart 20 (mt6768).

## Riwayat build (terbaru)
| Run | Target | Hasil | Error utama | Perbaikan |
|---|---|---|---|---|
| #25-#26 | sixteen | failure | rust-src, build-tools syntax | arm64 host patches |
| #27-#42 | sixteen | failure | prebuilts/build-tools, qcom symlinks, build-tools syntax | source tree fix scripts |
| #43-#60 | sixteen | failure | fix-source-tree path, commas, livedisplay, SimpleSettingsConfig, VibratorCL | perbaikan fix-source-tree.sh |
| #61-#64 | sixteen | failure | Common_CFlags (qualcomm vibrator), fstab avb flags, PRODUCT_PROPERTY_OVERRIDES → SYSTEM_PROPERTIES | disable ALL qcom hardware/qcom Android.bp |
| #65-#69 | sixteen | failure | prebuilt_any di Android.bp (tidak diizinkan) | ganti ke PRODUCT_COPY_FILES di vendor.mk |
| #70 | sixteen | **berjalan** | - | disable ALL hardware/qcom/ Android.bp |

## Perbaikan utama yang diterapkan

### Source tree fixes (`scripts/fix-source-tree.sh`)
- Nonaktifkan semua `hardware/qcom/**/Android.bp` (MediaTek MT6768 tidak butuh HAL Qualcomm)
- Nonaktifkan `hardware/lineage/livedisplay/**/Android.bp` (HIDL vs AIDL mismatch)
- Nonaktifkan `packages/apps/SimpleSettingsConfig/Android.bp` (butuh `org.lineageos.platform.internal` yang tidak ada)
- Nonaktifkan `vendor/qcom/opensource/vibrator/` (Qualcomm-only, dependensi `libspf-headers`, `libarosal_headers` tidak ada)
- Hapus referensi `vendor.lineage.livedisplay-V2-*` dari `frameworks/base/Android.bp`
- Generic fix broken symlinks `hardware/qcom/*/Android.bp -> gps/os_pickup.bp`

### BoardConfig.mk
- Hapus variabel usang: `TARGET_DEVICE`, `TARGET_BOARD_API_LEVEL`, `BOARD_SYSTEMSDK_VERSIONS`, `BOARD_VNDK_VERSION`, `TARGET_USES_ION`, `TARGET_USES_HWC2`, `NUM_FRAMEBUFFER_SURFACE_BUFFERS`, `BOARD_SUPER_PARTITION_BLOCK_DEVICE_SIZE_OVERRIDE`, `AB_OTA_UPDATER`
- Kernel offsets, `BOARD_MKBOOTIMG_ARGS`, `BOARD_MAIN_SIZE`, dynamic partition sizes di-comment
- `TARGET_SCREEN_WIDTH := 720`, `TARGET_SCREEN_HEIGHT := 1640` (di pindah ke `pixelos_X6840.mk`)

### pixelos_X6840.mk
- `core_64_bit_only.mk` (64-bit only device)
- `TARGET_SCREEN_WIDTH := 720`, `TARGET_SCREEN_HEIGHT := 1640` (sebelum inherit vendor/aosp)
- `PRODUCT_SHIPPING_API_LEVEL := 36`
- `BUILD_FINGERPRINT := Infinix/X6840-OP/Infinix-X6840:16/BP2A.250605.031.A3/301400019:user/release-keys`

### device.mk
- `PRODUCT_SHIPPING_API_LEVEL := 36`
- `PRODUCT_PROPERTY_OVERRIDES` → `PRODUCT_SYSTEM_PROPERTIES` (karena vendor.img tidak di-flash)
- 15 APK vendor di `PRODUCT_COPY_FILES` (sebelumnya prebuilt_any di Android.bp, tidak diizinkan PixelOS sixteen)

### fstab.mt6768
- Fix `avb=` flags: vendor/odm → `vbmeta_vendor`, product/system → `vbmeta_system`

### sepolicy/vendor/mtk.te
- Hapus `vendor_mtk_prop` dan `transsion_service` (tidak ada `property_contexts`/`service_contexts`)
- Hapus `allow untrusted_app_all` (redundan karena `app_api_service` sudah cukup)

### CI workflow (`.github/workflows/build.yml`)
- `set -o pipefail` di step Build (deteksi mka gagal)
- `set +e` di step Fix disk space (hindari exit code 1 dari docker/apt)
- `ccache -M 1G` (dari 2G)
- `JOBS=$(( $(nproc/all) / 4 ))` (dari /2, yaitu -j1)
- Swap 4G diaktifkan (sebelumnya dimatikan)
- Fix source tree step dengan `fix-source-tree.sh`

## Yang masih tertunda (low priority)
- fstab: ext4 vs EROFS (stok pakai EROFS, tapi vendor.img tidak di-flash jadi aman)
- `BOARD_SUPER_PARTITION_BLOCK_DEVICE_SIZE_OVERRIDE` sudah dihapus

## Cara cek build
```
gh run list -R mcfreakky41/pixelos_device_infinix_X6840
```
atau via GitHub Actions UI.

## Panduan flash
Lihat [`docs/FLASHING.md`](FLASHING.md). Hanya flash: `system.img`, `system_ext.img`, `product.img`, `vbmeta*.img` dengan `--disable-verity --disable-verification`. Jangan flash `super.img` atau `vendor*.img`.

## Catatan penting
- HP **JANGAN** di-reboot sampai ROM siap flash
- Semua operasi device = read-only
- Hanya flash: `system`, `system_ext`, `product`, `vbmeta`
- `boot`/`vendor_boot`/`init_boot`/`dtbo`/`vendor`/`odm`/`*_dlkm` **tetap stok**
