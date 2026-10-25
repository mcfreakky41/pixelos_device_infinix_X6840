#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build

echo ">>> Fixing broken hardware/qcom symlinks (generic)..."
# Generic: find all broken symlinks named Android.bp under hardware/ and replace with stubs
find hardware -maxdepth 3 -name Android.bp -xtype l -print 2>/dev/null | while read -r bp; do
    echo "  Removing broken symlink: $bp"
    rm -f "$bp"
    echo "// Stub to satisfy soong (original symlink was broken)" > "$bp"
done

echo ">>> Fixing livedisplay HIDL/AIDL version mismatch..."
# hardware/lineage/livedisplay (HIDL) expects vendor.lineage.livedisplay@2.0
# but hardware/lineage/interfaces (AIDL) provides vendor.lineage.livedisplay
# Fix: change dependency to AIDL version that exists
for f in hardware/lineage/livedisplay/sysfs/Android.bp hardware/lineage/livedisplay/sdm/Android.bp; do
    if [ -f "$f" ]; then
        python3 - "$f" << 'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace('vendor.lineage.livedisplay@2.0', 'vendor.lineage.livedisplay')
open(p, "w", encoding="utf-8").write(s)
print("  Fixed:", p)
PYEOF
    fi
done

# frameworks/base expects V2.0-java and V2.1-java (HIDL)
# but interfaces provides V1-java and V2-java (AIDL)
# Fix: change to V2-java (AIDL version that exists)
if [ -f frameworks/base/Android.bp ]; then
    python3 - frameworks/base/Android.bp << 'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace('vendor.lineage.livedisplay-V2.0-java', 'vendor.lineage.livedisplay-V2-java')
s = s.replace('vendor.lineage.livedisplay-V2.1-java', 'vendor.lineage.livedisplay-V2-java')
open(p, "w", encoding="utf-8").write(s)
print("  Fixed:", p)
PYEOF
fi

echo ">>> Source tree fixes applied."