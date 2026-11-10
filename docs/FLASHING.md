# Panduan Flash — PixelOS untuk Infinix Smart 20 (X6840)

> **Status dokumen:** prosedur ini sudah diperbaiki setelah audit, tetapi
> **belum diuji pada perangkat fisik dengan image hasil build ini**. Bagian
> yang belum terbukti ditandai jelas. Jangan pakai di perangkat utama sebelum
> rollback benar-benar tersedia.

---

## 📋 Apa yang Di-flash?

Build menghasilkan image **image-only** (bukan `super.img`, bukan ZIP OTA):

| Partisi | Aksi | Catatan |
|---------|------|---------|
| `system` | ✅ flash | Target ROM |
| `system_ext` | ✅ flash | Target ROM |
| `product` | ✅ flash | Target ROM |
| `vbmeta` | ✅ flash dengan `--disable-verity --disable-verification` | Build memakai AOSP test key (bukan release key OEM) |
| `vbmeta_system`, `vbmeta_vendor` | ⚠️ **jangan flash** untuk pemakaian normal | Hanya untuk inspeksi/analisis. Lihat bagian AVB. |
| `boot`, `init_boot`, `vendor_boot`, `dtbo` | ❌ jangan flash | Format MTK kustom / masih stok |
| `vendor`, `odm` | ❌ jangan flash | Tetap stok (lihat bagian "Mengapa vendor/odm stok") |
| `vendor_dlkm`, `odm_dlkm`, `system_dlkm` | ❌ jangan flash | Modul kernel stok |
| `super` | ❌ jangan flash | `super.img` tidak dibuat; README melarang flash `super.img` |

> **Ringkas:** `system`, `system_ext`, `product`, lalu `vbmeta`.
> `vbmeta*.img` lain di artifact hanya untuk pemeriksaan, bukan untuk flashing
> rutin.

---

## ⚙️ Mengapa `boot` / `vendor_boot` Tidak Di-rebuild?

### `boot_a_fresh.img` (stok)

| Field | Nilai |
|-------|-------|
| `kernel_addr` | `0x0` |
| `page_size` | `0x0` |
| cmdline | *(kosong)* |
| payload | Offset `0x1000` (kernel gzip ±14 MB) |

### `vendor_boot_a.img` (stok)

- Magic: `VNDRBOOT`
- Header version `4`, `page_size` `4096`
- Kernel: `0x40080000`, Ramdisk: `0x47c80000`
- **Cmdline di offset 28** (AOSP standar: offset 52)

**Akibat:** `mkbootimg` AOSP tidak bisa meregenerasi layout MTK khusus ini
tanpa penyesuaian. Karena itu kernel/boot tetap stok dan build hanya mengganti
partisi logis di dalam `super`.

---

## 🔐 Mengapa `vendor` / `odm` Tetap Stok

