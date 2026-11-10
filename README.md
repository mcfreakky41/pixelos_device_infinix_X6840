# PixelOS Device Tree untuk Infinix Smart 20 (X6840 / X6840B)

[![Build](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions/workflows/build.yml/badge.svg)](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Android-16%20(PixelOS%20sixteen)-3ddc84.svg)](https://github.com/PixelOS-AOSP)
[![Device](https://img.shields.io/badge/device-Infinix%20X6840-orange.svg)](#perangkat)

---

## 📱 Perangkat

| Spesifikasi | Nilai |
|-------------|-------|
| **Model** | Infinix Smart 20 (X6840 / X6840B) |
| **SoC** | MediaTek Helio G81 Ultimate (**mt6768**) |
| **Kernel** | 6.6.x (prebuilt dari dump stok) |
| **Target Android** | **16** (PixelOS `sixteen`) |
| **Arsitektur** | arm64-v8a (64-bit only) |
| **Partisi** | A/B + dynamic (`super`) + `vendor_boot` |
| **Codename vendor** | `tssi` |
| **Build Fingerprint** | `Infinix/X6840-OP/Infinix-X6840:16/BP2A.250605.031.A3/301400019:user/release-keys` |

---

## 📦 Struktur Repositori

```
device/infinix/X6840/     # Device tree (BoardConfig, device.mk, rootdir, sepolicy, prebuilt kernel)
vendor/infinix/X6840/     # Vendor tree (blobs di Download terpisah)
patches/arm64-host/       # Patch build host ARM64
scripts/                  # Skrip bantu (fetch blobs, apply patches)
.github/workflows/       # CI build (GitHub Actions)
docs/                     # STATUS.md, panduan flash, dokumentasi
```

> **Catatan:** Blob vendor tidak disimpan di git (ratusan MB). Diunduh otomatis via [Release `blobs-v1`](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/releases/tag/blobs-v1).

---

## 🏗️ Build

### Otomatis (Cara Utama)

Build berjalan di **GitHub Actions** pada runner `ubuntu-24.04-arm`:

```bash
gh workflow run build.yml -R mcfreakky41/pixelos_device_infinix_X6840
```

Atau lewat:
1. Buka tab **Actions** → pilih **build.yml**
2. Klik **Run workflow**
3. Pilih `build_type` (userdebug / user / eng)
4. Klik **Run workflow**

### Lokal

```bash
# 1. Sinkron source
repo init -u https://github.com/PixelOS-AOSP/manifest -b sixteen --depth=1
repo sync -c -j$(nproc --all)

# 2. Terapkan patch ARM64 host
bash device/infinix/X6840/scripts/apply-arm64-host.sh

# 3. Fetch vendor blobs
bash device/infinix/X6840/scripts/fetch-blobs.sh vendor/infinix/X6840/proprietary

# 4. Build
source build/envsetup.sh
lunch pixelos_X6840 bp2a userdebug
mka bacon
```

---

## 🔧 Build Host ARM64

Project ini membutuhkan patch khusus untuk build di host ARM64 karena manifest PixelOS tidak menyertakan prebuilt untuk `linux-arm64`:

- **ARM64 clang** - di-clone dari `mirror-goog-main-prebuilts`
- **ARM64 Rust** - di-download langsung dari rust-lang.org
- **ARM64 Go** - versi 1.23.4 dengan std lib terkompilasi

Lihat detail di [`patches/arm64-host/README.md`](patches/arm64-host/README.md).

---

## ⚡ Flash

### Prosedur (terbukti berhasil)

```bash
adb reboot fastboot
fastboot flash system      <system.img>
fastboot flash system_ext  <system_ext.img>
fastboot flash product     <product.img>
fastboot --disable-verity --disable-verification flash vbmeta <vbmeta.img>
fastboot reboot
```

### Yang Tidak Boleh Diflash

❌ **Jangan flash `super.img`** - vendor.img hasil rebuild tidak valid  
❌ `boot`, `vendor_boot`, `init_boot`, `dtbo`, `vendor`, `odm`, `*_dlkm` tetap stok

Lihat panduan lengkap di [`docs/FLASHING.md`](docs/FLASHING.md).

---

## 📚 Dokumentasi

| File | Deskripsi |
|------|-----------|
| `README.md` | Panduan utama project |
| `docs/STATUS.md` | Progress build dan riwayat |
| `docs/FLASHING.md` | Panduan flash ROM |
| `docs/FINDINGS-HDD.md` | Temuan dari dump firmware |
| `patches/arm64-host/` | Patch build host ARM64 |
| `CHANGELOG` | Riwayat perubahan |

---

## 🐛 Laporkan Bug

Gunakan [Issue Template](.github/ISSUE_TEMPLATE/bug_report.md) dengan:

1. Build number (misal: run #124)
2. Log build error
3. Output `git log --oneline -10`
4. `lunch` target yang dipakai

---

## 📄 Lisensi

- **Kode proyek**: [Apache License 2.0](LICENSE)
- **Blob vendor**: Proprietary (Transsion/MediaTek) - tidak termasuk di Apache-2.0

---

## 🙏 Kredit

- **[AOSP](https://source.android.com)**
- **[PixelOS](https://github.com/PixelOS-AOSP)**
- **[LineageOS](https://github.com/LineageOS)**
- **rama-firmware-dumps** - referensi device kembar X6728
- **[Building AOSP on ARM64](https://actinis.io/blog/building-aosp-on-arm64)** - referensi patch build host ARM64