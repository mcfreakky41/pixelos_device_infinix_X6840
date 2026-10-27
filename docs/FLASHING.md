# Panduan Flash — PixelOS untuk Infinix Smart 20 (X6840)

Dokumen ini menjelaskan **bagaimana ROM PixelOS yang dibangun dari device tree ini
di-flash ke perangkat**, dan **mengapa sebagian partisi harus tetap stok**.

Semua isi dokumen ini berasal dari pengukuran langsung pada perangkat dan dari
sumber AOSP/PixelOS yang dirujuk pada bagian yang relevan — bukan dari
perkiraan.

---

## 1. Ringkasan: apa yang diganti, apa yang tetap

| Partisi | Aksi | Alasan |
|---|---|---|
| `system` | **flash** (ext4) | target ROM |
| `system_ext` | **flash** (ext4) | target ROM |
| `product` | **flash** (ext4) | target ROM |
| `vbmeta` | **flash** dengan `--disable-verity --disable-verification` | device sudah unlocked; AVB harus tidak menolak image baru |
| `boot` | **jangan** | berisi kernel prebuilt + ramdisk; format non-generik |
| `vendor_boot` | **jangan** | format MTK kustom (lihat §2) — `mkbootimg` AOSP tidak bisa mereproduksinya |
| `init_boot` | **jangan** | vendor ramdisk stok |
| `dtbo` | **jangan** | device tree overlay stok |
| `vendor` | **jangan** | blob vendor kehilangan konteks SELinux saat diekstraksi (lihat §3) |
| `odm` | **jangan** | idem |
| `vendor_dlkm`, `odm_dlkm`, `system_dlkm` | **jangan** | modul kernel stok (kernel 6.6.89-android15-8) |
| `super` | **jangan** | berisi `vendor.img` hasil rebuild yang tidak valid; flashing super akan menimpa partisi stok yang justru dibutuhkan |

> **Penting:** `super.img` yang dihasilkan build **tidak boleh** di-flash.
> Image `vendor` di dalamnya dibangun ulang dari blob yang diekstraksi tanpa
> metadata SELinux, sehingga tidak valid untuk ini.

---

## 2. Kenapa `boot` / `vendor_boot` tidak boleh di-rebuild

