#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build
set -e
cd ~/android/pixelos

echo ">>> Fixing prebuilts/build-tools/Android.bp syntax error..."
if [ -f prebuilts/build-tools/Android.bp ]; then
    python3 -c "
import sys
with open('prebuilts/build-tools/Android.bp') as f: t=f.read()
if 'name: \"flex\"' in t and '    }\n    prebuilt_build_tool {\n        name: \"flex\"' not in t:
    t=t.replace('    }\n    prebuilt_build_tool {\n        name: \"flex\"', '    }\n    }\n    prebuilt_build_tool {\n        name: \"flex\"')
    open('prebuilts/build-tools/Android.bp','w').write(t)
    print('Fixed')
"
fi

echo ">>> Fixing broken hardware/qcom symlinks..."
for dir in hardware/qcom/sdm845 hardware/qcom/sm8150 hardware/qcom/sm7250; do
    bp="$dir/Android.bp"
    if [ -L "$bp" ]; then
        target=$(readlink "$bp")
        if [ ! -e "$dir/$target" ]; then
            echo "  Removing broken symlink: $bp -> $target"
            rm -f "$bp"
            echo "// Stub to satisfy soong (original symlink was broken)" > "$bp"
        fi
    fi
done
echo ">>> Source tree fixes applied."
