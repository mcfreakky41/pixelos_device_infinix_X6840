#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build
# Jalankan dari root source tree (~/android/pixelos). Idempoten.
# Perangkat Infinix X6840 (MediaTek MT6768) tidak butuh ANY Qualcomm HAL.
# Semua direktori Qualcomm dihapus sepenuhnya supaya Soong tidak menemukan
# referensi namespace Qualcomm yang rusak.

echo ">>> Fixing broken hardware/qcom symlinks (generic)..."
# Symlink Android.bp yang rusak diganti stub supaya Soong tidak berhenti.
find hardware/qcom -name Android.bp -xtype l -print 2>/dev/null | while read -r bp; do
    echo "  Removing broken symlink: $bp"
    rm -f "$bp"
    echo "// Stub to satisfy soong (original symlink was broken)" > "$bp"
done

echo ">>> Removing ALL hardware/qcom/ directory (MediaTek, tidak butuh Qualcomm)..."
rm -rf hardware/qcom 2>/dev/null || true
echo "  hardware/qcom removed (if existed)"

echo ">>> Removing ALL hardware/qcom-caf/ directory (MediaTek, tidak butuh Qualcomm)..."
rm -rf hardware/qcom-caf 2>/dev/null || true
echo "  hardware/qcom-caf removed (if existed)"

echo ">>> Removing ALL vendor/qcom/ directory (MediaTek, tidak butuh Qualcomm)..."
rm -rf vendor/qcom 2>/dev/null || true
echo "  vendor/qcom removed (if existed)"

echo ">>> Fixing livedisplay undefined module references..."
# Log Soong: "depends on undefined module" (BUKAN duplikat). hardware/lineage/
# livedisplay (HIDL) butuh vendor.lineage.livedisplay@2.0, sedangkan repo
# interfaces (AIDL) hanya menyediakan vendor.lineage.livedisplay (V1/V2).
# Perangkat ini tidak punya HAL LiveDisplay, jadi implementasi HAL dinonaktifkan.
if [ -f hardware/lineage/livedisplay/sysfs/Android.bp ]; then
    mv hardware/lineage/livedisplay/sysfs/Android.bp hardware/lineage/livedisplay/sysfs/Android.bp.disabled
    echo "  Disabled: hardware/lineage/livedisplay/sysfs/Android.bp"
fi
if [ -f hardware/lineage/livedisplay/sdm/Android.bp ]; then
    mv hardware/lineage/livedisplay/sdm/Android.bp hardware/lineage/livedisplay/sdm/Android.bp.disabled
    echo "  Disabled: hardware/lineage/livedisplay/sdm/Android.bp"
fi
if [ -f hardware/lineage/livedisplay/legacymm/Android.bp ]; then
    mv hardware/lineage/livedisplay/legacymm/Android.bp hardware/lineage/livedisplay/legacymm/Android.bp.disabled
    echo "  Disabled: hardware/lineage/livedisplay/legacymm/Android.bp"
fi

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
if [ -f packages/apps/SimpleSettingsConfig/Android.bp ]; then
    mv packages/apps/SimpleSettingsConfig/Android.bp packages/apps/SimpleSettingsConfig/Android.bp.disabled
    echo "  Disabled: packages/apps/SimpleSettingsConfig/Android.bp"
fi

echo ">>> Source tree fixes applied."