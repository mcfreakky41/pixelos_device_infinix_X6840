#!/usr/bin/env bash
# Fetch vendor blobs dari GitHub Release dan pasang ke vendor tree.
# Dijalankan otomatis oleh workflow build sebelum kompilasi.
set -euo pipefail

REPO="mcfreakky41/pixelos_device_infinix_X6840"
TAG="blobs-v1"
DEST="${1:-vendor/infinix/X6840/proprietary}"

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
    local name="$1"
    local url="https://github.com/${REPO}/releases/download/${TAG}/${name}"
    echo ">> Download ${name}"
    curl -fSL --retry 5 --retry-delay 5 -o "${TMP}/${name}" "$url"
    echo ">> Extract ${name} -> ${DEST}"
    tar -xzf "${TMP}/${name}" -C "$DEST"
}

fetch "X6840-vendor-blobs.tar.gz"
fetch "X6840-odm-blobs.tar.gz"

echo ">> Blobs terpasang:"
du -sh "${DEST}"/* 2>/dev/null || true
find "$DEST" -type f | wc -l
