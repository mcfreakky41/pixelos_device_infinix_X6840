# Patch set ARM64-host (host aarch64)

Dipakai oleh `.github/workflows/build.yml` lewat `scripts/apply-arm64-host.sh`.

## Kenapa perlu?

Manifest **PixelOS/LineageOS tidak mendukung build di host arm64 sama sekali**.
Bukti: `build/make/core/envsetup.mk` hanya punya cabang `x86_64`/`i686` untuk
`HOST_ARCH`; tidak ada `aarch64`. Di runner `ubuntu-24.04-arm` akibatnya:

```
build/make/core/envsetup.mk:195: error: unknown variable: HOST_ARCH   (run #17)
```

Referensi patch set yang terbukti: <https://actinis.io/blog/building-aosp-on-arm64>
(AOSP 17 di Jetson/DGX Spark). Skrip kita menerapkan padanannya untuk **PixelOS
`sixteen` (Android 16)**.

## Isi patch

| # | File | Isi | Memperbaiki |
|---|---|---|---|
| 0001 | `build/make/envsetup.sh` | `get_host_prebuilt_prefix` → `linux-arm64` pada aarch64 | `one-true-awk: cannot execute binary file` |
| 0002 | `build/make/core/envsetup.mk` | `HOST_ARCH := arm64`, `HOST_PREBUILT_ARCH := arm64` | **`unknown variable: HOST_ARCH`** (run #17) |
| 0002(c) | `build/make/core/clang/HOST_arm64.mk` (file baru) | runtime Clang host arm64 | `clang/config.mk` meng-include `HOST_$(HOST_ARCH).mk` |
| 0002b | `build/make/core/clang/config.mk` | `LLVM_READOBJ`/`LLVM_RTLIB_PATH` pakai `linux-arm64` | host arm64 mencoba binari x86 |
| 0004 | `prebuilts/build-tools/Android.bp` | enable `arm64` + target `linux_musl_arm64` untuk bison/flex/m4/make | tool prebuilt tidak ter-enable |
| 0006 | `build/soong/android/paths.go` | `out/host/linux-arm64` (collapse LinuxMusl, `archName=arm64`) | Make vs Soong beda nama direktori |
| 0007 | `build/soong/android/rule_builder.go` | stage `libc_musl.so` untuk BuiltTool musl | tool gagal jalan di sandbox |
| 0003 | `build/soong/rust/toolchain_library.go` + `prebuilts/rust-toolchain/linux-arm64/Android.bp` (baru) | `libstd` prebuilt untuk `linux_musl_arm64` | `prebuilt_libstd` selalu disabled |
| 0005 | `prebuilts/jdk/jdk21/Android.bp` | `javap` enable `arm64` + target `linux_musl_arm64` | tool JDK host arm64 tak ter-enable |
| 0009 | `build/soong/rust/builder.go` | pin staticlib host arm64 ke sysroot Rust prebuilt | `E0464`/`E0460`/`E0152` (Rust *double vision*) |
| 0012 | `system/sepolicy/tools/*.c` | `char` → `int` untuk hasil `getopt()` | di aarch64 `char` unsigned → sentinel `-1` jadi `0xff` |
| 0014 | `build/soong/scripts/jar-wrapper.sh` | default `-Xmx8g` untuk `java_binary_host` | metalava OOM pada host RAM kecil |

Patch blog yang **tidak** diterapkan (dan alasannya):

| # | Alasan |
|---|---|
| 0008, 0010 | blog sendiri menyatakan **REVERTED** (percobaan yang salah arah); patch 0009 adalah fix final |
| 0011 (KSP heap) | PixelOS `sixteen` belum punya rule `kotlin-ksp-client` — tidak berlaku |
| 0013 (LFI non-fatal) | `external/lfi` tidak ada di manifest PixelOS `sixteen` |

## Prebuilt yang harus disediakan (drop, bukan patch)

| Komponen | Status manifest | Penanganan di workflow |
|---|---|---|
| `prebuilts/build-tools/linux-arm64` | **ADA** | tanpa tindakan |
| Go arm64 | **TIDAK ADA** | unduh go1.23.4 + `GODEBUG=installgoroot=all go install -a std` |
| Clang host arm64 | kosong di `main` | clone branch `mirror-goog-main-prebuilts` → `clang-r584948b` |
| Rust toolchain arm64 | kosong di semua branch | drop resmi `rust-1.83.0-aarch64-unknown-linux-musl` ke `prebuilts/rust-toolchain/linux-arm64/1.83.0/` |
| JDK arm64 | hanya `linux-x86` di prebuilts | pakai Temurin 21 arm64 runner + `javap` dari JDK arm64 |

### Catatan versi Clang (penting)

Tree PixelOS `sixteen` meminta (`build/soong/cc/config/global.go`):

```
ClangDefaultVersion      = "clang-r547379"
ClangDefaultShortVersion = "20"
```

Prebuilt Clang arm64 yang tersedia: `clang-r584948b` / `clang-r596125` / `clang-r614150`
(LLVM 22/…), **tidak ada `clang-r547379`**. Karena `ClangVersion` dan
`ClangShortVersion` punya `StaticVariableWithEnvOverride`, workflow
menetapkan:

```
export LLVM_PREBUILTS_VERSION=clang-r584948b
export LLVM_RELEASE_VERSION=22
```

ditambah symlink `clang-r547379`/`clang-r584948` → `clang-r584948b` dan
`lib/clang/20` → `22` sebagai jaring pengaman.

### Catatan Rust (dinding tersulit)

Tree meminta `RustDefaultVersion = "1.83.0"` (`build/soong/rust/config/global.go`).
Tidak ada prebuilt Rust arm64 di manifest. Solusi (mengikuti blog):

1. Drop toolchain resmi `rust-1.83.0-aarch64-unknown-linux-musl` ke
   `prebuilts/rust-toolchain/linux-arm64/1.83.0/`.
2. Patch 0003 mengaktifkan `prebuilt_libstd` untuk host `linux_musl_arm64`.
3. Patch 0009 memaksa **seluruh host Rust all-prebuilt**: buang link-dir/rlib
   dari-source (`.rust_sysroot`, `libstd/linux_musl_arm64`), lalu pin direktori
   sysroot prebuilt mentah:
   `prebuilts/rust-toolchain/<PrebuiltOS()>/<RustDefaultVersion>/lib/rustlib/<triple>/lib`

Ini menghindari "Rust sysroot double vision" (`E0464`/`E0460`/`E0152`) yang
muncul bila sysroot prebuilt bercampur dengan crate dari-source.

## Sifat skrip

* **Idempoten** — aman dijalankan berulang; penanda mencegah patch ganda.
* **Tidak fatal** — kegagalan satu langkah tidak menghentikan langkah lain,
  supaya satu run bisa mengungkap banyak masalah sekaligus.
* Mencetak ringkasan + jejak verifikasi di akhir.
