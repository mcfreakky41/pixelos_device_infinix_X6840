# STATUS PROJECT - PixelOS X6840 (Infinix Smart 20)

**Terakhir update:** 2026-11-10 (run setelah #70)

---

## 📊 Ringkasan Status

| Item | Status |
|------|--------|
| Device tree | ✅ di-commit ke branch `main` |
| Vendor blobs | ✅ di-upload (GitHub Release `blobs-v1`) |
| Kernel prebuilt | ✅ ada (mt6768, arm64, prebuilt) |
| Workflow CI | ✅ aktif, manual dispatch via GitHub Actions |
| Runner | **ubuntu-24.04-arm** (native arm64 build) |
| Target | **PixelOS `sixteen` (Android 16)** |
| Release config | **bp2a** (PixelOS sixteen) |
| Build terkini | Workflow disk-fix siap dijalankan ulang (lihat bagian *Perbaikan Disk*) |
| Panduan flash | 📄 [docs/FLASHING.md](FLASHING.md) |

---

## 🎯 Keputusan Arsitektur

### Skenario Dipilih: **Android 16 dengan vendor API 35**
- ✅ **Android 16 GSI (AxionOS 2.8) BERHASIL BOOT** di device
- ✅ Platform A16 + vendor API 35 **kompatibel** (VINTF match)
- ✅ Build dengan fstab yang sudah di-fix (AVB flags benar)
- ✅ Semua Qualcomm HAL dinon-kan karena MediaTek MT6768

---

## 🔧 Perbaikan Utama yang Diterapkan

### Source Tree Fixes (`scripts/fix-source-tree.sh`)
- Nonaktifkan semua `hardware/qcom/**/Android.bp` (MediaTek MT6768 tidak butuh HAL Qualcomm)
- Nonaktifkan `hardware/lineage/livedisplay/**/Android.bp` (HIDL vs AIDL mismatch)
- Nonaktifkan `packages/apps/SimpleSettingsConfig/Android.bp` (butuh LineageOS SDK)
- Nonaktifkan `vendor/qcom/opensource/vibrator/` (Qualcomm-only modules)

### Konfigurasi Build
- **BoardConfig.mk:** Hapus variabel usang, koreksi kernel offsets
- **pixelos_X6840.mk:** Setup API level 36, fingerprint benar
- **device.mk:** Pakai PRODUCT_SYSTEM_PROPERTIES, bukan PRODUCT_PROPERTY_OVERRIDES

### Filesystem
- **fstab.mt6768:** Fix `avb=` flags (vendor/odm → vbmeta_vendor, product/system → vbmeta_system)
- **sepolicy:** Hapus tipe tidak terpakai (vendor_mtk_prop, transsion_service)

### CI Workflow (`.github/workflows/build.yml`)
- Build `-j3` pada runner 4 vCPU / 16 GB, swap 6 GB dibuat **setelah** sync
- `ulimit -v unlimited` - Tingkatkan memory limit
- Build log di-upload meskipun gagal
- Toolchain host ARM64 lengkap: Go (`go install std`), Rust (lib64 + rust-src), Clang r584948b, JDK 8 & 21

### 💾 Perbaikan Disk (`No space left on device`)
Runner hanya punya ~145 GB (OS ~21 GB), sedangkan sync penuh bisa ~120 GB
(worktree 91 GB + `.repo` ~29 GB) sehingga menyisakan < 5 GB.

Yang diterapkan:
- **Free disk agresif** sebelum sync (toolcache, docker, apt cache, dll.)
- **Local manifest** membuang project x86/emulator/cuttlefish/bazel/openwrt
  yang tidak dipakai build ARM64 (±10 GB lebih hemat)
- **`.repo` dihapus** setelah sync sebelum build
- **Swap tidak dibuat saat sync** (baru dibuat sebelum build) → +4-6 GB headroom
- **Retry sync tanpa `--force-sync`** agar objek tidak terduplikasi dan disk tidak habis
- **ccache 2 GB** dan upload artifact dibatasi (tanpa `super.img`)
- Guard/print `df -h` di setiap tahap penting

---

## ⏳ Yang Masih Tertunda

- Optimasi build time dengan cache yang lebih agresif
- Investigasi performance di perangkat nyata
- Dokumentasi testing di luar GSI

---

## 📋 Verifikasi Build

```bash
# Cek status build terbaru
gh run list -R mcfreakky41/pixelos_device_infinix_X6840

# Atau lihat via GitHub Actions UI
```

---

## ⚡ Panduan Flash

Lihat [`docs/FLASHING.md`](FLASHING.md).

**Yang harus di-flash:**
- `system.img`, `system_ext.img`, `product.img`, `vbmeta*.img` (dengan `--disable-verity --disable-verification`)

**Yang tidak boleh di-flash:**
- `super.img` - vendor.img hasil rebuild tidak valid
- `boot`, `vendor_boot`, `init_boot`, `dtbo`, `vendor`, `odm`, `*_dlkm` - tetap stok

---

## ⚠️ Catatan Penting

- HP **JANGAN** di-reboot sampai ROM siap flash
- Semua operasi device = read-only
- Hanya flash: `system`, `system_ext`, `product`, `vbmeta`
- `boot`/`vendor_boot`/`init_boot`/`dtbo`/`vendor`/`odm`/`*_dlkm` **tetap stok**