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
#   (patch 0001-0009). Skrip ini menerapkan padanannya + drop prebuilt arm64.
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

# (a2) tutup 'endif' tambahan pada blok 32-bit
old_tail = '''ifneq (,$(findstring i686,$(UNAME)))$(findstring x86,$(UNAME)))
$(error Building on a 32-bit x86 host is not supported: $(UNAME)!)
endif
endif
'''
new_tail = '''ifneq (,$(findstring i686,$(UNAME)))$(findstring x86,$(UNAME)))
$(error Building on a 32-bit x86 host is not supported: $(UNAME)!)
endif
endif
endif
'''
if "HOST_ARCH := arm64" in s and old_tail in s:
    s = s.replace(old_tail, new_tail, 1); changed = True
    print("    OK  : endif penutup ditambahkan")

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
# PATCH 0003 — build/soong/rust/toolchain_library.go: libstd linux_musl_arm64
# =============================================================================
step "0003" "soong/rust/toolchain_library.go: prebuilt libstd utk linux_musl_arm64"
TL="build/soong/rust/toolchain_library.go"
if [ -f "$TL" ]; then
  python3 - "$TL" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
changed = False

a_old = '''		Linux_musl_x86_64  hostPrebuiltTargetProps
		Linux_musl_x86     hostPrebuiltTargetProps
'''
a_new = '''		Linux_musl_x86_64  hostPrebuiltTargetProps
		Linux_musl_x86     hostPrebuiltTargetProps
		Linux_musl_arm64   hostPrebuiltTargetProps
'''
if "Linux_musl_arm64   hostPrebuiltTargetProps" in s:
    print("    SKIP: field Linux_musl_arm64 sudah ada")
elif a_old in s:
    s = s.replace(a_old, a_new, 1); changed = True
    print("    OK  : field Linux_musl_arm64 ditambahkan")
else:
    print("    WARN: anchor field struct tak cocok")

b_old = '''		} else if platform == "linux-musl-x86" && ctx.Config().BuildOS == android.LinuxMusl {'''
b_new = '''		} else if platform == "linux-musl-x86" && ctx.Config().BuildOS == android.LinuxMusl && ctx.Config().BuildArch == android.X86_64 {'''
if "&& ctx.Config().BuildArch == android.X86_64" in s:
    print("    SKIP: guard BuildArch x86_64 sudah ada")
elif b_old in s:
    s = s.replace(b_old, b_new, 1); changed = True
    print("    OK  : guard BuildArch x86_64 ditambahkan")
else:
    print("    WARN: anchor linux-musl-x86 tak cocok")

c_anchor = '''			p.Target.Linux_musl_x86.addPrebuiltToTarget(ctx, name, rustDir, "linux-musl-x86", "i686-unknown-linux-musl", rlib, solib)
'''
c_add = c_anchor + '''		} else if platform == "linux-arm64" && ctx.Config().BuildOS == android.LinuxMusl && ctx.Config().BuildArch == android.Arm64 {
			p.Target.Linux_musl_arm64.addPrebuiltToTarget(ctx, name, rustDir, "linux-arm64", "aarch64-unknown-linux-musl", rlib, solib)
'''
if 'platform == "linux-arm64"' in s:
    print("    SKIP: cabang linux-arm64 sudah ada")
elif c_anchor in s:
    s = s.replace(c_anchor, c_add, 1); changed = True
    print("    OK  : cabang linux-arm64 ditambahkan")
else:
    print("    WARN: anchor addPrebuiltToTarget musl-x86 tak cocok")

if changed:
    open(p, "w", encoding="utf-8").write(s)
PY
else
  warn "$TL tidak ada"
fi

# =============================================================================
# PATCH 0009 — build/soong/rust/builder.go: pin staticlib ke sysroot prebuilt
# =============================================================================
step "0009" "soong/rust/builder.go: pin staticlib host arm64 ke sysroot prebuilt"
RBB="build/soong/rust/builder.go"
if [ -f "$RBB" ]; then
  python3 - "$RBB" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "#22): proc_macro is prebuilt-only" in s:
    print("    SKIP: builder.go sudah dipatch"); sys.exit(0)

if '"slices"' not in s:
    s = s.replace('import (\n\t"path/filepath"\n\t"runtime"\n',
                  'import (\n\t"path/filepath"\n\t"runtime"\n\t"slices"\n', 1)

anchor = '''	mod := ctx.Module().(cc.LinkableInterface)
	toolchain := config.FindToolchain(ctx.Os(), ctx.Arch())
'''
add = anchor + '''
	if ctx.Host() && ctx.Arch().ArchType.String() == "arm64" {
		// all-prebuilt (#22): proc_macro prebuilt-only & terikat SVH prebuilt std/core.
		// Buang link-dir/rlib from-source, lalu pin sysroot prebuilt mentah.
		rustPathDeps.linkDirs = slices.DeleteFunc(rustPathDeps.linkDirs, func(d string) bool {
			return strings.Contains(d, ".rust_sysroot/") || strings.Contains(d, "/libstd/linux_musl_arm64")
		})
		rustPathDeps.RLibs = slices.DeleteFunc(rustPathDeps.RLibs, func(l RustLibrary) bool {
			p := l.Path.String()
			return strings.Contains(p, ".rust_sysroot") || strings.Contains(p, "/libstd/linux_musl_arm64")
		})
		rawDir := filepath.Join("prebuilts/rust-toolchain", ctx.Config().PrebuiltOS(),
			config.RustDefaultVersion, "lib/rustlib", toolchain.RustTriple(), "lib")
		if !slices.Contains(rustPathDeps.linkDirs, rawDir) {
			rustPathDeps.linkDirs = append(rustPathDeps.linkDirs, rawDir)
		}
	}
'''
if anchor in s:
    s = s.replace(anchor, add, 1)
    open(p, "w", encoding="utf-8").write(s)
    print("    OK  : builder.go dipatch")
else:
    print("    WARN: anchor builder.go tak cocok")
PY
else
  warn "$RBB tidak ada"
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
grep -n "Linux_musl_arm64" build/soong/rust/toolchain_library.go 2>/dev/null | head -3
echo "=============================================================="

exit 0
