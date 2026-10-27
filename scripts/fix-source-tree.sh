#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build
# Jalankan dari root source tree (~/android/pixelos). Idempoten.

disable_bp() {
    # $1 = path Android.bp, $2 = alasan singkat
    if [ -f "$1" ]; then
        mv "$1" "$1.disabled"
        echo "  Disabled: $1  ($2)"
    else
        echo "  (lewati, tidak ada / sudah nonaktif: $1)"
    fi
}

echo ">>> Fixing broken hardware/qcom symlinks (generic)..."
# Symlink Android.bp yang rusak (mis. hardware/qcom/*/Android.bp -> gps/os_pickup.bp)
# diganti stub supaya Soong tidak berhenti.
find hardware/qcom -name Android.bp -xtype l -print 2>/dev/null | while read -r bp; do
    echo "  Removing broken symlink: $bp"
    rm -f "$bp"
    echo "// Stub to satisfy soong (original symlink was broken)" > "$bp"
done

echo ">>> Disabling all Qualcomm HAL modules (MediaTek tidak butuh HAL Qualcomm)..."
# Semua Android.bp di hardware/qcom/ dan hardware/qcom-caf/ untuk Qualcomm-only HAL.
# Perangkat MediaTek MT6768 tidak butuh modul Qualcomm.
find hardware/qcom -name Android.bp -type f 2>/dev/null | while read -r bp; do
    disable_bp "$bp" "Qualcomm HAL, tidak dipakai di MediaTek"
done

echo ">>> Fixing livedisplay undefined module references..."
# Log Soong: "depends on undefined module" (BUKAN duplikat). hardware/lineage/
# livedisplay (HIDL) butuh vendor.lineage.livedisplay@2.0, sedangkan repo
# interfaces (AIDL) hanya menyediakan vendor.lineage.livedisplay (V1/V2).
# Perangkat ini tidak punya HAL LiveDisplay, jadi implementasi HAL dinonaktifkan.
disable_bp hardware/lineage/livedisplay/sysfs/Android.bp "HAL HIDL livedisplay tidak dipakai"
disable_bp hardware/lineage/livedisplay/sdm/Android.bp   "HAL HIDL livedisplay tidak dipakai"
disable_bp hardware/lineage/livedisplay/legacymm/Android.bp "HAL HIDL livedisplay tidak dipakai"

# frameworks/base menyebut vendor.lineage.livedisplay-V2.0-java dan
# vendor.lineage.livedisplay-V2.1-java (HIDL); yang ada di tree hanyalah
# vendor.lineage.livedisplay-V1-java dan -V2-java (AIDL).
# Karena perangkat ini tidak pakai livedisplay, buang semua referensi
# livedisplay-V2-* dari frameworks/base/Android.bp.
if [ -f frameworks/base/Android.bp ]; then
    python3 - frameworks/base/Android.bp << 'PYEOF'
import sys, re
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
# Hapus semua entri livedisplay-V2-* (V2.0-java, V2.1-java, V2-java)
s = re.sub(r'[ \t]*"vendor\.lineage\.livedisplay-V2[^\"]*",?[ \t]*\n?', '', s)
open(p, "w", encoding="utf-8").write(s)
print("  Fixed:", p)
PYEOF
fi

echo ">>> Fixing SimpleSettingsConfig undefined dependency..."
# Bergantung pada org.lineageos.platform.internal (Lineage SDK) yang tidak ada di tree ini.
disable_bp packages/apps/SimpleSettingsConfig/Android.bp "butuh org.lineageos.platform.internal"

echo ">>> Cek referensi ke modul yang dinonaktifkan (PRODUCT_PACKAGES dll.)..."
# Kalau makefile produk masih memasukkan modul yang sudah dinonaktifkan, Kati/Ninja
# akan gagal belakangan. Hanya melapor, tidak mengubah apa pun.
for name in vendor.qti.hardware.vibratorCL SimpleSettingsConfig 'vendor.lineage.livedisplay@2.0-service' vendor.qti.hardware.display.composer-service; do
    hits=$(grep -rIl --include='*.mk' --include='Android.mk' --include='Android.bp' --include='*.xml' \
              -e "$name" vendor device build packages hardware 2>/dev/null | head -5)
    if [ -n "$hits" ]; then
        echo "  PERINGATAN: '$name' masih direferensikan di:"
        echo "$hits" | sed 's/^/      /'
    else
        echo "  OK: tidak ada referensi ke '$name'"
    fi
done

echo ">>> Source tree fixes applied."