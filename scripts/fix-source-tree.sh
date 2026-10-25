#!/bin/bash
# Fix broken PixelOS sixteen source tree files before build
set -e
cd ~/android/pixelos

echo ">>> Fixing prebuilts/build-tools/Android.bp syntax error..."
if [ -f prebuilts/build-tools/Android.bp ]; then
    python3 << 'PYEOF'
import re
with open('prebuilts/build-tools/Android.bp', 'r') as f:
    t = f.read()
# Find all occurrences of 'name: "flex"'
matches = list(re.finditer(r'name: "flex"', t))
if matches:
    fixed = False
    lines = t.split('\n')
    # Process from bottom to top to maintain line numbers
    for m in reversed(matches):
        line_num = t[:m.start()].count('\n')
        if line_num > 0 and not lines[line_num - 1].rstrip().endswith('}'):
            lines[line_num] = '    }' + lines[line_num]
            fixed = True
    if fixed:
        with open('prebuilts/build-tools/Android.bp', 'w') as f:
            f.write('\n'.join(lines))
        print('Fixed: added } before flex module')
    else:
        print('No fix needed for flex module')
PYEOF
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
