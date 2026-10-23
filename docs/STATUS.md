# STATUS PROJECT — PixelOS X6840

Terakhir update: 2026-10-22 (run #20 gagal karena BOM UTF-8 di `X6840-vendor.mk` — sudah diperbaiki; run #21 dispatched)

## Ringkas
| Item | Status |
|---|---|
| Device tree | pushed (commit `ddfdd82`) |
| Vendor blobs | uploaded (Release blobs-v1) |
| Kernel prebuilt | ada (34.77 MB, ARM64 valid, SHA256 AE1703…) |
| Workflow CI | aktif, manual dispatch |
| Runner | **ubuntu-24.04-arm** (108 GB free, build native arm64) |
| Target | **PixelOS `sixteen` (Android 16)** |
| Release config | **`bp2a`** (satu-satunya yg valid di PixelOS) |
| Build terkini | run #21 (`sixteen`, userdebug, commit `ddfdd82`) — sedang jalan |
| Panduan flash | [`docs/FLASHING.md`](FLASHING.md) |

## Keputusan arah
- **Skenario C** (disetujui user): coba Android 16 dulu; fallback ke `fifteen` (A15) kalau mentok.
- Alasan: GSI Android 16 (AxionOS 2.8) **terbukti boot** di device ini (slot `_a`, Boot completed ~105 s)
  → platform A16 + vendor API 35 kompatibel di HP ini.
- Bukti: `E:\opencode-backup-20261003-080644\sessions-md\2026-09-17_Infinix_Smart_20_Evolution_X_GSI_800_MB.md`
  dan `E:\PixelOS-X6840\FINDINGS-HDD.md`.

## Riwayat build
| Run | Target | Hasil | Error | Perbaikan |
|---|---|---|---|---|
| #1 | — | cancelled | trigger ganda | — |
| #2 | fifteen | failure | branch `pixelos-15.2` tidak ada | ganti ke `fifteen`, JDK, artifact path |
| #3 | fifteen | cancelled (sengaja) | — | BoardConfig+rootdir+sepolicy belum lengkap |
| #4 | fifteen | cancelled | pindah target ke A16 | — |
| #5 | sixteen | failure | **disk habis saat sync** | cleanup native (aksi maximize-build-space rusak) |
| #6 | sixteen | failure | `easimon/maximize-build-space` crash di runner 24.04 | buang aksi itu, ganti cleanup native |
| #7 | sixteen | failure | **disk habis saat sync lagi** (log kosong = runner mati) | pindah ke arm64 + partial-clone |
| #8 | sixteen | failure | paket apt 32-bit tidak ada di arm64 (`*-multilib`, `lib32*`) | paket jadi kondisional per-arsitektur |
| #9 | **sixteen** | **jalan** | — | arm64 (108 GB) + partial-clone + paket apt benar |
| #10 | sixteen | cancelled | — | restart bersih |
| #11–#13 | sixteen | failure | `chromium-webview`: "Cannot initialize work tree" | **akar: flag sync tambahan** (`git config http.*`, `timeout`, `stdbuf`, `2>&1`) — bukan `repo init`. Kembalikan perintah sync run #9 |
| #14 | sixteen | failure | `prebuilts/go/linux-arm64: No such file` (exit 127) | sync **SUKSES** (~96 mnt); tambah step install Go arm64 |
| #15 | sixteen | failure | microfactory: `Failed to compile …: exit status 2` | Go arm64 terpasang; **akar: tarball Go resmi tak punya arsip std-lib** |
| #16 | sixteen | failure | `panic: Missing config trunk_staging` | **Go BERES** (`GODEBUG=installgoroot=all` → 298 `.a`); akar baru: release config salah |
| #17 | **sixteen** | **jalan** | — | `lunch pixelos_X6840 bp2a userdebug` (bukan `trunk_staging`) |
| #18 | sixteen | failure | **`build/make/core/envsetup.mk:1072: error: missing 'endif'`** (patch a2 anchor persis tak cocok senyap) | anchor `(a2)` dibuat tahan-bentuk + dry-run offline |
| #19 | sixteen | failure | `device.mk:15: build/make/target/product/virtual_ab_ota/launcher.mk does not exist` | **semua patch ARM64 lulus (step 14 ✓)**; ganti ke `launch_with_vendor_ramdisk.mk` |
| #20 | sixteen | failure | **`vendor/infinix/X6840/X6840-vendor.mk:1: error: missing separator`** | akar = **UTF-8 BOM** (`ef bb bf`) di awal file hasil generator PowerShell; BOM menyatu ke token pertama sehingga `#` bukan komentar |
| #21 | sixteen | **jalan** | — | BOM dibuang (commit `ddfdd82`) + guard `scripts/check-text-encoding.py` di CI |

## Temuan: BOM UTF-8 = "missing separator" (run #20)
File `.mk` yang diawali BOM **tidak bisa di-parse GNU make**:
```
vendor/infinix/X6840/X6840-vendor.mk:1: error: missing separator.
```
Byte BOM (`ef bb bf`) menyatu ke token pertama, jadi `#` tidak lagi dibaca sebagai
awal komentar. Penyebabnya `Set-Content -Encoding UTF8` di PowerShell 5.1 yang
selalu menulis BOM.

Pencegahan (3 lapis):
1. `scripts/gen-vendor-mk.ps1` → tulis via `[System.IO.File]::WriteAllText`
   dengan `UTF8Encoding($false)` + baris LF paksa, lalu verifikasi.
2. `.gitattributes` → `*.mk text eol=lf` (+ `.yml/.yaml/.gitignore/proprietary-files.txt`).
3. `scripts/check-text-encoding.py` → step CI sebelum build; gagal **dalam hitungan
   detik** kalau ada BOM/CRLF di file `.mk/.bp/.sh/.xml/.yml/.yaml/.rc/.cil/.te/.contexts`
   (perkecualian direktori `proprietary/` yang isinya blob OEM).


## Pelajaran ARM64-host (bagian tersulit kedua)
Manifest PixelOS **hanya menyediakan prebuilt host x86**; runner arm64 butuh tambahan.
Manifest PixelOS/LineageOS **tidak mendukung host aarch64 sama sekali** — tidak ada
cabang `aarch64` di `build/make/core/envsetup.mk`. Run #17 membuktikan itu:

```
build/make/core/envsetup.mk:195: error: unknown variable: HOST_ARCH
```

Solusi = patch set (padanan blog <https://actinis.io/blog/building-aosp-on-arm64>),
diterapkan oleh `scripts/apply-arm64-host.sh` **setelah sync** (repo AOSP tak bisa
kita commit), plus drop prebuilt. Semua patch sudah diverifikasi anchornya terhadap
sumber PixelOS `sixteen`.

| Komponen | Kondisi di manifest | Penanganan |
|---|---|---|
| `prebuilts/build-tools/linux-arm64` | **ADA** (ninja, ckati, bison, flex, m4, make) | aman, tanpa patch |
| **Go** | **TIDAK ADA** (`prebuilts/go/linux-arm64` kosong) | unduh go1.23.4 resmi + `GODEBUG=installgoroot=all go install -a std` → 298 `.a` |
| Clang host arm64 | kosong di `main`; ADA di branch `mirror-goog-main-prebuilts` (`clang-r584948b`/`r596125`/`r614150`) | drop + symlink + override `LLVM_PREBUILTS_VERSION`/`LLVM_RELEASE_VERSION` |
| **Rust arm64** | **KOSONG di semua branch** | drop `rust-1.83.0-aarch64-unknown-linux-musl` + patch 0003 (prefix prebuilt sadar-host) |
| JDK arm64 | `prebuilts/jdk/jdk21` hanya `linux-x86` | Temurin 21 arm64 dari runner + patch 0005 (`javap`) |

Catatan versi Clang: tree minta `clang-r547379` / LLVM `20`, arm64 hanya punya
`clang-r584948b` (LLVM 22) → symlink `clang-r547379`→`clang-r584948b` + `lib/clang/20`→`22`
+ override env. Ini pendekatan yang sama dipakai blog.

Rust: struktur PixelOS `sixteen` **beda total** dari AOSP-17 di blog.
`rust/toolchain_library.go` hanya ~160 baris — **tidak ada** `hostPrebuiltTargetProps`,
`addPrebuiltToTarget`, atau `linux-musl`. Bug nyata = satu baris hardcode
`filepath.Join("linux-x86", …)` di `rustSetToolchainSource()`; **patch 0003** menggantinya
dengan `config.HostPrebuiltTag(ctx.Config())` → `prebuilts/rust-toolchain/linux-arm64/1.83.0`.
**Patch 0009 blog dibuang** (premisnya sudah ada upstream via `--sysroot=/dev/null`;
versi awal kita menyisipkan import `slices` pada anchor import yang salah). Verifikasi
anchor & logika: `scripts/dryrun-arm64-patches.py` (offline, tanpa menunggu CI ~25 menit).

Kunci Go (dikonfirmasi dari source `cmd/go` Go 1.23.4, `build.go`):
> “Setting `GODEBUG=installgoroot=all` restores the use of `$GOROOT/pkg/$GOOS_$GOARCH`.”
Go ≥ 1.20 berhenti menulis `pkg/*.a`; bootstrap microfactory AOSP tetap membutuhkannya.

## Strategi disk (tahap tersulit — sudah terpecahkan)
Sumber Android 16 penuh (~80–100 GB) **tidak muat** di runner x64 gratis (maks ~86 GB).
Penyelesaian lewat dua sumbu, dibuktikan dengan probe (`probe-disk` & `probe-disk2`):

| | x64 `ubuntu-24.04` | **arm64 `ubuntu-24.04-arm`** |
|---|---|---|
| Total disk (`/`) | 145 GB | 145 GB |
| **Free** | **86 GB** | **108 GB** |
| `/usr` | 41 GB | **23 GB** (lebih ramping) |
| `/opt` | 8.8 GB | 5.7 GB |
| Multilib 32-bit | ada | **tidak ada** |

- **Runner `arm64`** dipakai karena repo **public** → gratis, dan disk 108 GB > 86 GB.
  Bonus: device X6840 = **arm64-v8a** → build **native (cepat)**, bukan emulasi.
- **`repo init --partial-clone --clone-filter=blob:limit=10M`** (terbukti berhasil di probe;
  manifest PixelOS = **990 proyek**) → tidak mengunduh blob besar.
- Cleanup native: hapus `/usr/share/dotnet`, `/usr/local/lib/android`, `/usr/share/swift`,
  `/opt/hostedtoolcache`, miniconda, powershell, go, graalvm.
- Setelah sync: reclaim `.git` & `.repo` sebelum build.
- Catatan: runner ini **tidak punya `/mnt` terpisah** → `easimon/maximize-build-space`
  **tidak kompatibel** (aksi itu untuk runner lama Azure DS2_v2 dengan `/mnt` 14 GB).

## Link
- Repo   : https://github.com/mcfreakky41/pixelos_device_infinix_X6840
- Release: https://github.com/mcfreakky41/pixelos_device_infinix_X6840/releases/tag/blobs-v1
- Actions: https://github.com/mcfreakky41/pixelos_device_infinix_X6840/actions

## Cara cek build
```
gh run list -R mcfreakky41/pixelos_device_infinix_X6840
```
atau via API (script: scripts/check-build.ps1)

## Yang sudah dilengkapi (commit da90e0c)
- BoardConfig.mk: DEVICE_PATH, ukuran partisi byte-exact, boot/init_boot/vendor_boot,
  kernel offsets, A/B partition list, AVB vbmeta_system+vendor, bootconfig
- device.mk: API 36, ART tuning 4GB, DSDS/VoLTE, fstab copy, dynamic partitions
- pixelos_X6840.mk: inherit `vendor/aosp/config/common_full_phone.mk`
- rootdir/etc/fstab.mt6768 (ext4 build, turunan stock fstab.mt6768)
- sepolicy/vendor/mtk.te (minimal, self-contained)
- vendorsetup.sh (lunch combo)

## Yang dilengkapi di CI (commit terakhir 8f4f140)
- runner arm64 + partial-clone + cleanup native
- JDK 21, build `-j$(nproc)/2` (hindari OOM)
- paket apt kondisional per-arsitektur (fix build #8)
- reclaim `.git`/`.repo` setelah sync
- blobs diambil dari GitHub Release (bukan disimpan di git)

## Perkiraan error berikutnya (siap diantisipasi)
Berdasarkan blog Actinis (peta jalan lengkap setelah patch host), dinding berikutnya:
1. **Cronet x86 SIMD** — flag `-msse3`, `-mavx*`, `-maes`, `-mpclmul`, `-mf16c` bocor
   ke host aarch64. Fix blog = shim `clang-real` (bash) yang membuang flag `-m*` x86.
   ⚠ Harus **pure bash** (tanpa `dirname`/`basename`) + `exec -a "$0"`.
2. **`llvm-objdump`/`llvm-nm` x86 hardcoded** saat Cronet minta — blog pakai wrapper
   script di dir bin x86 yang mengeksekusi tool arm64 asli (bukan copy biner: ada
   ketergantungan loader musl relatif ke tree asal).
3. **Rust sysroot double vision** — belum ditangani (0009 dibuang karena tak
   terbukti); patch 0003 + drop Rust saja dulu. Kalau `E0464`/`E0460`/`E0152`
   benar-benar muncul di run #19, baru tambal berbasis bukti log.
4. **JVM heap (metalava/SystemUI)** — sudah diantisipasi patch 0014 (`-Xmx8g`).
5. **VINTF (vendor API 35 vs system 36)** — sudah diverifikasi aman:
   - matrix vendor mendeklarasikan `system-sdk {35}`; `BOARD_SYSTEMSDK_VERSIONS := 36 35 34`
     dan `PLATFORM_SYSTEMSDK_VERSIONS` = rentang min..36 → kompatibel.
   - `checkvintf --check-compat` dijalankan dengan
     `--property ro.product.first_api_level=36` (`build/make/core/Makefile:5500`).
   - `init` menghitung `ro.vendor.api_level` = min(level produk, `ro.board.api_level`)
     = min(202404, 202404) = **202404** (A15) — sama seperti perangkat stok
     (`system/core/init/property_service.cpp:1108`, tanpa `LOG(FATAL)`).
   - `TARGET_BOARD_API_LEVEL` ternyata **tidak dipakai sama sekali** di build/make A16
     (variabel legacy) → nilainya harmless.
   - `PRODUCT_SHIPPING_VENDOR_API_LEVEL` **tidak** perlu di-override.
6. **Missing separator** — sudah teratasi (BOM, lihat di atas).

## Catatan penting
- HP JANGAN di-reboot sampai ROM siap flash
- Semua operasi device = read-only
- super.img (9 GB) = backup lokal saja (header gDla, tidak bisa lpunpack)
  → **backup partisi `system_a` mentah** wajib diambil sebelum flash (lihat
  [`docs/FLASHING.md`](FLASHING.md) §5.2)
- vendor/bin: 100% 64-bit (0 file 32-bit) → arm64-only sudah benar
- Kernel backup HDD **IDENTIK** dengan kernel proyek (verified SHA256)
- Prosedur flash terbukti (dari era GSI):
  `adb reboot fastboot` → `fastboot flash system <img>` → `fastboot erase userdata` → `fastboot reboot`
- **Hanya** `system`, `system_ext`, `product`, `vbmeta` yang di-flash.
  `boot`/`vendor_boot`/`init_boot`/`dtbo`/`vendor`/`odm`/`*_dlkm` **tetap stok**
  (`vendor_boot` MTK tidak bisa direproduksi `mkbootimg` AOSP; blob vendor kehilangan
  konteks SELinux). **Jangan flash `super.img`** — isinya `vendor.img` hasil rebuild
  yang tidak valid. Detail + rollback: [`docs/FLASHING.md`](FLASHING.md).

## Update terkini (2026-10-23)
| Item | Status |
|---|---|
| Vendor APK di Soong | Pindah ke `prebuilt_any` (endor/infinix/X6840/Android.bp) dengan `sub_dir` biar dipasang persis ke endor/app/ & endor/overlay/ (hindari PRODUCT_COPY_FILES yang ditolak uild/make). |
| BoardConfig mkbootimg | Tambah `--kernel_offset` dan `--ramdisk_offset` ke BOARD_MKBOOTIMG_ARGS. |
| CI Rust arm64 | Fix symlink librustc_driver ke prebuilts/rust/.../lib64/ tanpa bergantung cd (langsung link per-file + validasi). |
| Build terkini | run #26 (4ff4b26) - in_progress, setelah fix step Rust. |
