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
VENDOR_DIR="$(dirname "$DEST")"          # vendor/infinix/X6840

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ARCHIVES=("X6840-vendor-blobs.tar.gz" "X6840-odm-blobs.tar.gz")

for name in "${ARCHIVES[@]}"; do
    echo ">> Download ${name}"
    curl -fSL --retry 5 --retry-delay 5 -o "${TMP}/${name}" "${BASE_URL}/${name}"
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
du -sh "${DEST}"/* 2>/dev/null || true
find "$DEST" -type f | wc -l

# --- pastikan SEMUA sumber yang dirujuk build benar-benar ada ---
# vendor.mk (PRODUCT_COPY_FILES) dan Android.bp merujuk proprietary/<path>.
# Sumber hilang baru ketahuan di tahap Ninja ("No rule to make target"),
# jadi cek di sini supaya tidak membuang waktu build.
if [ "${SKIP_BLOB_CHECK:-0}" != "1" ] && [ -f "${VENDOR_DIR}/X6840-vendor.mk" ]; then
    echo ">> Cek kelengkapan sumber blob"
    missing=0
    list="$(cat "${VENDOR_DIR}"/X6840-vendor.mk "${VENDOR_DIR}"/Android.bp 2>/dev/null \
              | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*//' \
              | grep -oE 'proprietary/[^:" \\]+' | sort -u || true)"
    total=0
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        total=$((total + 1))
        if [ ! -e "${VENDOR_DIR}/${p}" ]; then
            missing=$((missing + 1))
            [ "$missing" -le 20 ] && echo "   HILANG: ${p}"
        fi
    done <<< "$list"
    echo "   dirujuk: ${total}, hilang: ${missing}"
    if [ "$missing" -gt 0 ]; then
        echo "!! ${missing} sumber blob hilang (mis. vendor_dlkm/odm_dlkm tidak ada di tarball?)."
        echo "   Perbaiki tarball release, atau set SKIP_BLOB_CHECK=1 bila disengaja."
        exit 1
    fi
fi
