#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build

echo ">>> Fixing broken hardware/qcom symlinks (generic)..."
# Generic: find all broken symlinks named Android.bp under hardware/ and replace with stubs
find hardware -maxdepth 3 -name Android.bp -xtype l -print 2>/dev/null | while read -r bp; do
    echo "  Removing broken symlink: $bp"
    rm -f "$bp"
    echo "// Stub to satisfy soong (original symlink was broken)" > "$bp"
done

echo ">>> Fixing livedisplay undefined module references..."
# livedisplay service repos (HIDL) reference vendor.lineage.livedisplay@2.0
# but interfaces repo (AIDL) provides vendor.lineage.livedisplay (no @2.0)
# Since device tree doesn't use livedisplay, disable service implementations.
for dir in hardware/lineage/livedisplay/sysfs hardware/lineage/livedisplay/sdm hardware/lineage/livedisplay/legacymm; do
    if [ -f "$dir/Android.bp" ]; then
        mv "$dir/Android.bp" "$dir/Android.bp.disabled"
        echo "  Disabled: $dir/Android.bp"
    fi
done

# frameworks/base references V2.0-java and V2.1-java (HIDL versions)
# but interfaces repo provides V1-java and V2-java (AIDL versions)
# Fix: change V2.0-java -> V2-java, and remove V2.1-java entry (to avoid duplicate)
if [ -f frameworks/base/Android.bp ]; then
    python3 - frameworks/base/Android.bp << 'PYEOF'
import sys, re
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace('vendor.lineage.livedisplay-V2.0-java', 'vendor.lineage.livedisplay-V2-java')
# Remove duplicate V2.1-java entry (V2.0 already became V2-java)
s = re.sub(r'\n[ \t]*"vendor\.lineage\.livedisplay-V2\.1-java",?', '', s)
open(p, "w", encoding="utf-8").write(s)
print("  Fixed:", p)
PYEOF
fi

echo ">>> Fixing SimpleSettingsConfig undefined dependency..."
# SimpleSettingsConfig depends on org.lineageos.platform.internal which doesn't exist
# Disable the module since device tree doesn't use it
if [ -f packages/apps/SimpleSettingsConfig/Android.bp ]; then
    mv packages/apps/SimpleSettingsConfig/Android.bp packages/apps/SimpleSettingsConfig/Android.bp.disabled
    echo "  Disabled: packages/apps/SimpleSettingsConfig/Android.bp"
fi



echo ">>> Disabling Qualcomm-only VibratorCL (tidak dipakai di MediaTek)..."
# VibratorCL depends on libspf-headers, libarosal_headers, libpalclient
# which only exist in Qualcomm CAF namespaces, not on MediaTek MT6768
bp=vendor/qcom/opensource/vibrator/aidl/VibratorCL/Android.bp
if [ -f "$bp" ]; then
    mv "$bp" "$bp.disabled"
    echo "  Disabled: $bp"
fi



echo ">>> Disabling Qualcomm Vibrator aidl (depends on VibratorCL)..."
bp=vendor/qcom/opensource/vibrator/aidl/Android.bp
if [ -f "$bp" ]; then
    mv "$bp" "$bp.disabled"
    echo "  Disabled: $bp"
fi

echo ">>> Source tree fixes applied."