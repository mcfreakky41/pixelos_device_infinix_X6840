# STATUS PROJECT - PixelOS X6840 (Infinix Smart 20)

**Terakhir update:** 2026-11-14 (diagnosa run #146-156; fix mojibake YAML; run #157 berjalan)

---

## 📊 Ringkasan Status

| Item | Status |
|------|--------|
| Device tree | ✅ di-commit ke branch `main` |
| Vendor blobs | ✅ di-upload (GitHub Release `blobs-v1`, sudah ada `SHA256SUMS`) |
| Kernel prebuilt | ✅ ada (mt6768, arm64, prebuilt) |
| Workflow CI | ✅ aktif, manual dispatch via GitHub Actions |
| Runner | **ubuntu-24.04-arm** (native arm64 build) |
| Target | **PixelOS `sixteen` (Android 16)** |
| Release config | **bp2a** (PixelOS sixteen) |
| Build terkini | image-only; lihat Actions untuk hasil terakhir |
| Status rilis | ⚠️ **belum siap rilis** — belum ada build yang lolos penuh + diuji di perangkat |
| Panduan flash | 📄 [docs/FLASHING.md](FLASHING.md) |

---

## 🎯 Keputusan Arsitektur

### Skenario Dipilih: **Android 16 dengan vendor API 35**
- ✅ Android 16 GSI (AxionOS 2.8) pernah **boot** di device
- ⚠️ Platform A16 + vendor API 35: nilai `system-sdk` cocok, tetapi
  **kompatibilitas VINTF penuh belum dibuktikan** (butuh `checkvintf` +
  manifest stok + VTS)
- ✅ Build memakai kernel/boot/vendor stok; hanya partisi logis system-side
  yang diganti
- ✅ Komponen Qualcomm dibuang karena platform MediaTek MT6768

---

## 🔧 Perbaikan Audit yang Diterapkan

### `scripts/fetch-blobs.sh`
- Regex path diperbaiki: mengambil path utuh
  (`proprietary/[^"[:space:]\\:]+`), bukan satu karakter
- Hitungan file memakai `mapfile` + `${#array[@]}`, bukan panjang string
- `SHA256SUMS` **wajib**; unduhan diverifikasi sebelum ekstraksi
  (escape hatch: `ALLOW_UNVERIFIED_BLOBS=1`)
- Folder tujuan dibersihkan sebelum ekstraksi; arsip dengan path absolut/`..`
  ditolak
- Validasi kelengkapan memakai `X6840-vendor.mk` sebagai sumber kebenaran,
  dengan `ALLOW_MISSING_BLOBS=1` sebagai escape hatch
- `proprietary-files.txt` diperiksa sebagai advisory (format `path;FIXUP`,
  baris `-`, fstab dikecualikan)

### `scripts/fix-source-tree.sh`
- Guard root source tree: menolak jalan kalau bukan root Android / bukan tree
  X6840
- Penghapusan Qualcomm dibatasi path eksplisit + helper `drop_dir()` yang
  menolak path berbahaya
- **SimpleSettingsConfig:** modul tidak lagi di-disable. Perbaikan yang benar
  adalah menghapus permintaan paket dari `vendor/aosp/**/*.mk`, karena
  `lineage-sdk` tidak ada di manifest PixelOS sixteen
- Patch livedisplay gagal → exit nonzero (tidak lagi "lanjut walau gagal")
- Verifikasi akhir fail-closed: skrip exit 1 bila masih ada sisa masalah

### `device/infinix/X6840/device.mk`
- Copy massal `find-copy-subdir-files` **dihapus** (salah `LOCAL_PATH`,
  arah `../../vendor`, dan prefix tujuan)
- Virtual A/B diaktifkan lewat
  `$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)`
- Hanya satu mekanisme pemasangan fstab (`PRODUCT_COPY_FILES`)

### `device/infinix/X6840/BoardConfig.mk`
- `system_dlkm` masuk `BOARD_AVB_VBMETA_SYSTEM`
- Kunci AVB memakai `?=` supaya bisa dioverride dari environment/local.mk
- Komentar eksplisit: test key = dev only; asumsi Virtual A/B; `tr_manifest`
  tidak diverifikasi AVB karena image-nya stok
- `rootdir/Android.mk` dihapus (duplikat pemasangan fstab)

### `vendor/infinix/X6840/X6840-vendor.mk`
- 15 overlay APK yang sebelumnya tidak punya mapping ditambahkan
  (5 di `vendor/app`, 10 di `vendor/overlay`)

### `scripts/apply-arm64-host.sh`
- **Fail-closed:** anchor yang tidak cocok → `sys.exit(1)` → `warn` → exit 1
- Guard root source tree
- Verifikasi akhir memeriksa semua penanda patch wajib, bukan hanya tiga
- Workflow tidak lagi memakai `|| true`

### `scripts/dryrun-arm64-patches.py`
- Mode `--root`: menguji anchor terhadap **checkout yang sama** dengan build
  (bukan branch remote yang bisa berubah)
- Cakupan ditambah: build-tools, JDK 21 javap, Rust glibc arm64, rustprebuilts

### CI (`.github/workflows/build.yml`)
- Dry-run dijalankan sebelum patch diterapkan
- Apply patch tanpa `|| true`
- Validasi image wajib sebelum upload (`system`, `system_ext`, `product`,
  `vbmeta`, `vbmeta_system`, `vbmeta_vendor`) + ringkasan AVB
- `if-no-files-found: error` untuk artifact ROM
- Action diperbarui (checkout v7, upload-artifact v7, setup-java v6)
- Smoke test clang: compile + jalankan binary host aarch64

### Dokumentasi
- `docs/FLASHING.md` ditulis ulang: backup via ADB **sebelum** fastboot,
  backup semua image, peringatan `erase userdata`, fastbootd, rollback,
  penjelasan SELinux/AVB yang akurat
- `docs/FINDINGS-HDD.md`: klaim VINTF diperhalus
- `README.md`: path script diperbaiki, link issue template `.yml`, cara
  menempatkan device/vendor tree

---

## 💾 Perbaikan Disk (`No space left on device`)

Runner hanya punya ~145 GB (OS ~21 GB), sedangkan sync penuh bisa ~120 GB
(worktree 91 GB + `.repo` ~29 GB) sehingga menyisakan < 5 GB.

Yang diterapkan:
- **Free disk agresif** sebelum sync (toolcache, docker, apt cache, dll.)
- **Local manifest** membuang project x86/emulator/cuttlefish/bazel/openwrt
  serta semua test suite (CTS/VTS/MTS/robolectric/platform_testing)
  yang tidak dipakai build ROM (±15 GB lebih hemat)
- **`.repo` dihapus** setelah sync sebelum build
- **Swap tidak dibuat saat sync** (baru dibuat sebelum build) → +4-6 GB headroom
- **Retry sync tanpa `--force-sync`** agar objek tidak terduplikasi dan disk
  tidak habis
- **Target build image-only** (`systemimage systemextimage productimage
  vbmetaimage`), bukan `bacon` — tidak membangun target_files/OTA zip
  yang memakan 10-20 GB ekstra, dan `super.img` memang tidak dipakai
- **ccache 2 GB** dan upload artifact dibatasi (tanpa `super.img`)
- Guard/print `df -h` di setiap tahap penting

---

## ⏳ Yang Masih Tertunda

- Build CI yang lolos penuh dengan commit audit terbaru
- Uji `checkvintf` dengan manifest stok + FCM/FM dari build
- Verifikasi descriptor AVB hasil build vs fstab (kalau vendor ikut di-flash)
- Uji boot image hasil build di perangkat fisik + rollback
- Uji fungsi hardware (telepon, kamera, Wi-Fi, Bluetooth, sensor)
- Toolchain: workaround Clang r584948b (LLVM 22) untuk tree yang meminta
  r547379 (LLVM 20) masih perlu pembuktian lewat build penuh

---

## 🧪 Riwayat Build Terbaru

- **Run `42799759405`** (commit `1c0baf9`, audit fixes): **GAGAL** di step `Build`.
  - Penyebab: Soong bootstrap gagal dengan `unrecognized module type "csuite_test"`.
  - Ditempatkan di `frameworks/base/libs/WindowManager/Shell/tests/flicker/pip/Android.bp:84` dan `art/test/Android.bp:1407`.
  - **Perbaikan:** `scripts/fix-source-tree.sh` kini patch blok `csuite_test` secara spesifik (commit `3868033`).
- **Run `42804973683`** (commit `3868033`): **GAGAL** di Soong bootstrap —
  `unrecognized module type "csuite_test"` → diperbaiki di `3868033`.
- **Run `42809964475`** (commit `7eae53b`): **GAGAL** di Soong bootstrap —
  `unrecognized module type` berubah menjadi *depends on undefined module*
  (`cts_defaults`, `mts-target-sdk-version-current`, …). Termasuk error baru:
  `packages/modules/Profiling/tests/cts/Android.bp:22` —
  `CtsProfilingModuleTests` depends on undefined `cts_defaults`.
- **Run `42814588670`** (commit `c3a9ae8`): **GAGAL** di Soong bootstrap
  (step Build). Error aktual:
  - `build/bazel/examples/android_test_helper_app/Android.bp:19` —
    `CtsEmptyTestAppExample` depends on undefined `cts_defaults`
  - `packages/modules/Uwb/tests/cts/tests/Android.bp:20` —
    `CtsUwbTestCases` depends on undefined `cts_defaults`
  - `packages/modules/Connectivity/tests/cts/hostside/Android.bp:36` —
    `CtsHostsideNetworkTests` depends on undefined `cts_defaults`
  - `tools/tradefederation/contrib/Android.bp:19` —
    `tradefed-contrib` depends on undefined `tradefed_errorprone_defaults`
  - **Analisis:** patch 4.6 versi sebelumnya hanya menangani entri
    multi-baris di `packages/modules` + `tools/tradefederation`; entri
    inline (`defaults: ["cts_defaults"]`) dan file di `build/bazel/`
    lolos. Patch 4.6 baru memindai seluruh tree (build, packages/modules,
    tools, frameworks, external, system, art, test, platform_testing,
    device, vendor) dan menangani entri inline + multi-baris.
- **Run `42930830683`** (commit `3da985d`): **DITOLAK** sebelum build
  (developer menahan). Patch 4.6 versi `3da985d` berpotensi merusak
  file `Android.bp` — menghapus string `"cts_defaults"` di properti `name:`.
- **Run `42932232012`** (commit `6810b92`): **DITOLAK** sebelum build
  (developer menahan). Perbaikan verifikasi akhir belum selesai.
- **Run `42933293380`** (commit `93d94f3`): **SEDANG BERJALAN** — patch 4.6
  final: verifikasi akhir cek semua elemen array, tidak hanya posisi pertama.
- **Run `43378490070`** (run #147, 2026-11-13): **GAGAL** di Soong bootstrap
  (tahap baru setelah robolectric diperbaiki):
  - `packages/apps/DeviceDiagnostics/TradeInModeTests/Android.bp:22` — undefined
    `vndk_utils`, `vts_kernel_utils`, `vts_vndk_utils`
  - `system/libvintf/Android.bp:186` — `libassemblevintf` (modul sistem!) undefined
    `libvts_vintf_test_common`
  - **Perbaikan:** hapus 7 baris remove-project VTS dari build.yml.
- **Run `43403885031`** (run #150, 2026-11-13): **GAGAL** di Soong bootstrap
  (satu layer lebih jauh setelah fix Cuttlefish):
  - `prebuilts/rust/Android.bp:539` — `rustc` butuh `gcc.lib/lib32/lib64/sysroot`
  - `trusty/vendor/google/aosp/scripts/Android.bp:21` — butuh
    `trusty_dirgroup_prebuilts_gcc_linux-x86_host_x86_64-linux-glibc2.17-4.8`
  - Semua modul itu didefinisikan di repo gcc x86_64 prebuilts yang di-drop.
  - **Perbaikan:** restore repo gcc dari local manifest (`60f3cefd`) DAN hapus
    dari daftar `rm -rf` di step Reclaim (`9cdbfe55`). Run #151 (`60f3cefd`)
    sengaja DIBATALKAN karena hanya memperbaiki separuh masalah.
- **Run `43424908491`** (run #154, 2026-11-13): **GAGAL** di Soong bootstrap.
  Section 4.10 (Virtualization) BERHASIL — error baru:
  `hardware/interfaces/gatekeeper/...:58` & `keymint/...:182` butuh
  `com.google.cf.apex.key`/`certificate` (milik Cuttlefish yang di-drop).
  **Perbaikan:** section 4.11 `fix-source-tree.sh` — ganti ke kunci HAL baku
  `com.android.hardware.key`/`:com.android.hardware.certificate`
  (dari `hardware/interfaces/apexkey`, dipakai semua HAL apex lain).
- **Run `43446219980`** (run #155, 2026-11-13): **GAGAL** di Soong bootstrap.
  Section 4.11 BERHASIL — error baru: ratusan modul di
  `art/test/Android.run-test.bp` butuh modul undefined `rewrapper`.
  **Investigasi:** `run_test_build.py` memakai `--rewrapper` (RBE / Remote
  Build Execution). Setelah pencarian recursive-tree di 10+ repo AOSP, modul
  `rewrapper` ditemukan didefinisikan di
  `platform/prebuilts/remoteexecution-client/Android.bp` (satu-satunya modul
  di repo itu) — repo yang ada di daftar remove-project.
  **Perbaikan:** pulihkan `prebuilts/remoteexecution-client` (commit
  `a5c1f54d` + koreksi `bff08d09`).
- **Run `43525779009`** (run #156, 2026-11-13): **GAGAL TANPA JOB** (workflow
  invalid). Penyebab: commit koreksi di atas mengalami double-encoding UTF-8
  (em-dash `—` menjadi karakter kontrol U+0080/U+0094) → YAML menolak
  karakter kontrol. **Perbaikan:** commit `2eb6fc55` — mojibake diperbaiki,
  YAML divalidasi (PyYAML) sebelum di-push. **Pelajaran: semua push file
  ber-UTF-8 WAJIB lewat Python base64, bukan btoa JavaScript.**
- **Run `43410021847`** (run #152, 2026-11-13): **GAGAL** di Soong bootstrap
  (satu layer lebih jauh lagi):
  - `packages/modules/Virtualization/build/microdroid/initrd/Android.bp:65,76`
    — `microdroid_gki-*_initrd_gen_x86_64` butuh `microdroid_gki_modules-*-x86_64`
    (repo `kernel/prebuilts/{6.6,6.12}/x86-64` di-drop). Host-tool microdroid
    x86_64, tidak relevan untuk device arm64.
  - **Perbaikan:** `fix-source-tree.sh` section 4.10 membuang baris srcs yang
    mereferensikan kernel prebuilt x86-64 di Virtualization (definisi modul
    tetap ada).
- **Run `43390192963`** (run #149, 2026-11-13): **GAGAL** di Soong bootstrap
  (tahap baru lagi setelah fix MLTS + SimpleSettingsConfig):
  - `platform_testing/Android.bp:5` — `platform_tests` depends on undefined
    `CuttlefishRilTests` + `CuttlefishWifiTests` (repo `device/google/cuttlefish`
    di-drop local manifest sejak commit `47dd1d9`; sejak commit `e2a971ff`
    platform_testing di-sync kembali, referensinya jadi terlihat).
  - **Perbaikan:** `fix-source-tree.sh` section 4.9 membuang kedua referensi
    dari `platform_testing/**/Android.bp` (test_suites, bukan bagian ROM) —
    tidak perlu restore repo cuttlefish yang besar.
- **Run `43384832216`** (run #148, 2026-11-13): **GAGAL** lagi di Soong bootstrap
  (satu layer lebih jauh):
  - `cts/tests/tests/neuralnetworks/benchmark/Android.bp:20` & `test/vts-testcase/
    hal/neuralnetworks/{V1_2,V1_3}/benchmark/java/Android.bp:23` — undefined
    `libnnbenchmark_jni`, `NeuralNetworksApiBenchmark_Lib`, `test_mlts_models_assets`
  - `packages/apps/SimpleSettingsConfig/Android.bp:16` — `SimpleSettingsConfig`
    undefined `org.lineageos.platform.internal` (lineage-sdk tidak ada di manifest
    PixelOS; file bp-nya dihidupkan lagi oleh fix-source-tree versi lama)
  - **Perbaikan:** hapus remove-project `mlts/benchmark` + `mlts/models`;
    `fix-source-tree.sh` kini MENONAKTIFKAN (bukan menghidupkan) file bp
    SimpleSettingsConfig.
- **Run `42965165542`** (run #146, commit `a1e1f03`, 2026-11-11): **GAGAL** di
  Soong bootstrap (step Build, ~1m20s setelah mka mulai). Error aktual:
  - `prebuilts/misc/common/robolectric/Android.bp:10:1` —
    `robolectric-android-all-prebuilts` depends on undefined module
    `robolectric-host-android_all`.
  - **Analisis:** `robolectric-host-android_all` didefinisikan di
    `platform/external/robolectric/Android.bp:112`, tetapi repo itu
    **dibuang dari sync** oleh local manifest `drop-unused-arm64.xml`
    (run mulai 2026-11-10, strategi hemat disk). Semua error sebelumnya
    sudah teratasi — ini sisa konflik strategi "drop test project".
  - **Perbaikan:** hapus `<remove-project name="platform/external/robolectric"/>`
    dan `<remove-project name="platform/test/robolectric-extensions"/>` dari
    build.yml; tambah `scripts/diagnose-undefined-mods.sh` + step workflow
    "Diagnose build failure" supaya error undefined module berikutnya langsung
    menunjuk repo yang harus dipulihkan.

---

## 📋 Verifikasi Build

```bash
# Cek status build terbaru
gh run list -R mcfreakky41/pixelos_device_infinix_X6840

# Atau lihat via GitHub Actions UI
```

---

## ⚡ Panduan Flash

Lihat [`docs/FLASHING.md`](FLASHING.md) untuk urutan lengkap + rollback.

**Yang harus di-flash:**
- `system.img`, `system_ext.img`, `product.img`
- `vbmeta.img` (top-level) dengan `--disable-verity --disable-verification`

**Yang tidak boleh di-flash (prosedur normal):**
- `vbmeta_system.img` / `vbmeta_vendor.img` — chained vbmeta, hanya untuk
  inspeksi. Vendor/odm tetap stok, jadi chained vbmeta hasil build tidak
  konsisten dengan image stok.
- `super.img` — build ini tidak membuatnya
- `boot`, `vendor_boot`, `init_boot`, `dtbo`, `vendor`, `odm`, `*_dlkm` —
  tetap stok

---

## ⚠️ Batas Pengujian

- Belum ada bukti build image-only ini lolos penuh dan menghasilkan image
  yang bisa boot di perangkat.
- Keberhasilan GSI Android 16 boot **bukan** bukti build ini benar.
- Kunci AVB masih AOSP test key; bukan build produksi.
- VINTF penuh, AVB chain, dan perilaku SELinux vendor belum diverifikasi.
- Backup/rollback di `docs/FLASHING.md` belum diuji pada perangkat dengan
  image hasil build ini.
- `AB_OTA_PARTITIONS` masih mencantumkan `vendor_boot` dan `vbmeta`
  (dump firmware mencatat keduanya tanpa suffix slot). Belum diverifikasi
  dengan `fastboot getvar has-slot:vendor_boot` / `has-slot:vbmeta` pada
  perangkat — jangan dipakai untuk OTA sampai dicek.
- Super partition (`BOARD_MAIN_PARTITION_LIST`) belum memuat partisi
  Transsion (`tr_*`) yang ada di dalam super; `super.img` **tidak boleh**
  dibangun/di-flash dari konfigurasi ini.
