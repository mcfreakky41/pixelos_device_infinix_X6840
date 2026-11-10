# PixelOS Device Tree untuk Infinix Smart 20 (X6840 / X6840B)

[![Build](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions/workflows/build.yml/badge.svg)](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Android-16%20(PixelOS%20sixteen)-3ddc84.svg)](https://github.com/PixelOS-AOSP)
[![Device](https://img.shields.io/badge/device-Infinix%20X6840-orange.svg)](#️-perangkat)

---

## 🏷️ Tagline

**_Android 16 (API 36) ROM build untuk Infinix Smart 20 X6840 dengan MediaTek Helio G81 Ultimate_**

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

> **Catatan penting:** Vendor blobs hanya untuk referensi. Saat flash, gunakan device tree yang sudah diperbaiki sehingga fstab dan AVB flags tetap konsisten.

---

## 📂 Struktur Repositori

```
device/infinix/X6840/        # Device tree utama
├── AndroidProducts.mk       # Product makefiles
├── BoardConfig.mk           # Board configuration
├── device.mk                # Device-specific product configuration
├── pixelos_X6840.mk         # Main product makefile
├── vendorsetup.sh           # Lunch combo setup
├── prebuilt/                # Prebuilt kernel (Image)
├── rootdir/                 # Root filesystems, fstab
│   └── etc/fstab.mt6768     # Filesystem table (custom AVB fixes)
├── sepolicy/                # SELinux policies
│   └── vendor/mtk.te        # MediaTek vendor SELinux
vendor/infinix/X6840/        # Vendor tree
├── X6840-vendor.mk          # Vendor product makefile
└── proprietary/             # Symlink placeholder (blobs diunduh terpisah)
patches/arm64-host/          # ARM64 build host patches
├── README.md                # Patch dokumentasi
scripts/                     # Utilitas build
├── apply-arm64-host.sh      # Terapkan patches build host ARM64
├── fetch-blobs.sh           # Fetch vendor blobs
├── check-text-encoding.py   # Validator encoding teks
├── dryrun-arm64-patches.py  # Test patches sebelum apply
└── fix-source-tree.sh       # Perbaiki source tree PixelOS
.github/workflows/           # CI/CD
├── build.yml                # GitHub Actions workflow
└── ISSUE_TEMPLATE/          # Templates laporan bug
docs/                        # Dokumentasi
├── STATUS.md                # Progress build & changelog
├── FLASHING.md              # Panduan flash ROM
└── FINDINGS-HDD.md          # Temuan dari dump firmware
```

> **Catatan:** Blob vendor tidak disimpan di git (ratusan MB). Diunduh otomatis via [Release `blobs-v1`](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/releases/tag/blobs-v1).

---

## 🏗️ Build

### Otomatis (Cara Utama)

Build berjalan di **GitHub Actions** pada runner `ubuntu-24.04-arm`:

```bash
gh workflow run build.yml -R mcfreakky41/pixelos_device_infinix_X6840
```

> **💾 Catatan Disk:** Workflow otomatis membebaskan disk sebelum sync, membuang project x86/emulator/test yang tidak dipakai build ARM64, menghapus `.repo` setelah sync, dan membangun **image-only** (`systemimage systemextimage productimage vbmetaimage`) — bukan `bacon`. Ini mencegah error `No space left on device` pada runner 145 GB. Monitoring di [docs/STATUS.md](docs/STATUS.md).

Atau lewat UI:
1. Buka tab **Actions** → pilih **build.yml**
2. Klik **Run workflow**
3. Pilih `build_type` (userdebug / user / eng)
4. Klik **Run workflow**

### Lokal

```bash
# 1. Sinkron source PixelOS sixteen
mkdir -p ~/android/pixelos && cd ~/android/pixelos
repo init -u https://github.com/PixelOS-AOSP/manifest -b sixteen --depth=1
repo sync -c -j$(nproc --all)

# 2. Tempatkan device tree + vendor tree dari repo ini ke source tree
#    (repo ini BUKAN root source tree; scripts/ ada di root repo ini)
git clone https://github.com/mcfreakky41/pixelos_device_infinix_X6840 /tmp/x6840-tree
mkdir -p device/infinix vendor/infinix
cp -r /tmp/x6840-tree/device/infinix/X6840 device/infinix/X6840
cp -r /tmp/x6840-tree/vendor/infinix/X6840 vendor/infinix/X6840

# 3. Cek anchor patch terhadap checkout ini, lalu terapkan (fail-closed)
python3 /tmp/x6840-tree/scripts/dryrun-arm64-patches.py --root "$PWD"
bash /tmp/x6840-tree/scripts/apply-arm64-host.sh "$PWD"

# 4. Perbaiki source tree (SimpleSettingsConfig, livedisplay, Qualcomm)
bash /tmp/x6840-tree/scripts/fix-source-tree.sh "$PWD"

# 5. Fetch + verifikasi vendor blobs (wajib cocok dengan SHA256SUMS)
bash /tmp/x6840-tree/scripts/fetch-blobs.sh vendor/infinix/X6840/proprietary

# 6. Build (image-only, cukup untuk flashing system/system_ext/product/vbmeta)
source build/envsetup.sh
lunch pixelos_X6840 bp2a userdebug
mka systemimage systemextimage productimage vbmetaimage -j$(nproc --all)
```

> Script mengubah source tree upstream secara langsung. Kalau `repo sync`
> dijalankan ulang, jalankan lagi langkah 3–4 (keduanya idempoten).
> Kalau `dryrun` atau `apply` gagal, **jangan** lanjut build: anchor patch
> berarti berubah dan hasil build tidak bisa dipercaya.

---

## 🔧 Build Host ARM64

Project ini membutuhkan patch khusus untuk build di host ARM64 karena manifest PixelOS tidak menyertakan prebuilt untuk `linux-arm64`:

| Komponen | Sumber |
|----------|--------|
| ARM64 clang | `mirror-goog-main-prebuilts` |
| ARM64 Rust | rust-lang.org (v1.83.0) |
| ARM64 Go | go.dev (v1.23.4) |

Lihat detail di [`patches/arm64-host/README.md`](patches/arm64-host/README.md).

---

## ⚡ Flash

### Prosedur singkat

> **Belum diuji pada perangkat fisik dengan image hasil build ini.** Backup
> dulu (lewat ADB saat Android masih boot), baru masuk fastbootd. Urutan
> lengkap + rollback ada di [`docs/FLASHING.md`](docs/FLASHING.md).

```bash
# Backup dilakukan SEBELUM reboot (lihat docs/FLASHING.md)
adb reboot fastboot
fastboot getvar is-userspace    # harus: yes (fastbootd)

fastboot flash system      <system.img>
fastboot flash system_ext  <system_ext.img>
fastboot flash product     <product.img>
fastboot --disable-verity --disable-verification flash vbmeta <vbmeta.img>
fastboot reboot
```

### Yang Tidak Boleh Diflash

❌ **Jangan flash `super.img`** — build ini tidak membuatnya, dan
`vendor.img` hasil rebuild belum tervalidasi  
❌ `boot`, `vendor_boot`, `init_boot`, `dtbo`, `vendor`, `odm`, `*_dlkm` tetap stok  
❌ `vbmeta_system.img` / `vbmeta_vendor.img` hanya untuk inspeksi pada prosedur
normal (vendor tetap stok)

Lihat panduan lengkap di [`docs/FLASHING.md`](docs/FLASHING.md).

---

## 📚 Dokumentasi

| File | Deskripsi |
|------|-----------|
| `README.md` | Panduan utama project |
| `docs/STATUS.md` | Progress build dan riwayat |
| `docs/FLASHING.md` | Panduan flash ROM lengkap |
| `docs/FINDINGS-HDD.md` | Temuan teknis dari dump firmware |
| `patches/arm64-host/` | Patch build host ARM64 |

---

## 🐛 Laporkan Bug

Gunakan [Issue Template](.github/ISSUE_TEMPLATE/bug_report.yml) dengan:

1. Build number (misal: run #124)
2. Log build error
3. Output `git log --oneline -10`
4. `lunch` target yang dipakai

---

## 📄 Lisensi

- **Kode proyek:** [Apache License 2.0](LICENSE)
- **Blob vendor:** Proprietary (Transsion/MediaTek) - tidak termasuk di Apache-2.0

---

## 🙏 Kredit

- **[AOSP](https://source.android.com)**
- **[PixelOS](https://github.com/PixelOS-AOSP)**
- **[LineageOS](https://github.com/LineageOS)**
- **rama-firmware-dumps** - referensi device kembar X6728
- **[Building AOSP on ARM64](https://actinis.io/blog/building-aosp-on-arm64)** - referensi patch build host ARM64