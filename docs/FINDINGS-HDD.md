# TEMUAN DARI HDD EKSTERNAL (VERIFIKASI)

Tanggal: 2026-10-20
Sumber: `E:\RAIHAN\backup dari os opensuse\root hp infinix smart 20\`
        dan `E:\opencode-backup-20261003-080644\sessions-md\`

## File di folder raihan

| File | Ukuran | Catatan |
|---|---|---|
| `boot.img` | 64 MB | SHA256: 989F92C9... (kernel terekstrak perlu diverifikasi) |
| `init_boot_stock_16.1.0.140SP09.img` | 8 MB | init_boot STOK asli |
| `init_boot_magisk_patched_30.7.img` | 8 MB | init_boot yang di-patch Magisk |
| `Magisk-v30.7.apk` | 11 MB | |
| `vbmeta.img` | kecil | |
| `vbmeta_system.img` | kecil | |

## Verifikasi kernel
Kernel hasil ekstrak dari `boot.img` backup **IDENTIK** dengan kernel yang dipakai
proyek: 36,461,056 bytes, SHA256 `AE17031903B1F5CACD5C0E718680BF1EB8881048B46AE96EC61239B7AC6703E1`.
→ Kernel prebuilt proyek VALID.

## Temuan KRUSIAL dari catatan sesi lama (GSI)

### Firmware asli HP
- Build: **X6840-16.3.0.140SP09(OP004PF001AZ)** (XOS 16.3)
- Sebelumnya juga tercatat 16.2.0.145SP09, 16.1.0.140SP09 (riwayat update)
- Fingerprint: `Infinix/X6840-OP/Infinix-X6840:16/BP2A.250605.031.A3/301400019:user/release-keys`

### Slot aktif
- `current-slot: a` (saat fastbootd)
- `ro.boot.slot_suffix: _a`

### Boot state
- `ro.boot.verifiedbootstate = orange`
- `ro.boot.veritymode = enforcing`
- `ro.boot.vbmeta.device_state = unlocked`
- Magisk 30.7 aktif

### ⭐ GSI Android 16 TERBUKTI BOOT di device ini
- **AxionOS 2.8** (`AxionOS-2.8-20260930-VANILLA-GSI.img`) → **boot sempurna**
  - `ro.axion.version=2.8-ONEIRA_FINAL-20260930-UNOFFICIAL-VANILLA-gsi`
  - `ro.build.id=BP4A.251205.006`, Android 16, slot `_a`
  - Boot completed ~105 detik
- LineageOS 23.2 microG juga dicoba
- EvoX 11.11 GSI: sempat bootloop, lalu (kata user) akhirnya bisa boot tapi ada bug

### Prosedur flash GSI yang TERBUKTI BERHASIL
```
adb reboot fastboot              # masuk fastbootd (is-userspace: yes)
fastboot flash system <img>      # auto-resize system_a
fastboot erase userdata
fastboot erase cache             # gagal: "Partition doesn't exist" (normal)
fastboot reboot
```

### Layout super (dari lpdump) — slot A
| Partisi | Sektor | Ukuran |
|---|---|---|
| odm_a | 1,333,352 | ~651 MB |
| odm_dlkm_a | 45,488 | ~22 MB |
| product_a | 554,304 | ~270 MB |
| system_a | 1,833,680 | ~896 MB (DM-0 = 887M saat itu) |
| system_dlkm_a | 14,232 | ~7 MB |
| system_ext_a | 3,082,840 | ~1.5 GB |
| vendor_a | 680,504 | ~332 MB |
| vendor_dlkm_a | 25,568 | ~12 MB |
| **tr_product_a** | 2,333,592 | **~1.1 GB** |
| **tr_region_a** | 6,801,088 | **~3.3 GB** |
| tr_preload_a | 680 | ~340 KB |
| tr_carrier_a | 680 | ~340 KB |
| tr_company_a | 680 | ~340 KB |
| tr_misc_a | 680 | ~340 KB |
| tr_manifest_a | 680 | ~340 KB |
| tr_overlayfs_a | 680 | ~340 KB |

Total super: 9,663,676,416 B (~9 GB). tr_* memakan ~4.4 GB.

### Partisi fisik (dari /proc/partitions + by-name)
boot_a=p27, boot_b=p43, init_boot_a=p29, init_boot_b=p45,
dtbo_a=p30, dtbo_b=p46, vendor_boot, super=p48 (9,437,184 KB),
userdata=p52 (49,912,800 KB ≈ 47.6 GB), metadata=p12 (62 MB),
tranfs=p51 (265 MB), persist=p15, nvdata=p14, nvcfg=p13,
protect1=p16, protect2=p17, tkv_a=p49, sec1=p32, md_udc=p11,
mrdump=p53, otp=p54, flashinfo=p55, preloader_a=boot0, preloader_b=boot1

## Analisis VINTF: apakah system A16 (API 36) cocok dengan vendor API 35?

**Kesimpulan: COCOK (bukan blocker).**

Aturan resmi VINTF (source.android.com/docs/core/architecture/vintf/match-rules):

> **System SDK version matches** — device compatibility matrix menyatakan
> `compatibility-matrix.system-sdk.version`. Cocok **hanya jika himpunan itu
> adalah subset** dari versi system SDK yang disediakan framework manifest
> (`manifest.system-sdk.version`).

Data device ini:
- Device (vendor) matrix minta: `system-sdk = {35}`
- Framework A16 (system) menyediakan: `{..., 34, 35, 36}` (AOSP selalu menyertakan level lama)

→ `{35} ⊆ {34,35,36}` = **MATCH**.

Ini juga sebabnya **AxionOS 2.8 (A16/API36) GSI berhasil boot** di vendor API 35 ini.
Jadi kekhawatiran "vendor 35 vs system 36 tidak kompatibel" **tidak berlaku** —
selama A16 kita tetap menyediakan system SDK 35 (AOSP default sudah begitu).

### Kesimpulan strategi
1. **Android 16 realistis** — GSI A16 sudah terbukti boot di device.
2. Prosedur flash ROM kita: pakai fastbootd + `fastboot flash system` (sama seperti GSI).
   Tapi ROM device-specific punya banyak partisi (system, system_ext, product,
   vendor, odm, dlkm) → perlu `fastboot flashall` atau flash super.img penuh.
3. Risiko utama device-specific A16: vendor stok API 35 vs system A16 (API 36).
   GSI tidak kena karena vendor tidak disentuh. Kalau ROM kita ganti vendor juga,
   perlu vendor dari dump (yang kita punya) — sudah API 35, cocok dgn platform.
