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
import re as RE, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s2 = RE.sub(r'[ \t]*"vendor\.lineage\.livedisplay-V2[^"]*",?[ \t]*\n?', '', s)
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

# Modul ini bergantung pada org.lineageos.platform.internal (lineage-sdk)
# yang TIDAK ada di manifest PixelOS sixteen. Permintaan paket sudah dibuang
# dari vendor/aosp (langkah 3 di atas); DEFINISI modulnya juga harus
# dinonaktifkan supaya Soong tidak menganalisis file yang melulu.
# Pelajaran run #148: hidupkan lagi file-nya = bootstrap gagal.
SSC_BP="packages/apps/SimpleSettingsConfig/Android.bp"
if [ -f "$SSC_BP" ]; then
    mv "$SSC_BP" "$SSC_BP.disabled" \
        && ok "SimpleSettingsConfig Android.bp dinonaktifkan" \
        || warn "gagal menonaktifkan SimpleSettingsConfig Android.bp"
elif [ -f "$SSC_BP.disabled" ]; then
    ok "SimpleSettingsConfig Android.bp sudah dinonaktifkan"
fi

python3 - <<'PYEOF'
import glob, re as RE, sys; M = RE.MULTILINE

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
    s2 = RE.sub(
        r'^[ \t]*PRODUCT_PACKAGES[ \t]*\+=[ \t]*\\[ \t]*\r?\n'
        r'[ \t]*SimpleSettingsConfig[ \t]*\r?\n',
        '', s, flags=M)
    # Selain itu, hapus entri-nya saja dari daftar.
    s2 = RE.sub(r'^[ \t]*SimpleSettingsConfig[ \t]*\\?[ \t]*\r?\n', '', s2, flags=M)
    # Rapikan backslash menggantung bila baris terakhir blok tadi dihapus.
    s2 = RE.sub(r'\\[ \t]*\n([ \t]*#)', r'\n\1', s2)
    s2 = RE.sub(r'\\[ \t]*\n([ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*[:+?]?=)', r'\n\1', s2)
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
            if RE.fullmatch(r'[ \t]*SimpleSettingsConfig[ \t]*\r?\n?', ln):
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
import re as RE, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
# Setiap entry: (module_type, [nama modul yang BERNAMA bermuatan Make])
targets = {
    "custom_generator": ["generated_kernel_includes", "prebuilt_kernel_includes"],
    "cc_defaults": ["generated_kernel_header_defaults", "prebuilt_kernel_header_defaults"],
    "cc_library_headers": ["generated_kernel_headers", "qti_kernel_headers", "prebuilt_kernel_headers"],
}
removed = []
for kind, names in targets.items():
    pat = RE.compile(r'(?ms)^' + RE.escape(kind) + r' \{\n.*?\n\}\n')
    ms = list(pat.finditer(s))
    if not ms:
        continue
    parts = []
    last = 0
    hit = False
    for m in ms:
        blk = m.group(0)
        nm = RE.search(r'name:\s*"([^"]+)"', blk)
        if nm and nm.group(1) in names:
            parts.append(s[last:m.start()])
            last = m.end()
            removed.append(kind + ":" + nm.group(1))
            hit = True
    parts.append(s[last:])
    s = "".join(parts)
    if not hit:
        print("  OK  : tidak ada blok " + kind + " bermuatan Make yang cocok")
if removed:
    open(p, "w", encoding="utf-8").write(s)
    print("  OK  : modul bermuatan Make dihapus spesifik:")
    for r in removed:
        print("        - " + r)
if '$(' in s:
    print("  WARN: masih ada Make variable di vendor/aosp/build/soong/Android.bp")
    sys.exit(1)
if not removed:
    print("  OK  : tidak ada modul bermuatan Make yang perlu dihapus")
PYEOF
    [ $? -eq 0 ] || warn "gagal patch vendor/aosp/build/soong/Android.bp"
elif [ -f "$VBP.disabled" ]; then
    ok "sudah dipatch (versi sebelumnya): $VBP.disabled"
fi

# ============================================================
# 4.5 framework test module (csuite_test) yang tidak dipakai build image
#     Perangkat memakai kernel prebuilt + image-only build, sehingga blok
#     test framework yang memakai module type custom "csuite_test" tidak
#     perlu ada. Patch blok-nya spesifik, bukan men-disable file.
# ============================================================
for F in \
    frameworks/base/libs/WindowManager/Shell/tests/flicker/pip/Android.bp \
    art/test/Android.bp; do
    if [ -f "$F" ]; then
        python3 - "$F" <<'PYEOF'
import re as RE, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
before = s
s2 = RE.sub(r'(?ms)^csuite_test \{\n.*?\n\}\n', '', s)
if s2 != before:
    open(p, "w", encoding="utf-8").write(s2)
    print(f"  OK  : blok csuite_test dihapus: {p}")
else:
    print(f"  OK  : tidak ada blok csuite_test: {p}")
PYEOF
        [ $? -eq 0 ] || warn "gagal patch test module: $F"
    else
        ok "tidak ada: $F (test module tidak ada di tree ini)"
    fi
