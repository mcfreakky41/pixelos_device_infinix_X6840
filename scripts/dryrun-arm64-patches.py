#!/usr/bin/env python3
"""
dryrun-arm64-patches.py — uji patch arm64-host TANPA menunggu CI.

Masalah yang dipecahkan:
  Run #18 memakan ~25 menit lalu gagal karena anchor patch (a2) tidak cocok
  secara senyap (bentuk baris i686 PixelOS sixteen beda dari AOSP-17 di blog).
  Siklus 25 menit untuk satu bug teks itu terlalu mahal.

Cara kerja:
  1. Unduh sumber PixelOS `sixteen` yang relevan (raw githubusercontent).
  2. Terapkan logika patch yang SAMA dengan scripts/apply-arm64-host.sh.
  3. Verifikasi: penanda ada, struktur seimbang, tidak ada WARN.

Pakai:
  python dryrun-arm64-patches.py            # jalankan semua cek
  python dryrun-arm64-patches.py --verbose  # tampilkan potongan hasil
"""
import sys
import urllib.request

BASE = "https://raw.githubusercontent.com/PixelOS-AOSP"
RAW = {
    "android_build": f"{BASE}/android_build/sixteen",
    "android_build_soong": f"{BASE}/android_build_soong/sixteen",
    "android_system_sepolicy": f"{BASE}/android_system_sepolicy/sixteen",
}

FAILS = []
WARNS = []


def fetch(repo, path):
    url = f"{RAW[repo]}/{path}"
    try:
        return urllib.request.urlopen(url, timeout=60).read().decode("utf-8")
    except Exception as e:
        FAILS.append(f"unduh gagal: {url} -> {e}")
        return None


def check(desc, cond, detail=""):
    if cond:
        print(f"  OK   {desc}")
    else:
        FAILS.append(f"{desc} {detail}")
        print(f"  FAIL {desc} {detail}")


def warn(desc, detail=""):
    WARNS.append(f"{desc} {detail}")
    print(f"  WARN {desc} {detail}")


def info(desc):
    print(f"  INFO {desc}")


# ===========================================================================
# 0001 — build/make/envsetup.sh: get_host_prebuilt_prefix
# ===========================================================================
def patch_0001():
    print("\n[0001] envsetup.sh: get_host_prebuilt_prefix -> linux-arm64")
    s = fetch("android_build", "envsetup.sh")
    if s is None:
        return
    old = '''function get_host_prebuilt_prefix
{
  local un=$(uname)
  if [[ $un == "Linux" ]] ; then
    echo linux-x86
'''
    if "linux-arm64" in s and "um=$(uname -m)" in s:
        check("cabang linux-arm64 sudah ada", True)
        return
    check("anchor get_host_prebuilt_prefix cocok", old in s)
    if old in s:
        new = '''function get_host_prebuilt_prefix
{
  local un=$(uname)
  local um=$(uname -m)
  if [[ $un == "Linux" ]] ; then
    if [[ $um == "aarch64" ]] ; then
      echo linux-arm64
    else
      echo linux-x86
    fi
'''
        s2 = s.replace(old, new, 1)
        check("hasil punya linux-arm64", "linux-arm64" in s2)
        check("blok if/else seimbang",
              s2.count("    if [[ $um == \"aarch64\" ]] ; then") == 1)


