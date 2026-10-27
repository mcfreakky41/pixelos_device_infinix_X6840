# PixelOS untuk Infinix Smart 20 (X6840)

[![Build](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions/workflows/build.yml/badge.svg)](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Android-16%20(PixelOS%20sixteen)-3ddc84.svg)](https://github.com/PixelOS-AOSP)
[![Device](https://img.shields.io/badge/device-Infinix%20X6840-orange.svg)](#perangkat)

Device tree **device-specific** untuk **Infinix Smart 20 (X6840 / X6840B)**, dibangun dari nol - bukan GSI.

> **Status: Work In Progress** | Target: **PixelOS sixteen (Android 16)** | Build terkini: **run #70** (berjalan) | Lihat [`docs/STATUS.md`](docs/STATUS.md) untuk progres & riwayat lengkap.

---

## Perangkat

| | |
|---|---|
| Model | Infinix Smart 20 (X6840 / X6840B) |
| SoC | MediaTek Helio G81 Ultimate (**mt6768**) |
| Kernel | 6.6.x (prebuilt dari dump stok) |
| Target Android | **16** (PixelOS `sixteen`) |
| Arsitektur | arm64-v8a saja (tanpa 32-bit) |
| Partisi | A/B + dynamic (`super`) + `vendor_boot` |
| Codename vendor | `tssi` |
| Fingerprint stok | `Infinix/X6840-OP/Infinix-X6840:16/BP2A.250605.031.A3/301400019:user/release-keys` |

---

## Struktur repositori

```
device/infinix/X6840/     Device tree (BoardConfig, device.mk, rootdir, sepolicy, prebuilt kernel)
vendor/infinix/X6840/     Vendor tree (kosong di git - blob ada di Release)
patches/arm64-host/       Patch build host ARM64 + dokumentasinya
scripts/                  Skrip bantu (patch, build, monitoring)
.github/workflows/        CI build (GitHub Actions)
docs/                     STATUS.md, temuan, catatan
```

> **Blob vendor tidak disimpan di git.** Ukurannya ratusan MB, jadi dititipkan di [Release `blobs-v1`](https://github.com/mcfreakky41/pixelos_device_infinix_X6840/releases/tag/blobs-v1) dan diambil otomatis oleh workflow.

---

## Build

### Otomatis (cara utama)

Build berjalan di **GitHub Actions** di runner `ubuntu-24.04-arm` (host ARM64, 108 GB bebas). Trigger hanya manual:

```bash
gh workflow run build.yml -R mcfreakky41/pixelos_device_infinix_X6840
```

atau lewat tab **Actions**  *build*  **Run workflow**.

### Lokal

```bash
# setelah source tersinkron & patch host diterapkan
source build/envsetup.sh
lunch pixelos_X6840 bp2a userdebug
mka bacon
```

> **Catatan penting:** `bp2a` adalah **satu-satunya** release config yang valid di PixelOS (`vendor/aosp/release/release_config_map.mk`). Memakai `trunk_staging` akan memicu `panic: Missing config trunk_staging`.

### Kenapa perlu patch host ARM64?

Manifest PixelOS/LineageOS **tidak mendukung build di host ARM64 sama sekali** - tidak ada cabang `aarch64` di `build/make/core/envsetup.mk`, sehingga di runner ARM64 `HOST_ARCH` kosong dan build gagal:

```
build/make/core/envsetup.mk:195: error: unknown variable: HOST_ARCH
```

Proyek ini menambalnya lewat [`scripts/apply-arm64-host.sh`](scripts/apply-arm64-host.sh) yang dijalankan **setelah sync, sebelum build**. Semua patch, prebuilt yang diperlukan, dan alasannya didokumentasikan di [`patches/arm64-host/README.md`](patches/arm64-host/README.md).

---

## Flash

> Prosedur ini terbukti di perangkat. **Backup dulu**, dan pastikan kamu paham risikonya - mem-flash ROM kustom bisa menyebabkan brick (lihat [NOTICE](NOTICE)). Panduan lengkap: **[`docs/FLASHING.md`](docs/FLASHING.md)**.

Ringkasnya, **hanya 4 partisi** yang diganti:

```bash
adb reboot fastboot
fastboot flash system      <system.img>
fastboot flash system_ext  <system_ext.img>
fastboot flash product     <product.img>
fastboot --disable-verity --disable-verification flash vbmeta <vbmeta.img>
# fastboot erase userdata   # hanya bila perlu
fastboot reboot
```

`boot`, `vendor_boot`, `init_boot`, `dtbo`, `vendor`, `odm`, `vendor_dlkm`, `odm_dlkm`, dan `system_dlkm` **tetap stok** - alasannya (format `vendor_boot` MTK kustom + konteks SELinux blob vendor) diuraikan di [`docs/FLASHING.md`](docs/FLASHING.md).

> **Jangan flash `super.img`.** Isinya `vendor.img` hasil rebuild yang tidak valid (konteks SELinux hilang).

Catatan: `fastboot erase cache` **gagal** di perangkat ini (`Partition doesn't exist`).

---

## Berkontribusi

Kontribusi sangat diterima - perbaikan bug, fitur, maupun dokumentasi.

1. Baca [CONTRIBUTING.md](CONTRIBUTING.md) (alur PR, konvensi commit, aturan blob).
2. Patuhi [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
3. Buka **Issue** lewat template yang tersedia untuk laporan bug / kegagalan build / usulan.
4. Kirim **Pull Request** ke branch `main`.

---

## Lisensi

- **Kode proyek ini** (device tree, skrip, patch, dokumentasi) - [Apache License 2.0](LICENSE).
- **Blob vendor** (Transsion/MediaTek) - **proprietary**, bukan milik proyek ini dan tidak berada di bawah Apache-2.0. Baca [NOTICE](NOTICE) untuk rinciannya.

---

## Kredit

Proyek ini berdiri di atas kerja banyak pihak:

- **[AOSP](https://source.android.com)** - basis platform Android (Apache-2.0)
- **[PixelOS](https://github.com/PixelOS-AOSP)** - proyek ROM yang jadi target (Apache-2.0)
- **[LineageOS](https://github.com/LineageOS)** - referensi device tree & sepolicy (Apache-2.0)
- **rama-firmware-dumps** - referensi device kembar X6728 (Infinix HOT 60i)
- **["Building AOSP on ARM64"](https://actinis.io/blog/building-aosp-on-arm64)** - referensi patch build host ARM64

`Infinix`, `Smart 20`, `MediaTek`, `Helio`, `Android` adalah merek dagang pemiliknya masing-masing; penggunaannya di sini bersifat deskriptif dan tidak menyiratkan afiliasi apa pun.
