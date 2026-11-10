#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build.
# Jalankan dari root source tree (~/android/pixelos). Idempoten.

set -uo pipefail

ROOT="${1:-$PWD}"
cd "$ROOT" || { echo "FATAL: tidak bisa cd ke $ROOT"; exit 1; }

FAIL=0
ok()   { echo "  OK  : $1"; }
warn() { echo "  WARN: $1"; FAIL=$((FAIL+1)); }

# ============================================================
# 0. Pastikan direktori kerja benar-benar root source tree Android
# ============================================================
for marker in build/envsetup.sh build/make/core/main.mk build/soong; do
    if [ ! -e "$marker" ]; then
        echo "FATAL: '$ROOT' bukan root source tree Android (tidak ada $marker)."
        echo "       Jalankan dari ~/android/pixelos atau berikan path-nya sebagai argumen."
        exit 1
    fi
done
if [ ! -f device/infinix/X6840/device.mk ]; then
    echo "FATAL: device/infinix/X6840/device.mk tidak ada — tree ini bukan untuk X6840."
    exit 1
fi
ok "root source tree terdeteksi: $ROOT"

drop_dir() {
    local d="$1"
    case "$d" in
        ""|"/"|".")
            warn "menolak menghapus path berbahaya: '$d'"
            return
            ;;
    esac
    if [ -d "$d" ]; then
        local sz
        sz=$(du -sh "$d" 2>/dev/null | cut -f1)
        rm -rf -- "$d" && ok "dihapus: $d (${sz:-?})" || warn "gagal menghapus: $d"
    else
        ok "tidak ada (dilewati): $d"
    fi
}

# ============================================================
# 1. Qualcomm HAL — tidak dipakai platform MediaTek
# ============================================================
echo ">>> Membersihkan komponen Qualcomm (tidak dipakai MT6768)..."
if [ -d hardware/qcom ]; then
    find hardware/qcom -name Android.bp -xtype l -print 2>/dev/null | while read -r bp; do
        echo "  Removing broken symlink: $bp"
        rm -f "$bp"
        echo "// Stub to satisfy soong (original symlink was broken)" > "$bp"
    done
fi
drop_dir hardware/qcom
drop_dir hardware/qcom-caf
drop_dir vendor/qcom

# ============================================================
# 2. LiveDisplay (HIDL) — perangkat ini tidak punya HAL-nya
# ============================================================
echo ">>> Menonaktifkan livedisplay HIDL (tidak ada HAL di perangkat)..."
for d in sysfs sdm legacymm; do
    bp="hardware/lineage/livedisplay/$d/Android.bp"
    if [ -f "$bp" ]; then
        mv "$bp" "$bp.disabled"
        ok "disabled: $bp"
    elif [ -f "$bp.disabled" ]; then
        ok "sudah disabled: $bp"
    fi
done

if [ -f frameworks/base/Android.bp ]; then
    python3 - frameworks/base/Android.bp <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s2 = re.sub(r'[ \t]*"vendor\.lineage\.livedisplay-V2[^"]*",?[ \t]*\n?', '', s)
if s2 == s:
    print("  OK  : frameworks/base/Android.bp sudah bersih (tidak ada livedisplay-V2)")
elif "vendor.lineage.livedisplay-V2" in s2:
    print("  WARN: masih ada referensi livedisplay-V2 setelah patch")
    sys.exit(1)
else:
    open(p, "w", encoding="utf-8").write(s2)
    print("  OK  : referensi livedisplay-V2 dibuang dari frameworks/base/Android.bp")
PYEOF
    [ $? -eq 0 ] || warn "gagal patch frameworks/base/Android.bp"
fi

# ============================================================
# 3. SimpleSettingsConfig
# Modul ini bergantung pada org.lineageos.platform.internal (lineage-sdk),
# yang TIDAK ada di manifest PixelOS sixteen. Karena itu, perbaikan yang
# benar adalah MEMBUANG permintaan paket dari konfigurasi produk, bukan
# menonaktifkan definisi modul-nya.
# ============================================================
echo ">>> Memperbaiki SimpleSettingsConfig (butuh lineage-sdk yang tidak ada)..."

if [ -f packages/apps/SimpleSettingsConfig/Android.bp.disabled ] \
   && [ ! -f packages/apps/SimpleSettingsConfig/Android.bp ]; then
    mv packages/apps/SimpleSettingsConfig/Android.bp.disabled \
       packages/apps/SimpleSettingsConfig/Android.bp
    ok "dipulihkan: packages/apps/SimpleSettingsConfig/Android.bp"
fi

python3 - <<'PYEOF'
import glob, re, sys

