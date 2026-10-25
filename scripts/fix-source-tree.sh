#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build

echo ">>> Fixing broken hardware/qcom symlinks (generic)..."
# Generic: find all broken symlinks named Android.bp under hardware/ and replace with stubs
find hardware -maxdepth 3 -name Android.bp -xtype l -print 2>/dev/null | while read -r bp; do
    echo "  Removing broken symlink: $bp"
    rm -f "$bp"
    echo "// Stub to satisfy soong (original symlink was broken)" > "$bp"
done
echo ">>> Source tree fixes applied."