Hasil pengukuran header image stok (`E:\PixelOS-X6840\dumps\boot-parts-fresh\`):

### `boot_a_fresh.img`

| Field | Nilai |
|---|---|
| `kernel_addr` | `0x0` |
| `page_size` | `0x0` |
| cmdline | *(kosong)* |
| payload | mulai di offset `0x1000` (gzip kernel, 14 554 925 byte) |

### `vendor_boot_a.img`

Magic `VNDRBOOT` — **bukan** header `VNDRBOOT` standar AOSP (yang memakai
`ANDROID!` + header v3). Header_version `4`, `page_size` `4096`,
`kernel_addr` `0x40080000`, `ramdisk_addr` `0x47c80000`,
`vendor_ramdisk_size` `0x01ba8023`, dan **cmdline berada di offset 28**
(standar AOSP: offset 52).

Konsekuensi:

* `mkbootimg` AOSP tidak bisa menulis cmdline ke offset 28 → `vendor_boot.img`
  hasil build akan **berbeda** dari stok dan risiko boot gagal.
* Image `boot.img` di perangkat ini **tidak** memuat kernel_addr/page_size/
  cmdline; semuanya ada di `vendor_boot.img`.

Karena itu device tree dikonfigurasi agar `boot.img` dibangun **tanpa**
`--cmdline/--base/--pagesize` (persis seperti stok), sementara nilai base dan
pagesize dikirim ke `vendor_boot.img`:

```makefile
BOARD_KERNEL_BASE := 0x40080000      # dari header vendor_boot_a.img
BOARD_KERNEL_PAGESIZE := 4096         # dari header vendor_boot_a.img
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_USES_GENERIC_KERNEL_IMAGE := true
```

`BOARD_USES_GENERIC_KERNEL_IMAGE := true` dipakai dengan sengaja: perangkat
ini punya `vendor_boot` (vendor ramdisk), sehingga generic ramdisk (`init_boot`)
harus memuat `first_stage_ramdisk/`
(`build/make/core/Makefile:1208`). Efek sampingnya persis yang kita mau:
`boot.img` tidak diberi `--cmdline/--base/--pagesize`.

---

## 3. Kenapa `vendor` / `odm` harus tetap stok

Blob vendor diambil dari perangkat yang sudah ter-*mount* dengan cara
`cp -r` + `adb pull`. `adb pull` **tidak** membawa extended attribute, sehingga
**konteks SELinux tiap file hilang**. Membangun ulang `vendor.img` dari blob
itu menghasilkan partisi tanpa label yang benar → `init` akan menolak
meng-*mount* `/vendor`.

Akibatnya:

* `vendor.img` hasil build **tidak dipakai**;
* `vendor`/`odm` stok **dipertahankan** apa adanya;
* modul kernel (`vendor_dlkm`, `odm_dlkm`) juga tetap stok, karena kernel
  yang dipakai adalah kernel stok 6.6.89.

> Alternatif (menarik `vendor.img` mentah sebagai *prebuilt*) ruled out karena
> ukurannya ~409 MB dan tidak ada mekanisme AOSP standar untuk menyisipkan
> image partisi vendor hasil build mentah.

---

## 4. Level API: system 36 vs vendor 35

Partisi `vendor`/`odm` stok adalah **Android 15 (API 35)**:

```
ro.vendor.build.version.sdk=35
ro.vendor.build.version.release=15
ro.board.api_level=202404          # level API vendor format baru (V)
ro.board.first_api_level=30
ro.product.first_api_level=36
ro.vendor.build.fingerprint=transsion/tssi/tssi:15/AP3A.240905.015.A2/101500043:user/release-keys
```

ROM ini adalah **Android 16 (API 36)**. Kombinasi ini memang dipakai oleh
OEM (system A16 + vendor A15) dan **sudah terbukti boot** di perangkat ini
(GSI Android 16 booting di X6840, slot `_a`, boot completed ~105 detik).

`init` menghitung `ro.vendor.api_level` sebagai nilai minimum antara level API
produk dan `ro.board.api_level`
(`system/core/init/property_service.cpp:1108`), sehingga hasilnya `202404`
(A15) — sama seperti perangkat stok. **Tidak ada `LOG(FATAL)` di sana**;
`ro.vendor.api_level` hanya informatif.

Sisi build: `checkvintf --check-compat` dijalankan dengan
`--property ro.product.first_api_level=36`
(`build/make/core/Makefile:5500`). Kompatibilitas matrix vendor mendeklarasikan
`system-sdk {35}`, sedangkan `BOARD_SYSTEMSDK_VERSIONS := 36 35 34` —
kompatibel.

---

## 5. Langkah flash

### 5.1 Prasyarat

* Device dalam **fastboot mode**: `adb reboot fastboot`
* `fastboot` versi 1.0.41+ (Android platform-tools terbaru)
* File hasil build: `system.img`, `system_ext.img`, `product.img`, `vbmeta.img`
  (semua ada di `out/target/product/X6840/` dan juga di artifact **Upload ROM**
  pada GitHub Actions run terkait)

### 5.2 Backup (sangat disarankan, **sebelum** flash)

`super.img` stok sudah dicadangkan lokal, tetapi formatnya tidak bisa di-unpack
(header `gDla`), sehingga **tidak bisa dipakai sebagai jalur rollback** dengan
tool `lpunpack`. Cadangkan **semua partisi yang akan ditimpa**: `system`,
`system_ext`, `product` (partisi logical) dan `vbmeta` (partisi fisik).
Mengembalikan hanya `system` sementara `system_ext`/`vbmeta` tetap versi ROM
baru bisa membuat perangkat bootloop.

Partisi logical (dynamic partition di dalam `super`) TIDAK ada di
`/dev/block/by-name/` — yang ada di sana hanya `super`. Akses lewat device
mapper (nama bisa `system_a` atau `system`; cek dulu):

```bash
adb shell su -c "ls -l /dev/block/mapper/"
SLOT=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')    # mis. _a
for p in system system_ext product; do
  # pakai nama yang ada di /dev/block/mapper/ (dengan atau tanpa suffix slot)
  adb shell su -c "dd if=/dev/block/mapper/${p}${SLOT} of=/data/local/tmp/${p}.img bs=4M"
  adb shell su -c "ls -l /data/local/tmp/${p}.img"          # pastikan ukurannya wajar
  adb pull /data/local/tmp/${p}.img ./backup-${p}.img
  adb shell su -c "rm /data/local/tmp/${p}.img"
done
adb shell su -c "dd if=/dev/block/by-name/vbmeta${SLOT} of=/data/local/tmp/vbmeta.img"
adb pull /data/local/tmp/vbmeta.img ./backup-vbmeta.img
adb shell su -c "rm /data/local/tmp/vbmeta.img"
```

Jika `/dev/block/mapper/<nama>` tidak ada, alternatifnya cadangkan seluruh
`super` (ukurannya besar, tapi pasti ada):

```bash
adb shell su -c "dd if=/dev/block/by-name/super of=/data/local/tmp/super.img bs=4M"
```

> Slot `_b` **tidak** boleh diandalkan sebagai jalur rollback: tabel `lpdump`
> di `docs/FINDINGS-HDD.md` hanya memuat partisi slot `_a`, jadi belum ada bukti
> `_b` berisi sistem stok yang utuh.

### 5.3 Flash

```bash
fastboot flash system      system.img
fastboot flash system_ext  system_ext.img
fastboot flash product     product.img
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
```

Lalu (hanya bila diperlukan, mis. setelah ganti ROM atau error lain):

```bash
fastboot erase userdata
fastboot reboot
```

> `fastboot erase cache` **tidak** tersedia di perangkat ini
> ("Partition doesn't exist") — tidak masalah.

Helper otomatis: skrip `flash-rom.ps1` lokal (tidak ada di repo publik ini)
menjalankan urutan di atas.

---

## 6. Rollback

1. **Pulihkan semua partisi yang ditimpa** dari backup §5.2 (fastbootd):
   ```bash
   fastboot flash system      backup-system.img
   fastboot flash system_ext  backup-system_ext.img
   fastboot flash product     backup-product.img
   fastboot --disable-verity --disable-verification flash vbmeta backup-vbmeta.img
   ```
   (bila `backup-vbmeta.img` memuat flag verifikasi aktif, flash tanpa flag
   `--disable-*` agar sama dengan stok).
2. Semua image `boot`/`vendor_boot`/`init_boot`/`vendor`/`odm`/`*_dlkm` **tidak
   pernah diubah**, jadi selalu dalam kondisi baik.
3. `fastboot set-active b` hanya berguna bila slot `_b` terbukti berisi sistem
   stok (belum terbukti, lihat catatan §5.2) — jangan dijadikan satu-satunya
   jalur rollback.

---

## 7. Daftar periksa sebelum flash

- [ ] `fastboot getvar current-slot` → pastikan slot yang dituju
- [ ] `fastboot getvar is-userspace` → `yes` (butuh fastbootd untuk partisi dinamis)
- [ ] Ukuran image hasil build muat di partisi logical device (fastbootd mengubah
      ukuran otomatis; pastikan `super` punya ruang cukup)
- [ ] Backup `system`, `system_ext`, `product`, dan `vbmeta` sudah diambil dan ukurannya wajar
- [ ] `vbmeta.img` flashed **dengan** `--disable-verity --disable-verification`
- [ ] **Jangan** flash `super.img`