Penjelasan lama di dokumen ini ("`adb pull` menghilangkan extended attribute
sehingga SELinux context hilang") **tidak tepat**. Image builder AOSP menerima
`file_contexts` lewat parameter `fc_config` dan memakainya saat membuat
filesystem ext4 (`mkuserimg_mke2fs`), jadi label SELinux **tidak** bergantung
pada xattr yang terbawa `adb pull`.

Alasan yang sebenarnya untuk port ini:

1. Vendor image stok berisi policy SELinux vendor, HAL MediaTek, dan blob yang
   belum divalidasi ulang sebagai satu kesatuan.
2. Rebuild `vendor`/`odm` dari blob stok belum diuji: bisa muncul AVC denial,
   HAL gagal start, atau mismatch VNDK.
3. Yang ingin dicapai tahap ini adalah membuktikan **system side** (framework
   Android 16) bisa boot di atas vendor Android 15 yang utuh.

Kalau nanti `vendor` mau di-flash, yang wajib diuji bukan xattr, melainkan:

- apakah `file_contexts` mencakup semua path yang dipakai vendor,
- apakah label hasil image benar (`sepolicy-analyze`, `ls -Z` di device),
- apakah policy vendor dan system saling kompatibel (tidak ada neverallow),
- apakah init dan HAL berjalan tanpa AVC denial yang menghalangi fungsi utama.

---

## 📱 API: System 36 vs Vendor 35

Spesifikasi vendor stok:

```
ro.vendor.build.version.sdk=35
ro.vendor.build.version.release=15
ro.board.api_level=202404
ro.product.first_api_level=36
```

Pemeriksaan `system-sdk`:

- Vendor meminta: `{35}`
- Framework A16 menyediakan: `{34, 35, 36}`
- `{35} ⊆ {34,35,36}` → **cocok pada nilai system-sdk**

> **Penting:** ini **bukan** bukti kompatibilitas VINTF penuh. Pemeriksaan VINTF
> mencakup dua arah (framework compatibility matrix vs device manifest, dan
> framework manifest vs device compatibility matrix) plus versi FCM/HAL.
> Kecocokan penuh belum dibuktikan di repo ini; lihat
> [FINDINGS-HDD.md](FINDINGS-HDD.md).

Bukti yang ada: GSI Android 16 (AxionOS 2.8) pernah boot di perangkat ini.
Itu bukti system-side A16 bisa jalan dengan vendor 35, bukan bukti build ini
sudah benar.

---

## 🔧 Langkah Flash

### 0. Prasyarat

- Bootloader sudah **unlocked** (`ro.boot.verifiedbootstate=orange`).
- `platform-tools` (adb + fastboot) versi terbaru.
- Battery > 50%.
- **Backup sudah dibuat** (langkah 1) dan disalin ke komputer lain.
- Ketahui slot aktif: hampir semua operasi di bawah memakai slot `a` pada
  perangkat ini, tetapi verifikasi dulu.

### 1. Backup — dilakukan saat Android masih BOOT (bukan di fastboot)

> Urutan ini penting. Perintah `adb` **tidak tersedia** saat perangkat sudah
> berada di fastboot/fastbootd. Backup dulu, baru reboot ke fastboot.

Perangkat stok pada dump ini sudah ter-root (Magisk), sehingga `su` tersedia.
Kalau perangkat tidak root, backup lewat `adb` tidak bisa; gunakan recovery
khusus atau dump firmware stok sebelum lanjut.

```bash
# Pastikan perangkat boot normal dan terdeteksi
adb devices
adb shell getprop ro.boot.slot_suffix      # mis. _a
adb shell su -c 'ls -l /dev/block/mapper/' # pastikan partisi ada

# Siapkan folder backup
mkdir -p backup-x6840

# Backup SEMUA partisi yang nanti di-flash (system, system_ext, product,
# vbmeta, vbmeta_system, vbmeta_vendor) + partisi kunci lain.
# Ganti _a sesuai slot aktif.
for p in system system_ext product vbmeta vbmeta_system vbmeta_vendor; do
  echo ">>> backup $p"
  adb shell su -c "dd if=/dev/block/mapper/${p}_a of=/sdcard/backup-${p}.img bs=4M"
  adb pull "/sdcard/backup-${p}.img" "./backup-x6840/backup-${p}.img"
  adb shell rm -f "/sdcard/backup-${p}.img"
done

# Partisi non-logis yang sebaiknya ikut disimpan (bukan untuk di-flash,
# tetapi penting kalau perlu pemulihan penuh).
for p in boot init_boot vendor_boot dtbo; do
  adb shell su -c "dd if=/dev/block/by-name/${p}_a of=/sdcard/backup-${p}.img bs=4M"
  adb pull "/sdcard/backup-${p}.img" "./backup-x6840/backup-${p}.img"
  adb shell rm -f "/sdcard/backup-${p}.img"
done

ls -lh backup-x6840/
sha256sum backup-x6840/*.img > backup-x6840/SHA256SUMS
```

Catatan:

- `dd` dari partisi yang sedang di-mount bisa menghasilkan snapshot yang tidak
  konsisten. Untuk rollback yang benar-benar bersih, cara paling aman adalah
  dump firmware stok lengkap dengan tool MTK/recovery sebelum mencoba build ini.
- Jangan lanjut kalau ukuran file backup `0` atau `adb pull` gagal.
- Salin folder `backup-x6840/` ke komputer/HDD lain.

### 2. Masuk ke fastbootd (userspace fastboot)

Partisi `system`, `system_ext`, dan `product` adalah **logical partition** di
dalam `super`. Flashing-nya harus lewat **fastbootd**, bukan bootloader
fastboot biasa.

```bash
adb reboot fastboot

# Tunggu, lalu verifikasi:
fastboot devices
fastboot getvar is-userspace     # harus: yes
fastboot getvar current-slot
```

Kalau `is-userspace` bukan `yes`, jangan lanjut — `fastboot flash system`
akan gagal atau salah target.

### 3. Flash ROM

```bash
fastboot flash system      system.img
fastboot flash system_ext  system_ext.img
fastboot flash product     product.img

# vbmeta top-level dari build, dengan verity/verification dimatikan.
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img

fastboot reboot
```

**Jangan** flash `vbmeta_system.img` / `vbmeta_vendor.img` pada prosedur
normal: `vendor`, `odm`, dan `*_dlkm` tetap stok, sehingga chain vendor stok
lebih konsisten dibanding vbmeta hasil build. Kalau ingin menganalisisnya,
baca bagian AVB di bawah.

### 4. Reset data (hanya jika perlu)

Ganti ROM dari stok ke PixelOS biasanya butuh data bersih karena perbedaan
enkripsi/keystore. **Perintah ini menghapus SEMUA data pengguna** (foto,
aplikasi, akun, dsb). Pastikan backup sudah benar.

```bash
# HAPUS SEMUA DATA PENGGUNA — tidak bisa dibatalkan
fastboot erase userdata
fastboot erase metadata        # opsional, ikut membersihkan metadata enkripsi
fastboot reboot
```

Coba boot tanpa `erase userdata` dulu. Kalau bootloop karena kunci enkripsi
tidak cocok, baru lakukan penghapusan data.

### 5. Boot pertama

- Boot pertama bisa 5–15 menit (dex2oat).
- Kalau berhenti di logo, ambil log:
  ```bash
  adb logcat -d > logcat-boot.txt
  adb shell dmesg > dmesg-boot.txt
  ```
- Jangan langsung menyimpulkan "ROM gagal" sebelum melihat log.

---

## ↩️ Rollback

Kalau build bermasalah, kembali ke stok memakai backup dari langkah 1.
Semua perintah dijalankan di **fastbootd** (kecuali disebut lain).

```bash
fastboot getvar is-userspace    # harus yes

fastboot flash system      backup-x6840/backup-system.img
fastboot flash system_ext  backup-x6840/backup-system_ext.img
fastboot flash product     backup-x6840/backup-product.img

# Kembalikan vbmeta stok (verifikasi ikut kembali seperti semula)
fastboot flash vbmeta         backup-x6840/backup-vbmeta.img
fastboot flash vbmeta_system  backup-x6840/backup-vbmeta_system.img
fastboot flash vbmeta_vendor  backup-x6840/backup-vbmeta_vendor.img

fastboot reboot
```

Kalau data sudah terhapus dan ingin kembali persis seperti stok, flash firmware
stok lengkap dengan tool resmi MTK. Backup partisi di atas tidak memulihkan
data pengguna.

---

## 🔏 AVB: apa yang build ini lakukan

- `BoardConfig.mk` memakai **AOSP test key**
  (`external/avb/test/data/testkey_rsa2048.pem`). Ini **bukan** release key
  OEM, jadi build ini bukan build produksi dan tidak untuk verified boot
  terkunci.
- `BOARD_AVB_VBMETA_SYSTEM := system system_ext product system_dlkm`.
  `system_dlkm` dimasukkan karena `fstab.mt6768` di device tree memakai
  `avb=vbmeta_system` untuk partisi itu.
- `tr_manifest` **tidak** memakai `avb=` dan diberi `nofail`, karena image-nya
  berasal dari stok dan tidak dibangun ulang (tidak punya descriptor di
  vbmeta hasil build).
- `vbmeta.img` di-flash dengan `--disable-verity --disable-verification`
  karena signature-nya beda dari stok dan sebagian partisi (vendor/dlkm) tetap
  stok.
- **fstab di device tree hanya berlaku kalau `vendor.img` ikut di-flash.**
  Pada prosedur normal, `vendor` tetap stok, sehingga fstab yang dipakai
  perangkat adalah fstab stok. Perubahan fstab di repo ini penting untuk
  skenario rebuild vendor, bukan untuk flash system-only.

Untuk memeriksa isi vbmeta hasil build (opsional):

```bash
python3 external/avb/avbtool info_image --image vbmeta.img
python3 external/avb/avbtool info_image --image vbmeta_system.img
python3 external/avb/avbtool info_image --image vbmeta_vendor.img
```

Cocokkan daftar `Partition Name` dengan flag `avb=` di fstab **jika** vendor
ikut di-flash. Jangan menganggap semua `vbmeta*.img` otomatis cocok hanya
karena build selesai.

---

## 📋 Checklist Sebelum Flash

- [ ] Bootloader unlocked dan `fastboot devices` terdeteksi
- [ ] Backup `system`, `system_ext`, `product`, `vbmeta`,
      `vbmeta_system`, `vbmeta_vendor` ada dan ukurannya wajar
- [ ] `SHA256SUMS` backup dibuat dan disalin ke komputer lain
- [ ] `fastboot getvar is-userspace` → `yes` (fastbootd)
- [ ] `fastboot getvar current-slot` sesuai dengan backup (`_a`/`_b`)
- [ ] Image build ada dan tidak kosong (`system.img`, `system_ext.img`,
      `product.img`, `vbmeta.img`)
- [ ] `vbmeta.img` di-flash dengan `--disable-verity --disable-verification`
- [ ] Tahu bahwa `fastboot erase userdata` menghapus semua data
- [ ] **Tidak** mem-flash `super.img`, `boot.img`, `vendor_boot.img`,
      `init_boot.img`, `dtbo.img`, `vendor.img`, `odm.img`, `*_dlkm.img`

---

## 📚 Referensi

- [docs/FINDINGS-HDD.md](FINDINGS-HDD.md) — temuan dari dump firmware
- [docs/STATUS.md](STATUS.md) — status build dan batas pengujian
- [README.md](../README.md) — build lokal dan CI
