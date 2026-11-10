#!/usr/bin/env bash
# Fetch vendor blobs dari GitHub Release dan pasang ke vendor tree.
# Dijalankan otomatis oleh workflow build sebelum kompilasi.
#
# Variabel opsional:
#   BLOBS_REPO / BLOBS_TAG / BLOBS_BASE_URL  - ganti sumber unduhan
#   SKIP_BLOB_CHECK=1                        - lewati cek kelengkapan sumber blob
#   ALLOW_UNVERIFIED_BLOBS=1                 - izinkan lanjut bila SHA256SUMS tidak ada
#   ALLOW_MISSING_BLOBS=1                    - jangan gagal bila ada blob yang hilang
set -euo pipefail

REPO="${BLOBS_REPO:-mcfreakky41/pixelos_device_infinix_X6840}"
TAG="${BLOBS_TAG:-blobs-v1}"
BASE_URL="${BLOBS_BASE_URL:-https://github.com/${REPO}/releases/download/${TAG}}"
DEST="${1:-vendor/infinix/X6840/proprietary}"
VENDOR_DIR="$(dirname "$DEST")"

die() { echo "!! $*" >&2; exit 1; }

echo "=== Fetching vendor blobs ==="
echo "Repo: $REPO"
echo "Tag: $TAG"
echo "Destination: $DEST"

case "$DEST" in
    */proprietary) ;;
    *) die "DEST harus berakhir dengan '/proprietary' (didapat: $DEST)" ;;
esac

ARCHIVES=("X6840-vendor-blobs.tar.gz" "X6840-odm-blobs.tar.gz")

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for name in "${ARCHIVES[@]}"; do
    echo ">> Download ${name}"
    if ! curl -fSL --retry 5 --retry-delay 5 -o "${TMP}/${name}" "${BASE_URL}/${name}"; then
        echo "!! GAGAL download: ${name}"
        echo "   Pastikan release ${TAG} ada di https://github.com/${REPO}/releases"
        exit 1
    fi
done

# --- verifikasi integritas (WAJIB) ---
if curl -fsSL --retry 3 -o "${TMP}/SHA256SUMS" "${BASE_URL}/SHA256SUMS" 2>/dev/null; then
    echo ">> Verifikasi SHA256"
    for name in "${ARCHIVES[@]}"; do
        grep -qE "[[:space:]]\*?${name}$" "${TMP}/SHA256SUMS" \
            || die "SHA256SUMS tidak memuat entri untuk ${name}"
    done
    ( cd "$TMP" && sha256sum -c --ignore-missing SHA256SUMS ) \
        || die "Checksum blob TIDAK cocok — undangan rusak/dimanipulasi"
else
    if [ "${ALLOW_UNVERIFIED_BLOBS:-0}" = "1" ]; then
        echo "!! PERINGATAN: SHA256SUMS tidak ada; lanjut karena ALLOW_UNVERIFIED_BLOBS=1"
    else
        die "SHA256SUMS tidak ada di release ${TAG}.
   Buat: sha256sum ${ARCHIVES[*]} > SHA256SUMS lalu unggah ke release.
   Untuk memaksa lanjut tanpa verifikasi: ALLOW_UNVERIFIED_BLOBS=1"
    fi
fi

# --- pastikan arsip tidak berisi path absolut / keluar direktori ---
for name in "${ARCHIVES[@]}"; do
    if tar -tzf "${TMP}/${name}" | grep -qE '^/|(^|/)\.\.(/|$)'; then
        die "Arsip ${name} berisi path tidak aman (absolut atau '..')"
    fi
done

# --- bersihkan tujuan supaya file dari ekstraksi lama tidak tertinggal ---
echo ">> Membersihkan ${DEST}"
rm -rf "$DEST"
mkdir -p "$DEST"

for name in "${ARCHIVES[@]}"; do
    echo ">> Extract ${name} -> ${DEST}"
    tar -xzf "${TMP}/${name}" -C "$DEST"
done

echo ">> Blobs terpasang:"
du -sh "${DEST}"/* 2>/dev/null || echo "   (kosong atau tidak ada)"
echo "   Total files: $(find "$DEST" -type f | wc -l)"

# ============================================================
# Validasi kelengkapan blob
# Sumber kebenaran = X6840-vendor.mk
# ============================================================
if [ "${SKIP_BLOB_CHECK:-0}" != "1" ] && [ -f "${VENDOR_DIR}/X6840-vendor.mk" ]; then
    echo ">> Checking blob completeness"
    mapfile -t refs < <(
        grep -ohE 'proprietary/[^"[:space:]\\:]+' \
            "${VENDOR_DIR}/X6840-vendor.mk" \
            "${VENDOR_DIR}/Android.bp" 2>/dev/null \
        | sort -u
    )
    total=${#refs[@]}
    if [ "$total" -eq 0 ]; then
        die "Tidak ada path blob yang terbaca dari ${VENDOR_DIR}/X6840-vendor.mk."
    fi
    missing=0
    for p in "${refs[@]}"; do
        [ -n "$p" ] || continue
        if [ ! -e "${VENDOR_DIR}/${p}" ]; then
            echo "   MISSING: ${p}"
            missing=$((missing + 1))
        fi
    done
    present=$((total - missing))
    echo "   Referenced: ${total}, Present: ${present}, Missing: ${missing}"
    if [ "$missing" -gt 0 ]; then
        if [ "${ALLOW_MISSING_BLOBS:-0}" = "1" ]; then
            echo "!! PERINGATAN: ${missing} blob hilang, lanjut karena ALLOW_MISSING_BLOBS=1"
        else
            die "${missing} blob yang dirujuk X6840-vendor.mk tidak ada."
        fi
    fi

    # --- pemeriksaan tambahan (advisory): proprietary-files.txt ---
    if [ -f "${VENDOR_DIR}/proprietary-files.txt" ]; then
        pmissing=0
        while IFS= read -r line; do
            case "$line" in
                ''|'#'*) continue ;;
            esac
            line="${line#-}"
            p="${line%%;*}"
            p="$(printf '%s' "$p" | tr -d '[:space:]')"
            [ -n "$p" ] || continue
            case "$p" in
                vendor/etc/fstab.mt6768) continue ;;
            esac
            if [ ! -e "${VENDOR_DIR}/proprietary/${p}" ]; then
                echo "   WARN (proprietary-files.txt): tidak ada ${p}"
                pmissing=$((pmissing + 1))
            fi
        done < "${VENDOR_DIR}/proprietary-files.txt"
        echo "   proprietary-files.txt: ${pmissing} entri tidak ada di blob (advisory)"
    fi
fi

echo "=== Done ==="
