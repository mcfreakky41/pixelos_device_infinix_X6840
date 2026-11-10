# Temuan dari Dump Firmware — Infinix Smart 20 (X6840)

**Tanggal:** 2026-10-20  
**Sumber:** Backup HDD eksternal dari flash recovery

---

## 📦 File yang Tersedia

| File | Ukuran | Status |
|------|--------|--------|
| `boot.img` | 64 MB | ✅ Dipakai sebagai referensi |
| `init_boot_stock_16.1.0.140SP09.img` | 8 MB | ✅ Init boot stok |
| `init_boot_magisk_patched_30.7.img` | 8 MB | ✅ Magisk patched |
| `vbmeta.img` | kecil | ✅ Backup penting |
| Kernel extracted | 36,461,056 bytes | ✅ **VALID** (SHA256: AE170319...) |

---

## 🔍 Firmware Stock

- **Build:** `X6840-16.3.0.140SP09(OP004PF001AZ)` (XOS 16.3)
- **Slot aktif:** `a`
- **Boot state:**
  - `ro.boot.verifiedbootstate = orange` (unlocked)
  - Magisk 30.7 aktif

---

## ✅ Bukti GSI Android 16 Berhasil Boot

| ROM | Status | Boot Time |
|-----|--------|-----------|
| **AxionOS 2.8** (`20260930-VANILLA-GSI`) | ✅ BERHASIL | ~105 detik |
| LineageOS 23.2 microG | ✅ (dicoba) | - |
| EvoX 11.11 GSI | ⚠️ Sempet bootloop, lalu berhasil | - |

### Prosedur Flash GSI Terbukti Berhasil
```bash
adb reboot fastboot
fastboot flash system <img>
fastboot erase userdata
fastboot reboot
```

---

## 💾 Layout Partisi Super (Slot A)

| Partisi | Sektor | Ukuran |
|---------|--------|--------|
| `system_a` | 1,833,680 | ~896 MB |
| `system_ext_a` | 3,082,840 | ~1.5 GB |
| `product_a` | 554,304 | ~270 MB |
| `vendor_a` | 680,504 | ~332 MB |
| `odm_a` | 1,333,352 | ~651 MB |
| `vendor_dlkm_a` | 45,488 | ~22 MB |
| `odm_dlkm_a` | 45,488 | ~22 MB |
| `system_dlkm_a` | 14,232 | ~7 MB |
| `tr_product_a` | 2,333,592 | ~1.1 GB |
| `tr_region_a` | 6,801,088 | **~3.3 GB** |
| **Total Super** | - | **~9 GB** |

> Partisi `tr_*` (Transsion) mengambil ~4.4 GB!

---

## 🔗 Partisi Fisik

```
boot_a=p27, boot_b=p43
init_boot_a=p29, init_boot_b=p45
dtbo_a=p30, dtbo_b=p46
vendor_boot=pXX
super=p48 (9,437,184 KB)
userdata=p52 (49,912,800 KB ≈ 47.6 GB)
```

---

## 🔒 VINTF Compatibility Analysis

### Device Matrix (Vendor)
- `system-sdk = {35}`

### Framework Manifest (System)
- `system-sdk = {..., 34, 35, 36}`

### Kesimpulan
⚠️ **COCOK PADA NILAI system-sdk, VINTF PENUH BELUM DIBUKTIKAN**

`{35} ⊆ {34,35,36}` hanya menunjukkan nilai `system-sdk` vendor ada di daftar
yang disediakan framework. Ini **bukan** bukti kompatibilitas VINTF lengkap.
Pemeriksaan VINTF melibatkan dua pasangan:

1. Framework compatibility matrix (FCM) vs **device manifest** vendor.
2. Framework manifest vs **device compatibility matrix** vendor.

Selain itu versi FCM, versi HAL, dan `kernel` requirements harus cocok.

Yang masih perlu dilakukan sebelum menyimpulkan "kompatibel":

- jalankan `checkvintf` dengan manifest stok dan FCM/FM dari build,
- bandingkan versi HAL yang dideklarasikan vendor dengan yang diminta framework,
- jalankan VTS/VTS-TestCase yang relevan pada perangkat.

Bukti yang sudah ada: GSI Android 16 (AxionOS 2.8) berhasil boot dengan vendor
Android 15. Itu menunjukkan system-side A16 bisa berjalan, tetapi belum
membuktikan seluruh HAL vendor memenuhi kontrak VINTF yang diminta build ini.

---

## 🛠️ Rekomendasi Implementasi

### Opsi 1: Android 16 (Direkomendasikan)
- ✅ GSI A16 sudah terbukti boot
- Pakai kernel 6.6.89 stok
- System A16 + vendor A15: layak dicoba, **belum terbukti stabil** untuk build ini

### Opsi 2: Android 15 (Fallback)
- Jika ada masalah tak terprediksi
- Kompatibel dengan seluruh komponen

---

## 📊 Ringkasan Teknis

| Komponen | Nilai |
|----------|-------|
| Platform | Android 16 / API 36 |
| Vendor API | 15 / 35 |
| Kernel | 6.6.89-android15-8 (prebuilt) |
| AVB | SHA256_RSA2048, vbmeta_system + vbmeta_vendor |
| Dynamic Partitions | Ya (super partition, group `main`) |
| A/B OTA | Ya (slot a/b); konfigurasi build memakai Virtual A/B |
| Verified Boot | Orange (unlocked), build memakai AOSP test key |

---

## 📎 Lampiran

- File fstab khusus: `vendor/etc/fstab.mt6768`
- Kernel prebuilt: SHA256 `AE17031903B1F5CACD5C0E718680BF1EB8881048B46AE96EC61239B7AC6703E1`
- Build fingerprint stok: `Infinix/X6840-OP/Infinix-X6840:16/BP2A.250605.031.A3/301400019:user/release-keys`