#!/usr/bin/env bash
# Fetch vendor blobs dari GitHub Release dan pasang ke vendor tree.
# Dijalankan otomatis oleh workflow build sebelum kompilasi.
#
# Variabel opsional:
#   BLOBS_REPO / BLOBS_TAG / BLOBS_BASE_URL  - ganti sumber unduhan
#   SKIP_BLOB_CHECK=1                        - lewati cek kelengkapan sumber blob
set -euo pipefail

REPO="${BLOBS_REPO:-mcfreakky41/pixelos_device_infinix_X6840}"
TAG="${BLOBS_TAG:-blobs-v1}"
BASE_URL="${BLOBS_BASE_URL:-https://github.com/${REPO}/releases/download/${TAG}}"
DEST="${1:-vendor/infinix/X6840/proprietary}"
VENDOR_DIR="$(dirname "$DEST")"

echo "=== Fetching vendor blobs ==="
echo "Repo: $REPO"
echo "Tag: $TAG"
echo "Destination: $DEST"

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ARCHIVES=("X6840-vendor-blobs.tar.gz" "X6840-odm-blobs.tar.gz")

for name in "${ARCHIVES[@]}"; do
    echo ">> Download ${name}"
    if ! curl -fSL --retry 5 --retry-delay 5 -o "${TMP}/${name}" "${BASE_URL}/${name}"; then
        echo "!! GAGAL download: ${name}"
        echo "   Pastikan release ${TAG} ada di https://github.com/${REPO}/releases"
        exit 1
    fi
done

# --- verifikasi integritas (bila release menyediakan SHA256SUMS) ---
if curl -fsSL --retry 3 -o "${TMP}/SHA256SUMS" "${BASE_URL}/SHA256SUMS" 2>/dev/null; then
    echo ">> Verifikasi SHA256"
    ( cd "$TMP" && sha256sum -c --ignore-missing SHA256SUMS )
else
    echo "!! SHA256SUMS tidak ada di release ${TAG}: unduhan TIDAK diverifikasi."
    echo "   Buat dengan: sha256sum ${ARCHIVES[*]} > SHA256SUMS lalu unggah ke release."
fi

for name in "${ARCHIVES[@]}"; do
    echo ">> Extract ${name} -> ${DEST}"
    tar -xzf "${TMP}/${name}" -C "$DEST"
done

echo ">> Blobs terpasang:"
du -sh "${DEST}"/* 2>/dev/null || echo "   (kosong atau tidak ada)"
echo "   Total files: $(find "$DEST" -type f | wc -l)"

# --- pastikan SEMUA sumber yang dirujuk build benar-benar ada ---
if [ "${SKIP_BLOB_CHECK:-0}" != "1" ] && [ -f "${VENDOR_DIR}/X6840-vendor.mk" ]; then
    echo ">> Checking blob completeness"
    missing=0
    list="$(grep -ohE 'proprietary/[^"[:space:]\\]' "${VENDOR_DIR}/X6840-vendor.mk" "${VENDOR_DIR}/Android.bp" 2>/dev/null | sort -u || echo "")"
    total=${#list}
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        missing=$((missing + 1))
        ! [ -e "${VENDOR_DIR}/${p}" ] && echo "   MISSING: ${p}"
    done <<< "$list"
    echo "   Referenced: ${total}, Present: $((total - missing))"
fi

echo "=== Done ==="