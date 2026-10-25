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
# Strategy: find lines that are closing braces } (without comma) followed by
# an identifier: pattern (next entry in a map). Add comma after } if missing.
lines = t.split('\n')
fixed = False

# Pattern: a line ending with } (possibly with trailing whitespace) followed by
# a non-empty line starting with an identifier followed by :
for i in range(len(lines) - 1):
    line = lines[i].rstrip()
    # Only fix indented } (inside maps), not top-level module closing braces
    indent = len(lines[i]) - len(lines[i].lstrip())
    if indent > 0 and line.endswith('}') and not line.endswith(',}'):
        # Find next non-empty line
        j = i + 1
        while j < len(lines) and lines[j].strip() == '':
            j += 1
        if j < len(lines):
            next_line = lines[j].strip()
            # Check if next line starts with identifier followed by :
            if re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*\s*:', next_line):
                # Add comma after }
                lines[i] = line + ','
                fixed = True

if fixed:
    with open('prebuilts/build-tools/Android.bp', 'w') as f:
        f.write('\n'.join(lines))
    print('Fixed: added missing commas after } in map entries')
else:
    print('No fix needed for map entries')
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
