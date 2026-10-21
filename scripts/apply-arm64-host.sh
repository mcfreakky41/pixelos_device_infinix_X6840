#!/usr/bin/env bash
# =============================================================================
# apply-arm64-host.sh — buat build AOSP/PixelOS jalan di host ARM64 (aarch64)
#
# LATAR BELAKANG
#   Manifest PixelOS/LineageOS TIDAK mendukung host arm64 sama sekali:
#   build/make/core/envsetup.mk tidak punya cabang aarch64, sehingga di runner
#   arm64 HOST_ARCH kosong dan build gagal:
#       build/make/core/envsetup.mk:195: error: unknown variable: HOST_ARCH
#   (lihat run #17)
#
#   Referensi patch set yang terbukti: https://actinis.io/blog/building-aosp-on-arm64
#   Skrip ini menerapkan padanannya (subset yang terbukti berlaku di PixelOS
#   sixteen) + drop prebuilt arm64. Patch blog yang tak berlaku/tak terbukti
#   sengaja DILEWATI — lihat patches/arm64-host/README.md.
#
# SIFAT
#   Idempoten: aman dijalankan berulang. Kalau penanda sudah ada, dilewati.
#   Tidak fatal: tiap langkah dicatat; kegagalan satu langkah tidak menghentikan
#   langkah lain supaya satu run bisa mengungkap banyak hal sekaligus.
# =============================================================================
set -u

ROOT="${1:-$PWD}"
cd "$ROOT" || { echo "FATAL: tidak bisa cd ke $ROOT"; exit 1; }

echo "=============================================================="
echo " apply-arm64-host.sh  (root=$ROOT)"
echo " host: $(uname -s -m)"
echo "=============================================================="

FAILED=0
step() { echo ""; echo "--- [$1] $2"; }
ok()   { echo "    OK  : $1"; }
skip() { echo "    SKIP: $1"; }
warn() { echo "    WARN: $1"; FAILED=$((FAILED+1)); }

# -----------------------------------------------------------------------------
# Util: sisipkan blok setelah baris yang cocok, hanya jika penanda belum ada.
#   insert_after <file> <pola-anchor> <penanda> <file-isi>
# -----------------------------------------------------------------------------
insert_after() {
  local file="$1" anchor="$2" marker="$3" blockfile="$4"
  if [ ! -f "$file" ]; then warn "file tidak ada: $file"; return; fi
  if grep -qF "$marker" "$file"; then skip "sudah dipatch: $file"; return; fi
  local lineno
  lineno=$(grep -nF -- "$anchor" "$file" | head -1 | cut -d: -f1)
  if [ -z "$lineno" ]; then warn "anchor tak ditemukan di $file: $anchor"; return; fi
  # sed: sisipkan isi blockfile setelah lineno
  sed -i "${lineno}r ${blockfile}" "$file" \
    && ok "patch diterapkan: $file (setelah baris $lineno)" \
    || warn "gagal patch: $file"
}

