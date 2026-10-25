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
# Strategy: find lines that start a new module definition (identifier followed by {)
# and check if the previous non-empty line ends with }. If not, insert } before it.
lines = t.split('\n')
fixed = False
# Find module starts: lines matching pattern like "something {" or "something{"
module_starts = []
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped and '{' in stripped and not stripped.startswith('//') and not stripped.startswith('#'):
        # Check if this looks like a module definition start
        # Module definitions in Blueprint are like: module_type { or module_type{
        if re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*\s*\{', stripped):
            module_starts.append(i)

# Process from bottom to top
for idx in reversed(module_starts):
    # Find the previous non-empty line
    prev_idx = idx - 1
    while prev_idx >= 0 and lines[prev_idx].strip() == '':
        prev_idx -= 1
    if prev_idx >= 0 and not lines[prev_idx].rstrip().endswith('}'):
        # Insert } before this module start
        indent = lines[idx][:len(lines[idx]) - len(lines[idx].lstrip())]
        lines.insert(idx, indent + '}')
        fixed = True

if fixed:
    with open('prebuilts/build-tools/Android.bp', 'w') as f:
        f.write('\n'.join(lines))
    print('Fixed: added missing } before module definitions')
else:
    print('No fix needed for module definitions')
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