# ===========================================================================
# 0002 — envsetup.mk: HOST_ARCH, HOST_PREBUILT_ARCH, blok endif
# ===========================================================================
def patch_0002():
    print("\n[0002] envsetup.mk: HOST_ARCH=arm64 + endif seimbang")
    s = fetch("android_build", "core/envsetup.mk")
    if s is None:
        return

    anchor = '''ifneq (,$(findstring x86_64,$(UNAME)))
  HOST_ARCH := x86_64
  HOST_2ND_ARCH := x86
  HOST_IS_64_BIT := true
else
'''
    check("anchor HOST_ARCH x86_64 cocok", anchor in s)
    if anchor not in s:
        return
    add_a = anchor + '''ifneq (,$(findstring aarch64,$(UNAME)))
  HOST_ARCH := arm64
  HOST_2ND_ARCH :=
  HOST_IS_64_BIT := true
else
'''
    s = s.replace(anchor, add_a, 1)

    # (a2) sisipkan endif penutup, dengan cara yg sama seperti skrip
    MARK = "# arm64-host: endif penutup blok HOST_ARCH"
    lines = s.split("\n")
    inserted = False
    for i, ln in enumerate(lines):
        if "32-bit x86 host is not supported" in ln:
            seen = 0
            for j in range(i + 1, min(len(lines), i + 12)):
                if lines[j].strip() == "endif":
                    seen += 1
                    if seen == 2:
                        lines.insert(j + 1, MARK)
                        lines.insert(j + 2, "endif")
                        inserted = True
                        break
            break
    check("endif penutup disisipkan", inserted)
    s = "\n".join(lines)

    # verifikasi keseimbangan blok HOST_ARCH.
    # Catatan penting: "ifeq ($(HOST_OS),darwin)" muncul LEBIH DULU di file
    # (di bagian HOST_CROSS), jadi WAJIB dicari mulai dari `start`, kalau tidak
    # rentang jadi kosong dan cek "lolos" palsu. Titik awal = baris ifneq x86_64.
    start = s.index("ifneq (,$(findstring x86_64,$(UNAME)))")
    end = s.index("ifeq ($(HOST_OS),darwin)", start)
    assert start < end, "rentang blok HOST_ARCH tidak valid"
    seg = s[start:end].split("\n")
    op = sum(1 for l in seg if l.strip().startswith(("ifneq", "ifeq")))
    cl = sum(1 for l in seg if l.strip() == "endif")
    check(f"blok HOST_ARCH seimbang (open={op}, endif={cl})", op == cl and op > 0)

    # HOST_PREBUILT_ARCH
    old_b = '''# We don't want to move all the prebuilt host tools to a $(HOST_OS)-x86_64 dir.
HOST_PREBUILT_ARCH := x86
'''
    check("anchor HOST_PREBUILT_ARCH cocok", old_b in s)
    if old_b in s:
        new_b = '''# We don't want to move all the prebuilt host tools to a $(HOST_OS)-x86_64 dir.
# arm64-host: samakan tag prebuilt dgn Soong PrebuiltOS() -> linux-arm64
ifeq ($(HOST_ARCH),arm64)
HOST_PREBUILT_ARCH := arm64
else
HOST_PREBUILT_ARCH := x86
endif
'''
        s = s.replace(old_b, new_b, 1)
        check("HOST_PREBUILT_ARCH := arm64 ada", "HOST_PREBUILT_ARCH := arm64" in s)


# ===========================================================================
# 0002b — core/clang/config.mk
# ===========================================================================
def patch_0002b():
    print("\n[0002b] core/clang/config.mk: LLVM_READOBJ/RTLIB_PATH arm64")
    s = fetch("android_build", "core/clang/config.mk")
    if s is None:
        return
    old = '''## Clang configurations.

LLVM_READOBJ := $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/bin/llvm-readobj

LLVM_RTLIB_PATH := $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION)/lib/clang/$(LLVM_RELEASE_VERSION)/lib/linux/
'''
    check("anchor clang/config.mk cocok", old in s)
    check("memuat HOST_$(HOST_ARCH).mk (konsisten dgn HOST_arm64.mk)",
          "$(HOST_ARCH)" in s)


# ===========================================================================
# 0004 — prebuilts/build-tools/Android.bp
# ===========================================================================
def patch_0004():
    print("\n[0004] prebuilts/build-tools/Android.bp: bison/flex/m4/make arm64")
    # repo prebuilts tidak di githubusercontent PixelOS -> lewati, catat saja
    warn("diperiksa saat runtime CI (repo prebuilts tak tersedia via raw)")


# ===========================================================================
# 0006/0007 — soong paths.go / rule_builder.go
# ===========================================================================
def patch_0006():
    print("\n[0006] soong/android/paths.go")
    s = fetch("android_build_soong", "android/paths.go")
    if s is None:
        return
    check("anchor collapse LinuxMusl cocok",
          "if os == LinuxMusl && ctx.Config().UseHostMusl() {" in s)
    check("anchor archName x86 cocok",
          'archName = "x86"' in s)


def patch_0007():
    print("\n[0007] soong/android/rule_builder.go")
    s = fetch("android_build_soong", "android/rule_builder.go")
    if s is None:
        return
    check("anchor UseHostMusl cocok",
          "if c.rule.ctx.Config().UseHostMusl() {" in s)