# -----------------------------------------------------------------------------
# Util: sed_replace <file> <penanda> <old-regex> <new>
# -----------------------------------------------------------------------------
sed_replace() {
  local file="$1" marker="$2" old="$3" new="$4"
  if [ ! -f "$file" ]; then warn "file tidak ada: $file"; return; fi
  if grep -qF "$marker" "$file"; then skip "sudah dipatch: $file"; return; fi
  if ! grep -qE -- "$old" "$file"; then warn "pola tak ditemukan di $file: $old"; return; fi
  sed -i -E "s|$old|$new|" "$file" \
    && ok "sed diterapkan: $file" \
    || warn "sed gagal: $file"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# =============================================================================
# PATCH 0001 — build/make/envsetup.sh: prefix prebuilt host -> linux-arm64
#   Tanpa ini: 'one-true-awk: cannot execute binary file' saat source envsetup.sh
# =============================================================================
step "0001" "envsetup.sh: get_host_prebuilt_prefix -> linux-arm64 pada aarch64"
ENVSETUP="build/make/envsetup.sh"
if [ -f "$ENVSETUP" ]; then
  if grep -q 'um="$(uname -m)"' "$ENVSETUP" 2>/dev/null || grep -qF 'linux-arm64' "$ENVSETUP"; then
    skip "sudah dipatch: $ENVSETUP"
  else
    python3 - "$ENVSETUP" <<'PY' || warn "gagal patch envsetup.sh"
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = '''function get_host_prebuilt_prefix
{
  local un=$(uname)
  if [[ $un == "Linux" ]] ; then
    echo linux-x86
'''
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
if old not in s:
    print("    WARN: pola get_host_prebuilt_prefix tak cocok"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
print("    OK  : envsetup.sh dipatch")
PY
  fi
else
  warn "$ENVSETUP tidak ada"
fi

# =============================================================================
# PATCH 0002 — build/make/core/envsetup.mk
#   (a) cabang HOST_ARCH arm64
#   (b) HOST_PREBUILT_ARCH=arm64
#   (c) core/clang/HOST_arm64.mk (baru)
#   INI YANG MEMBLOKIR RUN #17 (unknown variable: HOST_ARCH).
# =============================================================================
step "0002" "envsetup.mk: HOST_ARCH=arm64 + HOST_PREBUILT_ARCH=arm64 + clang HOST_arm64.mk"
ENVMK="build/make/core/envsetup.mk"
if [ -f "$ENVMK" ]; then
  python3 - "$ENVMK" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
changed = False

# (a) cabang aarch64 untuk HOST_ARCH
anchor = '''ifneq (,$(findstring x86_64,$(UNAME)))
  HOST_ARCH := x86_64
  HOST_2ND_ARCH := x86
  HOST_IS_64_BIT := true
else
'''
add_a = '''ifneq (,$(findstring x86_64,$(UNAME)))
  HOST_ARCH := x86_64
  HOST_2ND_ARCH := x86
  HOST_IS_64_BIT := true
else
ifneq (,$(findstring aarch64,$(UNAME)))
  HOST_ARCH := arm64
  HOST_2ND_ARCH :=
  HOST_IS_64_BIT := true
else
'''
if "HOST_ARCH := arm64" in s:
    print("    SKIP: cabang HOST_ARCH arm64 sudah ada")
elif anchor in s:
    s = s.replace(anchor, add_a, 1); changed = True
    print("    OK  : cabang HOST_ARCH arm64 ditambahkan")
else:
    print("    WARN: anchor HOST_ARCH tak cocok")

# (a2) tutup 'endif' tambahan pada blok 32-bit.
#   Cabang arm64 menambah satu 'else' -> butuh satu 'endif' ekstra.
#   JANGAN cocokkan teks anchor dgn persis: bentuk baris i686 BEDA antar tree
#   (AOSP-17 di blog: 'i686,$(UNAME)))$(findstring x86,...' dgn ',' ekstra;
#   PixelOS sixteen: 'i686,$(UNAME))$(findstring x86,...' tanpa ',').
#   Run #18 membuktikan anchor persis itu GAGAL senyap -> 'missing endif'.
#   Jadi: cari baris $(error 32-bit), lalu sisipkan 'endif' setelah dua 'endif'
#   berikutnya. Idempoten lewat penanda di komentar.
MARK_A2 = "# arm64-host: endif penutup blok HOST_ARCH"
if "HOST_ARCH := arm64" in s and MARK_A2 not in s:
    lines = s.split("\n")
    inserted = False
    for i, ln in enumerate(lines):
        if "32-bit x86 host is not supported" in ln:
            # hitung 'endif' berikutnya (butuh 2), sisipkan setelah yg ke-2
            seen = 0
            for j in range(i + 1, min(len(lines), i + 12)):
                if lines[j].strip() == "endif":
                    seen += 1
                    if seen == 2:
                        lines.insert(j + 1, MARK_A2)
                        lines.insert(j + 2, "endif")
                        inserted = True
                        break
            break
    if inserted:
        s = "\n".join(lines); changed = True
        print("    OK  : endif penutup ditambahkan (blok HOST_ARCH)")
    else:
        print("    WARN: baris $(error 32-bit) / 2x endif tak ditemukan")
elif MARK_A2 in s:
    print("    SKIP: endif penutup sudah ada")

# (b) HOST_PREBUILT_ARCH arm64
old_b = '''# We don't want to move all the prebuilt host tools to a $(HOST_OS)-x86_64 dir.
HOST_PREBUILT_ARCH := x86
'''
new_b = '''# We don't want to move all the prebuilt host tools to a $(HOST_OS)-x86_64 dir.
# arm64-host: samakan tag prebuilt dgn Soong PrebuiltOS() -> linux-arm64
ifeq ($(HOST_ARCH),arm64)
HOST_PREBUILT_ARCH := arm64
else
HOST_PREBUILT_ARCH := x86
endif
'''
if "HOST_PREBUILT_ARCH := arm64" in s:
    print("    SKIP: HOST_PREBUILT_ARCH arm64 sudah ada")
elif old_b in s:
    s = s.replace(old_b, new_b, 1); changed = True
    print("    OK  : HOST_PREBUILT_ARCH arm64 ditambahkan")
else:
    print("    WARN: anchor HOST_PREBUILT_ARCH tak cocok")

if changed:
    open(p, "w", encoding="utf-8").write(s)
PY
else
  warn "$ENVMK tidak ada"
fi

# (c) core/clang/HOST_arm64.mk
CLANGMK="build/make/core/clang/HOST_arm64.mk"
if [ ! -f "$CLANGMK" ]; then
  mkdir -p "$(dirname "$CLANGMK")"
  cat > "$CLANGMK" <<'EOF'
# arm64-host: runtime libs Clang utk host aarch64.
HOST_LIBPROFILE_RT := $(LLVM_RTLIB_PATH)/libclang_rt.profile-aarch64.a
HOST_LIBCRT_BUILTINS := $(LLVM_RTLIB_PATH)/libclang_rt.builtins-aarch64.a
EOF
  ok "dibuat: $CLANGMK"
else
  skip "sudah ada: $CLANGMK"
fi

# =============================================================================
# PATCH 0006 — build/soong/android/paths.go: penamaan out/host/linux-arm64
# =============================================================================
step "0006" "soong/paths.go: host-out dir naming utk host arm64"
PATHS="build/soong/android/paths.go"
if [ -f "$PATHS" ]; then
  python3 - "$PATHS" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
changed = False

old1 = '''		if os == LinuxMusl && ctx.Config().UseHostMusl() {'''
new1 = '''		if os == LinuxMusl && (ctx.Config().UseHostMusl() || os == ctx.Config().BuildOS) {'''
if "os == ctx.Config().BuildOS" in s:
    print("    SKIP: collapse LinuxMusl sudah ada")
elif old1 in s:
    s = s.replace(old1, new1, 1); changed = True
    print("    OK  : collapse LinuxMusl -> linux")
else:
    print("    WARN: anchor collapse LinuxMusl tak cocok")

old2 = '''		archName := arch.String()
		if os.Class == Host && (arch == X86_64 || arch == Common) {
			archName = "x86"
		}
'''
new2 = '''		archName := arch.String()
		if os.Class == Host && (arch == X86_64 || arch == Common) {
			archName = "x86"
			if ctx.Config().BuildArch == Arm64 {
				archName = "arm64"
			}
		}
'''
if 'archName = "arm64"' in s:
    print("    SKIP: archName arm64 sudah ada")
elif old2 in s:
    s = s.replace(old2, new2, 1); changed = True
    print("    OK  : archName arm64 ditambahkan")
else:
    print("    WARN: anchor archName tak cocok")

if changed:
    open(p, "w", encoding="utf-8").write(s)
PY
else
  warn "$PATHS tidak ada"
fi

# =============================================================================
# PATCH 0007 — build/soong/android/rule_builder.go: stage libc_musl.so
# =============================================================================
step "0007" "soong/rule_builder.go: stage libc_musl.so utk BuiltTool musl"
RB="build/soong/android/rule_builder.go"
if [ -f "$RB" ]; then
  python3 - "$RB" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = '''	if c.rule.ctx.Config().UseHostMusl() {'''
new = '''	if c.rule.ctx.Config().UseHostMusl() || c.rule.ctx.Config().BuildOS == LinuxMusl {'''
if "c.rule.ctx.Config().BuildOS == LinuxMusl" in s:
    print("    SKIP: rule_builder sudah dipatch")
elif old in s:
    s = s.replace(old, new, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("    OK  : rule_builder.go dipatch")
else:
    print("    WARN: anchor rule_builder tak cocok")
PY
else
  warn "$RB tidak ada"
fi

# =============================================================================
# PATCH 0004 — prebuilts/build-tools/Android.bp: bison/flex/m4/make arm64
#   (enable arm64 + target linux_musl_arm64)
# =============================================================================
step "0004" "prebuilts/build-tools/Android.bp: enable arm64 utk bison/flex/m4/make"
BT="prebuilts/build-tools/Android.bp"
if [ -f "$BT" ]; then
  python3 - "$BT" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if 'src: "linux-arm64/bin/' in s:
    print("    SKIP: build-tools arm64 sudah ada"); sys.exit(0)

names = ["bison", "flex", "m4", "make"]
count = 0
for n in names:
    # target linux_musl_arm64 sebelum blok 'linux: {'
    pat = re.compile(
        r'(\n        linux: \{\n            src: "linux-x86/bin/' + n + r'")')
    repl = ('\n        linux_musl_arm64: {\n'
            '            src: "linux-arm64/bin/' + n + '",\n'
            '            deps: ["linux-arm64/lib64/libc_musl.so"],\n'
            '        }' + r'\1')
    s2, k = pat.subn(repl, s, count=1)
    if k:
        s = s2; count += 1

# enable arm64 di blok arch x86_64 (pola berulang: '            enabled: true,\n        },\n    },')
pat2 = re.compile(r'(        x86_64: \{\n            enabled: true,\n        \},\n    \},)')
s, k2 = pat2.subn(
    '        x86_64: {\n            enabled: true,\n        },\n'
    '        arm64: {\n            enabled: true,\n        },\n    },', s)
count += k2

open(p, "w", encoding="utf-8").write(s)
print("    OK  : build-tools dipatch (target=%d, arch=%d)" % (count - k2, k2))
PY
else
  warn "$BT tidak ada"
fi

# =============================================================================
# PATCH 0003 — build/soong/rust/toolchain_library.go: prefix prebuilt sadar-host
#
#   Run #18 + dry-run membuktikan struktur Rust PixelOS sixteen BEDA TOTAL dari
#   AOSP-17 di blog. File ini hanya ~160 baris, TIDAK ada hostPrebuiltTargetProps,
#   TIDAK ada addPrebuiltToTarget, TIDAK ada linux-musl. Memaksakan patch model
#   blog di sini berisiko merusak tree.
#
#   Bug NYATA di tree ini cuma satu baris:
#       rustSetToolchainSource(): prefix := filepath.Join("linux-x86", ...)
#   -> di host aarch64 path jadi prebuilts/rust-toolchain/linux-x86/... padahal
#      toolchain arm64 kita ada di linux-arm64/... (Exec/No such file).
#
#   Fungsi lain (rustToolchainRustcPrebuiltFactory) SUDAH memakai
#   config.HostPrebuiltTag(ctx.Config()) -> jadikan ini konsisten, sekaligus
#   menghemat kode: tak perlu field/target baru.
# =============================================================================
step "0003" "soong/rust/toolchain_library.go: prefix prebuilt ikut host (linux-arm64)"
TL="build/soong/rust/toolchain_library.go"
if [ -f "$TL" ]; then
  python3 - "$TL" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

MARK = "# arm64-host: prefix prebuilt ikut host"
if MARK in s:
    print("    SKIP: sudah dipatch"); sys.exit(0)

old = '''		prefix := filepath.Join("linux-x86", GetRustPrebuiltVersion(ctx))'''
new = ('''		// arm64-host: prefix prebuilt ikut host (linux-arm64 di aarch64)''' + "\n"
       '''		prefix := filepath.Join(config.HostPrebuiltTag(ctx.Config()), GetRustPrebuiltVersion(ctx))''')

if old not in s:
    print("    WARN: anchor rustSetToolchainSource('linux-x86') tak cocok")
    sys.exit(0)

# pastikan import config sudah ada (memang sudah: dipakai fungsi rustc prebuilt)
if '"android/soong/rust/config"' not in s:
    print("    WARN: import 'android/soong/rust/config' hilang, patch dibatalkan")
    sys.exit(0)

s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
print("    OK  : rustSetToolchainSource pakai HostPrebuiltTag()")
PY
else
  warn "$TL tidak ada"
fi

# =============================================================================
# PATCH 0009 — TIDAK DITERAPKAN (sengaja)
#
#   Blog actinis.io memakai 0009 utk menambal "Rust sysroot double vision"
#   (E0464/E0460/E0152) pada AOSP-17. Setelah memeriksa
#   build/soong/rust/builder.go PixelOS sixteen (577 baris) secara langsung:
#
#   1. Premis blog SUDAH ditangani upstream: transformSrctoCrate() sendiri
#      sudah menambahkan  `rustcFlags = append(rustcFlags, "--sysroot=/dev/null")`
#      jadi sysroot implisit memang sengaja dimatikan; crate dicari lewat `-L`
#      (makeLibFlags -> deps.linkDirs).
#   2. Patch versi awal kita menyisipkan import "slices" pada anchor
#      'import (\n\t"path/filepath"\n\t"runtime"\n' — PADAHAL blok import nyata
#      di PixelOS sixteen adalah "path/filepath" lalu "strings" (TIDAK ada
#      "runtime"). Artinya import tak pernah masuk -> kode memakai
#      slices.DeleteFunc/(slices.Contains) GAGAL KOMPILASI.
#   3. Filter '.rust_sysroot/' & '/libstd/linux_musl_arm64' menargetkan link-dir
#      from-source yang HANYA muncul pada model patch 0003 versi LAMA (yang
#      sekarang sudah dibuang). Dengan 0003 baru (fix prefix prebuilt), tak ada
#      libstd from-source utk host, sehingga filter itu jadi no-op — sementara
#      pemasangan `rawDir` mentah berisiko mencampur sysroot prebuilt dgn crate
#      dari-source (justru memicu masalah yg mau dihindari).
#
#   Keputusan: JANGAN terapkan patch spekulatif yang belum terbukti & malah
#   tidak bisa dikompilasi. Biarkan run #19 mengungkap error Rust NYATA (kalau
#   ada) supaya kita menambal berdasarkan bukti, bukan dugaan. Rinciannya ada
#   di patches/arm64-host/README.md (tabel "tidak diterapkan").
# =============================================================================
step "0009" "soong/rust/builder.go: DILEWATI (tidak terbukti / premis sudah ada upstream)"
if [ -f "build/soong/rust/builder.go" ]; then
  skip "0009 tidak diterapkan — lihat komentar & README"
else
  warn "build/soong/rust/builder.go tidak ada"
fi

# =============================================================================
# TAMBAHAN — build/make/core/clang/config.mk: host arm64 pakai clang arm64
#   Baris asli men-hardcode 'linux-x86' utk LLVM_READOBJ & LLVM_RTLIB_PATH,
#   sehingga host arm64 akan mencoba menjalankan binary x86 -> Exec format error.
# =============================================================================
step "0002b" "core/clang/config.mk: pakai clang arm64 utk host arm64"
CLANGCFG="build/make/core/clang/config.mk"
if [ -f "$CLANGCFG" ]; then
  python3 - "$CLANGCFG" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "arm64-host" in s:
    print("    SKIP: clang/config.mk sudah dipatch"); sys.exit(0)
old = '''## Clang configurations.

LLVM_READOBJ := $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/bin/llvm-readobj

LLVM_RTLIB_PATH := $(LLVM_PREBUILTS_BASE)/linux-x86/$(LLVM_PREBUILTS_VERSION)/lib/clang/$(LLVM_RELEASE_VERSION)/lib/linux/
'''
new = '''## Clang configurations.

# arm64-host: pada host aarch64, Clang host ada di linux-arm64 (bukan linux-x86),
# karena menjalankan binary x86 di arm64 = "Exec format error".
ifeq ($(HOST_ARCH),arm64)
LLVM_HOST_PREBUILT_ARCH := arm64
else
LLVM_HOST_PREBUILT_ARCH := x86
endif

LLVM_READOBJ := $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-$(LLVM_HOST_PREBUILT_ARCH)/$(LLVM_PREBUILTS_VERSION)/bin/llvm-readobj

LLVM_RTLIB_PATH := $(LLVM_PREBUILTS_BASE)/linux-$(LLVM_HOST_PREBUILT_ARCH)/$(LLVM_PREBUILTS_VERSION)/lib/clang/$(LLVM_RELEASE_VERSION)/lib/linux/
'''
if old in s:
    s = s.replace(old, new, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("    OK  : clang/config.mk dipatch (LLVM_READOBJ + RTLIB_PATH arm64)")
else:
    print("    WARN: anchor clang/config.mk tak cocok")
PY
else
  warn "$CLANGCFG tidak ada"
fi

# =============================================================================
# PATCH 0005 — prebuilts/jdk/jdk21/Android.bp: enable javap utk host arm64
#   javap prebuilt_build_tool hanya x86; tambahkan arm64 + target linux_musl_arm64.
# =============================================================================
step "0005" "prebuilts/jdk/jdk21/Android.bp: enable javap utk arm64 host"
JDKBP="prebuilts/jdk/jdk21/Android.bp"
if [ -f "$JDKBP" ]; then
  python3 - "$JDKBP" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "linux_musl_arm64" in s:
    print("    SKIP: javap arm64 sudah ada"); sys.exit(0)
old = '''        x86_64: {
            enabled: true,
        },
    },
    target: {
        linux: {
            src: "linux-x86/bin/javap",'''
new = '''        x86_64: {
            enabled: true,
        },
        arm64: {
            enabled: true,
        },
    },
    target: {
        linux_musl_arm64: {
            src: "linux-arm64/bin/javap",
            deps: [
                "linux-arm64/lib/libjli.so",
                "linux-arm64/lib/jrt-fs.jar",
                "linux-arm64/lib/jvm.cfg",
                "linux-arm64/lib/server/libjvm.so",
                "linux-arm64/lib/libverify.so",
                "linux-arm64/lib/libjava.so",
                "linux-arm64/lib/libzip.so",
                "linux-arm64/lib/libjimage.so",
                "linux-arm64/lib/modules",
                "linux-arm64/lib/libnio.so",
                "linux-arm64/lib/libnet.so",
                "linux-arm64/lib/tzdb.dat",
                "linux-arm64/lib/libawt.so",
                "linux-arm64/lib/libawt_headless.so",
                "linux-arm64/lib/libjavajpeg.so",
                "linux-arm64/lib/liblcms.so",
                "linux-arm64/lib/libmanagement.so",
                "linux-arm64/lib/libmanagement_ext.so",
                "linux-arm64/conf/security/java.security",
            ],
        },
        linux: {
            src: "linux-x86/bin/javap",'''
if old in s:
    s = s.replace(old, new, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("    OK  : javap arm64 ditambahkan")
else:
    print("    WARN: anchor jdk21/Android.bp tak cocok")
PY
else
  warn "$JDKBP tidak ada"
fi

# =============================================================================
# PATCH 0012 — system/sepolicy: hasil getopt() disimpan dlm 'int', bukan 'char'
#   Di aarch64 plain char = unsigned -> sentinel -1 jadi 0xff -> parsing meleset.
# =============================================================================
step "0012" "system/sepolicy: getopt() -> int (bukan char) utk aarch64"
SEP_FILES="system/sepolicy/tools/checkfc.c
system/sepolicy/tools/sepolicy-analyze/attribute.c
system/sepolicy/tools/sepolicy-analyze/neverallow.c
system/sepolicy/tools/sepolicy-check.c"
for f in $SEP_FILES; do
  if [ ! -f "$f" ]; then warn "tidak ada: $f"; continue; fi
  if grep -qE '^\s*char (c|ch);' "$f"; then
    sed -i -E 's/^([[:space:]]*)char (c|ch);/\1int \2;/' "$f" \
      && ok "getopt int: $f" || warn "gagal: $f"
  else
    skip "sudah int / pola tak ada: $f"
  fi
done

# =============================================================================
# PATCH 0014 — build/soong/scripts/jar-wrapper.sh: default -Xmx8g utk tool host
#   metalava OOM pada host arm64 (heap JVM default). -J-Xmx... dari tool tetap menang.
# =============================================================================
step "0014" "soong/scripts/jar-wrapper.sh: default -Xmx8g utk java_binary_host"
JW="build/soong/scripts/jar-wrapper.sh"
if [ -f "$JW" ]; then
  if grep -qF 'exec java -Xmx8g' "$JW"; then
    skip "sudah dipatch: $JW"
  elif grep -qF 'exec java "${javaOpts[@]}" -jar ${jardir}/${jarfile} "$@"' "$JW"; then
    python3 - "$JW" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = 'exec java "${javaOpts[@]}" -jar ${jardir}/${jarfile} "$@"'
new = ('# arm64-host (#28): default max-heap supaya tool hemat (metalava) tidak OOM;\n'
       '# -J-Xmx... dari tool ditambahkan setelahnya dan menimpa (JVM pakai -Xmx terakhir).\n'
       'exec java -Xmx8g "${javaOpts[@]}" -jar ${jardir}/${jarfile} "$@"')
s = s.replace(old, new, 1)
open(p, "w", encoding="utf-8").write(s)
print("    OK  : jar-wrapper.sh dipatch")
PY
  else
    warn "anchor jar-wrapper tak cocok"
  fi
else
  warn "$JW tidak ada"
fi

# =============================================================================
# RINGKASAN + jejak verifikasi
# =============================================================================
echo ""
echo "=============================================================="
echo " RINGKASAN apply-arm64-host.sh"
echo "   langkah bermasalah (WARN): $FAILED"
echo "=============================================================="
echo "--- Verifikasi cepat ---"
grep -n "HOST_ARCH := arm64" build/make/core/envsetup.mk 2>/dev/null | head -2
grep -n "HOST_PREBUILT_ARCH := arm64" build/make/core/envsetup.mk 2>/dev/null | head -2
grep -n "linux-arm64" build/make/envsetup.sh 2>/dev/null | head -2
ls -la build/make/core/clang/HOST_arm64.mk 2>/dev/null
grep -c "linux-arm64" prebuilts/build-tools/Android.bp 2>/dev/null | sed 's/^/    build-tools linux-arm64 refs: /'
grep -n "prefix prebuilt ikut host" build/soong/rust/toolchain_library.go 2>/dev/null | head -3
grep -q 'filepath.Join("linux-x86", GetRustPrebuiltVersion' build/soong/rust/toolchain_library.go 2>/dev/null \
  && echo "    !! MASIH ada hardcode linux-x86 di rust toolchain_library.go" \
  || echo "    OK  : hardcode linux-x86 rust sudah hilang"
echo "--- tambahan ---"
grep -c "linux_musl_arm64" prebuilts/jdk/jdk21/Android.bp 2>/dev/null | sed 's/^/    jdk21 linux_musl_arm64 refs: /'
grep -n "^[[:space:]]*int c;" system/sepolicy/tools/checkfc.c 2>/dev/null | head -1
grep -n "Xmx8g" build/soong/scripts/jar-wrapper.sh 2>/dev/null | head -1
echo "=============================================================="

exit 0