changed = []
for path in glob.glob("vendor/aosp/**/*.mk", recursive=True):
    try:
        s = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        continue
    if "SimpleSettingsConfig" not in s:
        continue

    # Kasus paling umum: SimpleSettingsConfig adalah satu-satunya isi blok
    # 'PRODUCT_PACKAGES += \', jadi buang juga baris '+= \'.
    s2 = re.sub(
        r'^[ \t]*PRODUCT_PACKAGES[ \t]*\+=[ \t]*\\[ \t]*\r?\n'
        r'[ \t]*SimpleSettingsConfig[ \t]*\r?\n',
        '', s, flags=re.M)
    # Selain itu, hapus entri-nya saja dari daftar.
    s2 = re.sub(r'^[ \t]*SimpleSettingsConfig[ \t]*\\?[ \t]*\r?\n', '', s2, flags=re.M)
    # Rapikan backslash menggantung bila baris terakhir blok tadi dihapus.
    s2 = re.sub(r'\\[ \t]*\n([ \t]*#)', r'\n\1', s2)
    s2 = re.sub(r'\\[ \t]*\n([ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*[:+?]?=)', r'\n\1', s2)
    if s2 != s:
        open(path, "w", encoding="utf-8").write(s2)
        changed.append(path)

if changed:
    for p in changed:
        print(f"  OK  : SimpleSettingsConfig dihapus dari PRODUCT_PACKAGES ({p})")
else:
    print("  OK  : tidak ada permintaan SimpleSettingsConfig di vendor/aosp (sudah bersih)")

leftover = []
for path in glob.glob("vendor/aosp/**/*.mk", recursive=True):
    try:
        for i, ln in enumerate(open(path, encoding="utf-8"), 1):
            if re.fullmatch(r'[ \t]*SimpleSettingsConfig[ \t]*\r?\n?', ln):
                leftover.append(f"{path}:{i}")
    except (OSError, UnicodeDecodeError):
        continue
if leftover:
    print("  WARN: masih ada baris SimpleSettingsConfig: " + ", ".join(leftover))
    sys.exit(1)
PYEOF
[ $? -eq 0 ] || warn "masih ada permintaan SimpleSettingsConfig"

# ============================================================
# 4. vendor/aosp/build/soong/Android.bp — modul kernel headers bermuatan
#    Make tidak dipakai (perangkat memakai kernel prebuilt). Patch
#    SPESIFIK: hapus blok blok modul yang bermuatan Make, BUKAN men-disable
#    seluruh file blueprint.
# ============================================================
VBP="vendor/aosp/build/soong/Android.bp"
if [ -f "$VBP" ]; then
    python3 - "$VBP" <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
targets = [
    "custom_generator generated_kernel_includes",
    "custom_generator prebuilt_kernel_includes",
    "cc_defaults generated_kernel_header_defaults",
    "cc_defaults prebuilt_kernel_header_defaults",
    "cc_library_headers generated_kernel_headers",
    "cc_library_headers qti_kernel_headers",
    "cc_library_headers prebuilt_kernel_headers",
]
removed = []
for t in targets:
    kind, name = t.split(None, 1)
    pat = re.compile(r'(?ms)^' + re.escape(kind) + r' \{\n.*?\n\}\n')
    m = pat.search(s)
    if m:
        s = s[:m.start()] + s[m.end():]
        removed.append(t)
if removed:
    open(p, "w", encoding="utf-8").write(s)
    print("  OK  : modul bermuatan Make dihapus spesifik:")
    for r in removed:
        print("        - " + r)
elif '$(' in s:
    print("  WARN: masih ada Make variable di vendor/aosp/build/soong/Android.bp")
    sys.exit(1)
else:
    print("  OK  : tidak ada modul bermuatan Make yang perlu dihapus")
PYEOF
    [ $? -eq 0 ] || warn "gagal patch vendor/aosp/build/soong/Android.bp"
elif [ -f "$VBP.disabled" ]; then
    ok "sudah dipatch (versi sebelumnya): $VBP.disabled"
fi

# ============================================================
# 5. Verifikasi akhir (fail-closed)
# ============================================================
check_absent() { # desc, path
    if [ -e "$2" ]; then warn "masih ada: $2 ($1)"; else ok "$1"; fi
}

check_absent "hardware/qcom sudah hilang"      hardware/qcom
check_absent "hardware/qcom-caf sudah hilang"  hardware/qcom-caf
check_absent "vendor/qcom sudah hilang"        vendor/qcom

if [ -f frameworks/base/Android.bp ] \
   && grep -q "vendor.lineage.livedisplay-V2" frameworks/base/Android.bp; then
    warn "frameworks/base/Android.bp masih menyebut livedisplay-V2"
else
    ok "frameworks/base/Android.bp bersih dari livedisplay-V2"
fi

if grep -rqE '^[[:space:]]*SimpleSettingsConfig[[:space:]]*$' vendor/aosp --include='*.mk' 2>/dev/null; then
    warn "masih ada permintaan SimpleSettingsConfig di vendor/aosp"
else
    ok "tidak ada permintaan SimpleSettingsConfig di vendor/aosp"
fi

if [ "$FAIL" -gt 0 ]; then
    echo ">>> SELESAI DENGAN $FAIL MASALAH — periksa WARN di atas."
    exit 1
fi
echo ">>> Source tree fixes applied."
exit 0