done

# ============================================================
# 4.6 Hapus referensi ke module defaults test framework yang tidak
#     tersedia pada tree ini (cts_defaults, cts_support_defaults,
#     mts-target-sdk-version-current, tradefed_errorprone_defaults).
#     Soong bootstrap gagal bila ada modul yang bergantung pada module
#     tersebut. Patch ini spesifik: hanya string nama module yang
#     dibuang (baik entri multi-baris maupun inline), bukan file/dir.
# ============================================================
UNDEF_NAMES="tradefed_defaults|tradefed_errorprone_defaults|rdroidtest_defaults|rdroidtest\.defaults|MotionTestDefaults"
for d in build packages/modules tools frameworks external system art test platform_testing device vendor hardware prebuilts; do
    [ -d "$d" ] || continue
    while IFS= read -r F; do
        python3 - "$F" <<'PYEOF'
import re as RE, sys
p = sys.argv[1]
# Module types yang tidak tersedia karena repository yang dihapus:
# - package Testing (platform_testing) — tidak ada di tree ini
# - Kita tidak menghapus cts_* karena platform/cts sudah dipulihkan
UNDEF = ("tradefed_defaults", "tradefed_errorprone_defaults", "rdroidtest_defaults", 
         "rdroidtest.defaults", "MotionTestDefaults")
alt = "|".join(RE.escape(u) for u in UNDEF)
s = open(p, encoding="utf-8").read()
orig = s
# Hapus entry YANG BERADA DALAM defaults: atau dependencies:,
# bukan entry pada properti lain seperti name: "cts_defaults"
pat_inline = r'(defaults|dependencies)\s*:\s*\[([^\]]*(?:' + alt + r')[^\]]*)\]'
def repl_inline(m):
    arr = RE.findall(r'"([^"]+)"', m.group(2))
    arr = [x for x in arr if x not in UNDEF]
    if not arr: return m.group(1) + ': []'
    return m.group(1) + ': [' + ', '.join('"' + x + '"' for x in arr) + ']'
s = RE.sub(pat_inline, repl_inline, s)
pat_multi = r'(defaults|dependencies)\s*:\s*\[\s*\n(\s*)"(?:' + alt + r')"[ \t]*,\s*\n(\s*)\]'
s = RE.sub(pat_multi, r'\1: []', s)
if s != orig:
    open(p, "w", encoding="utf-8").write(s)
    print("  OK  : hapus referensi module tidak tersedia: " + p)
    # Verifikasi: periksa SELURUH isi array defaults/dependencies
    for arr in RE.finditer(r'(defaults|dependencies)\s*:\s*\[([^\]]*)\]', s):
        contents = arr.group(2)
        found = [x for x in RE.findall(r'"([^"]+)"', contents) if x in UNDEF]
        if found:
            print("  WARN: masih ada referensi module tidak tersedia: " + p)
            sys.exit(1)
PYEOF
        [ $? -eq 0 ] || warn "gagal bersihkan referensi module tidak tersedia: $F"
    done < <(grep -rl --include=Android.bp -E "\"(${UNDEF_NAMES})\"" "$d" 2>/dev/null || true)
done

# ============================================================
# 4.7 Nonaktifkan proyek pengujian yang tidak diperlukan
#     - device/google/cuttlefish sudah dihapus lelocal manifest
# ============================================================
echo ">>> Membersihkan proyek pengujian yang tidak diperlukan..."

# Cuttlefish sudah dihapus lewat local manifest
CTVF_ROOT="device/google/cuttlefish"
for p in "$CTVF_ROOT" "${CTVF_ROOT}.disabled"; do
    if [ -e "$p" ]; then
        echo ">>> Membersihkan sisa Cuttlefish: $p"
        rm -rf -- "$p" || warn "gagal membersihkan $p"
    fi
done
if [ -e "$CTVF_ROOT" ] || [ -e "${CTVF_ROOT}.disabled" ]; then
    warn "Cuttlefish masih tersisa dalam source tree"
else
    ok "Cuttlefish tidak ditemukan dalam source tree (dihapus local manifest)"
fi

# ============================================================
# 4.8 Nonaktifkan Cuttlefish Automotive Proxy.
# platform_testing tetap dipertahankan untuk sts_defaults,
# tetapi automotive proxy membutuhkan cuttlefish_base yang tidak ada.
# ============================================================

AUTO_BP="platform_testing/tools/automotive/proxy/Android.bp"
AUTO_DISABLED="${AUTO_BP}.disabled"

if [ -f "$AUTO_BP" ]; then
    if grep -q 'name: "automotive_vsock_proxy"' "$AUTO_BP" &&
       grep -q '"cuttlefish_base"' "$AUTO_BP"; then
        if mv "$AUTO_BP" "$AUTO_DISABLED"; then
            ok "Cuttlefish Automotive Proxy dinonaktifkan"
        else
            warn "Gagal menonaktifkan Automotive Proxy"
        fi
    else
        warn "Android.bp tidak sesuai dengan pola yang diharapkan"
    fi
