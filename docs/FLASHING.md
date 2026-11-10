# Panduan Flash — PixelOS untuk Infinix Smart 20 (X6840)

> **Dokumen teknis lengkap** — Semua isi berasal dari pengukuran langsung pada perangkat dan sumber AOSP/PixelOS.

---

## 📋 Ringkasan: Partisi Apa yang Diubah?

| Partisi | Aksi | Alasan |
|---------|------|--------|
| `system` | ✅ **FLASH** (ext4) | Target ROM |
| `system_ext` | ✅ **FLASH** (ext4) | Target ROM |
| `product` | ✅ **FLASH** (ext4) | Target ROM |
| `vbmeta` | ✅ **FLASH** (`--disable-verity --disable-verification`) | Device sudah unlocked |
| `boot` | ❌ **JANGAN FLASH** | Format non-generik |
| `vendor_boot` | ❌ **JANGAN FLASH** | Format MTK kustom |
| `init_boot` | ❌ **JANGAN FLASH** | Vendor ramdisk stok |
| `dtbo` | ❌ **JANGAN FLASH** | Device tree overlay stok |
| `vendor` | ❌ **JANGAN FLASH** | Blob hilang SELinux konteks |
| `odm` | ❌ **JANGAN FLASH** | Sama seperti vendor |
| `vendor_dlkm`, `odm_dlkm`, `system_dlkm` | ❌ **JANGAN FLASH** | Modul kernel stok |
| `super` | ❌ **JANGAN FLASH** | `vendor.img` hasil rebuild tidak valid |

> **Penting:** Flash hanya: `system`, `system_ext`, `product`, `vbmeta*.img`

---

## ⚙️ Mengapa `boot` / `vendor_boot` Tidak Boleh Di-Rebuild?

### `boot_a_fresh.img`
| Field | Nilai |
|-------|-------|
| `kernel_addr` | `0x0` |
| `page_size` | `0x0` |
| cmdline | *(kosong)* |
| payload | Offset `0x1000` (kernel gzip 14 MB) |

### `vendor_boot_a.img`
- Magic: `VNDRBOOT` (bukan AOSP standar)
- Header version: `4`, page_size: `4096`
- Kernel: `0x40080000`, Ramdisk: `0x47c80000`
- **Cmdline di offset 28** (standar AOSP: offset 52)

**Akibat:** `mkbootimg` AOSP tidak bisa meregenerasi format MTK khusus ini.

---

## 🔐 Mengapa `vendor` / `odm` Harus Tetap Stok

`adb pull` tidak membawa extended attributes → **konteks SELinux hilang**.

Rebuild `vendor.img` menghasilkan partisi tanpa label yang benar → `init` menolak mount.

### Solusi
- `vendor.img` hasil build **tidak dipakai**
- Semua blob vendor tetap stok
- Kernel 6.6.89-stok tetap dipakai

---

## 📱 Level API: System 36 vs Vendor 35

### Spesifikasi Vendor Stok
```
ro.vendor.build.version.sdk=35
ro.vendor.build.version.release=15
ro.board.api_level=202404
ro.product.first_api_level=36
```

### Kompatibilitas ✅
- Vendor membutuhkan: `system-sdk {35}`
- System A16 menyediakan: `{34, 35, 36}`
- `{35} ⊆ {34,35,36}` = **MATCH**

> **Android 16 GSI (AxionOS 2.8) sudah terbukti BOOT** di device ini.

---

## 🔧 Langkah Flash

### 1. Prasyarat
- Device dalam **fastboot mode** (`adb reboot fastboot`)
- `fastboot` versi 1.0.41+
- File build: `system.img`, `system_ext.img`, `product.img`, `vbmeta.img`

### 2. Backup (WAJIB!)

```bash
# Periksa slot aktif
fastboot getvar current-slot
fastboot getvar is-userspace

# Backup partisi logic
adb shell su -c "dd if=/dev/block/mapper/system_a of=/sdcard/system.img bs=4M"
adb pull /sdcard/system.img ./backup-system.img
```

### 3. Flash ROM

```bash
fastboot flash system      system.img
fastboot flash system_ext  system_ext.img
fastboot flash product     product.img
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot reboot
```

### 4. Reset Jika Perlu

```bash
fastboot erase userdata
fastboot reboot
```

---

## ↩️ Rollback

Jika build bermasalah:

```bash
fastboot flash system      backup-system.img
fastboot flash system_ext  backup-system_ext.img
fastboot flash product     backup-product.img
fastboot --disable-verity --disable-verification flash vbmeta backup-vbmeta.img
```

> Semua image `boot`, `vendor_boot`, `init_boot`, `vendor`, `odm`, `*_dlkm` tetap stok — tidak perlu di-flash kembali.

---

## 📋 Checklists Sebelum Flash

- [ ] `fastboot getvar is-userspace` → `yes`
- [ ] Backup `system`, `system_ext`, `product`, `vbmeta` sudah ada
- [ ] File image cukup besar (muat di partisi)
- [ ] `vbmeta.img` flashed dengan `--disable-verity --disable-verification`
- [ ] **Jangan** flash `super.img`

---

## 📚 Referensi Tambahan

- [docs/FINDINGS-HDD.md](FINDINGS-HDD.md) — Temuan teknis dari dump firmware
- [docs/STATUS.md](STATUS.md) — Progress build dan changelog