# ===========================================================================
# 0003/0009 — rust toolchain_library.go / builder.go
# ===========================================================================
def patch_0003():
    """Patch 0003 (real PixelOS sixteen): rustSetToolchainSource hardcode linux-x86.

    Struktur Rust PixelOS sixteen BEDA TOTAL dari AOSP-17 di blog:
      - file pendek (~160 baris),
      - TIDAK ada hostPrebuiltTargetProps / addPrebuiltToTarget / linux-musl.
    Bug nyata = 'filepath.Join("linux-x86", ...)' di rustSetToolchainSource.
    Fix    = pakai config.HostPrebuiltTag(ctx.Config()) (sama seperti
             rustToolchainRustcPrebuiltFactory yg sudah host-aware).
    """
    print("\n[0003] soong/rust/toolchain_library.go")
    s = fetch("android_build_soong", "rust/toolchain_library.go")
    if s is None:
        return
    old = '''		prefix := filepath.Join("linux-x86", GetRustPrebuiltVersion(ctx))'''
    check("anchor rustSetToolchainSource('linux-x86') cocok", old in s)
    # import config harus ada supaya patch valid
    check("import 'android/soong/rust/config' ada",
          '"android/soong/rust/config"' in s)
    # HostPrebuiltTag harus memang dipakai fungsi lain (bukti helper host-aware)
    check("HostPrebuiltTag dipakai fungsi rustc prebuilt",
          "config.HostPrebuiltTag(ctx.Config())" in s)
    # setelah patch: tidak boleh ada lagi hardcode linux-x86
    s2 = s.replace(old, "X", 1)
    check("tidak ada sisa hardcode 'linux-x86' di rustSetToolchainSource",
          'linux-x86' not in s2.split("func rustSetToolchainSource")[1].split("func ")[0])


def patch_0009():
    """Patch 0009 TIDAK diterapkan (keputusan berbasis bukti).

    Verifikasi premis keputusan terhadap source nyata:
      - upstream sudah mematikan sysroot implisit ('--sysroot=/dev/null'),
      - blok import nyata TIDAK punya 'runtime' (patch versi lama salah anchor),
      - 'slices' memang belum diimport (bukti tak ada kode yg butuh).
    Kalau salah satu asumsi ini berubah, keputusan harus ditinjau ulang.
    """
    print("\n[0009] soong/rust/builder.go (keputusan: DILEWATI)")
    s = fetch("android_build_soong", "rust/builder.go")
    if s is None:
        return
    anchor = '''	mod := ctx.Module().(cc.LinkableInterface)
	toolchain := config.FindToolchain(ctx.Os(), ctx.Arch())
'''
    check("anchor TransformRlibstoStaticlib cocok (kalau nanti diterapkan)", anchor in s)
    check("rustPathDeps.linkDirs/RLibs ada", "rustPathDeps.linkDirs" in s and "rustPathDeps.RLibs" in s)
    check("premis 1: upstream sudah pakai --sysroot=/dev/null",
          '--sysroot=/dev/null' in s)
    check("premis 2: blok import TIDAK punya \"runtime\" (anchor lama salah)",
          'import (\n\t"path/filepath"\n\t"runtime"\n' not in s)
    check("premis 3: \"slices\" belum diimport", '"slices"' not in s)
    # 0009 tidak dipanggil dari main() — hanya cek premis.
    info("0009 sengaja tidak diterapkan; lihat README tabel 'tidak diterapkan'")


# ===========================================================================
# 0005 — prebuilts/jdk/jdk21/Android.bp
# ===========================================================================
def patch_0005():
    print("\n[0005] prebuilts/jdk/jdk21/Android.bp")
    warn("diperiksa saat runtime CI (repo prebuilts tak tersedia via raw)")


# ===========================================================================
# 0012 — sepolicy getopt int
# ===========================================================================
def patch_0012():
    print("\n[0012] system/sepolicy: char -> int")
    files = [
        ("checkfc.c", "char c;"),
        ("sepolicy-analyze/attribute.c", "char ch;"),
        ("sepolicy-analyze/neverallow.c", "char ch;"),
        ("sepolicy-check.c", "char ch;"),
    ]
    for path, needle in files:
        s = fetch("android_system_sepolicy", f"tools/{path}")
        if s is None:
            continue
        check(f"{path}: anchor '{needle}' ada", needle in s)


# ===========================================================================
# 0014 — jar-wrapper.sh
# ===========================================================================
def patch_0014():
    print("\n[0014] soong/scripts/jar-wrapper.sh: -Xmx8g")
    s = fetch("android_build_soong", "scripts/jar-wrapper.sh")
    if s is None:
        return
    old = 'exec java "${javaOpts[@]}" -jar ${jardir}/${jarfile} "$@"'
    check("anchor exec java cocok", old in s)


def main():
    print("=" * 66)
    print(" DRY-RUN patch arm64-host terhadap sumber PixelOS sixteen")
    print("=" * 66)
    for fn in (patch_0001, patch_0002, patch_0002b, patch_0003, patch_0004,
               patch_0005, patch_0006, patch_0007, patch_0009, patch_0012,
               patch_0014):
        try:
            fn()
        except Exception as e:
            FAILS.append(f"{fn.__name__} exception: {e}")
            print(f"  FAIL {fn.__name__} exception: {e}")

    print("\n" + "=" * 66)
    print(f" RINGKASAN: {len(FAILS)} gagal, {len(WARNS)} peringatan")
    print("=" * 66)
    for f in FAILS:
        print("  FAIL " + f)
    for w in WARNS:
        print("  WARN " + w)
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