elif [ -f "$AUTO_DISABLED" ]; then
    ok "Cuttlefish Automotive Proxy sudah dinonaktifkan"
else
    # File tidak ada — mungkin tidak diambil dalam sync
    ok "Cuttlefish Automotive Proxy tidak ada (tidak diperlukan)"
fi


# ============================================================
# 4.9 platform_testing: buang referensi test Cuttlefish yang
#     repo-nya (device/google/cuttlefish) tidak di-sync.
#     'platform_tests' adalah test_suites — tidak dipakai build image
#     device. Pelajaran run #149:
#       platform_testing/Android.bp:5 "platform_tests" depends on
#       undefined module "CuttlefishRilTests"/"CuttlefishWifiTests".
# ============================================================
echo ">>> Membuang referensi test Cuttlefish dari platform_testing..."
CUTTFILES=$(grep -rl --include=Android.bp -E '"(CuttlefishRilTests|CuttlefishWifiTests)"' platform_testing 2>/dev/null || true)
if [ -n "$CUTTFILES" ]; then
    while IFS= read -r F; do
        python3 - "$F" <<'PYEOF'
import re as RE, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
orig = s
cut = ("CuttlefishRilTests", "CuttlefishWifiTests")
# 1) entri array multi-baris: baris yang hanya berisi "Nama",
for c in cut:
    s = RE.sub(r'(?m)^[ \t]*"%s"[ \t]*,?[ \t]*\r?\n' % RE.escape(c), '', s)
# 2) entri array satu baris
for c in cut:
    s = RE.sub(r'[ \t]*"%s"[ \t]*,?' % RE.escape(c), '', s)
# rapikan sisa koma
s = RE.sub(r',\s*,', ',', s)
s = RE.sub(r'\[\s*,', '[', s)
s = RE.sub(r',\s*\]', ']', s)
if s != orig:
    open(p, "w", encoding="utf-8").write(s)
    print("  OK  : referensi Cuttlefish test dibuang dari", p)
else:
    print("  OK  : tidak ada referensi Cuttlefish test di", p)
PYEOF
        [ $? -eq 0 ] || warn "gagal bersihkan referensi Cuttlefish test: $F"
    done <<< "$CUTTFILES"
else
    ok "tidak ada referensi Cuttlefish test di platform_testing (sudah bersih)"
fi


# ============================================================
# 4.10 Virtualization (microdroid): buang referensi ke kernel
#      prebuilts x86-64 yang di-drop local manifest.
#      Pelajaran run #152: 'microdroid_gki-{15-6.6,16-6.12}_initrd_gen_x86_64'
#      butuh microdroid_gki_modules-*-x86_64 dari repo
#      kernel/prebuilts/{6.6,6.12}/x86-64 yang tidak di-sync.
#      Keduanya host-tool/VIRT microdroid x86_64 — tidak relevan
#      untuk build image device arm64. Hapus HANYA baris srcs-nya;
#      definisi modul tetap ada supaya tidak memicu error baru.
# ============================================================
echo ">>> Membuang referensi kernel prebuilt x86-64 dari Virtualization..."
KX_PAT='"(microdroid_gki_modules-android15-6.6-x86_64|microdroid_gki_modules-android16-6.12-x86_64)"'
if [ -d packages/modules/Virtualization ]; then
    KX_FILES=$(grep -rl --include=Android.bp -E "$KX_PAT" packages/modules/Virtualization 2>/dev/null || true)
    if [ -n "$KX_FILES" ]; then
        while IFS= read -r F; do
            python3 - "$F" <<'PYEOF'
import sys
p = sys.argv[1]
targets = ("microdroid_gki_modules-android15-6.6-x86_64",
           "microdroid_gki_modules-android16-6.12-x86_64")
lines = open(p, encoding="utf-8").read().split("\n")
out, removed = [], 0
for ln in lines:
    if any(('"%s"' % t) in ln for t in targets):
        removed += 1
        continue
    out.append(ln)
if removed:
    open(p, "w", encoding="utf-8").write("\n".join(out))
    print("  OK  : %d baris referensi kernel prebuilt x86-64 dibuang dari %s" % (removed, p))
else:
    print("  OK  : tidak ada referensi kernel prebuilt x86-64 di %s" % p)
PYEOF
            [ $? -eq 0 ] || warn "gagal bersihkan referensi kernel prebuilt x86-64: $F"
        done <<< "$KX_FILES"
    else
        ok "tidak ada referensi kernel prebuilt x86-64 di Virtualization"
    fi
else
    ok "packages/modules/Virtualization tidak ada (dilewati)"
fi

# ============================================================
# 5. Verifikasi akhir (fail-closed)
# ============================================================
check_absent() { # desc, path
    if [ -e "$2" ]; then warn "masih ada: $2 ($1)"; else ok "$1"; fi
}

check_absent "SimpleSettingsConfig bp dinonaktifkan" packages/apps/SimpleSettingsConfig/Android.bp
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
