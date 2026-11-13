#!/bin/bash
# Diagnostik kegagalan Soong bootstrap: modul/variabel undefined.
#
# Latar belakang: workflow memakai local manifest (drop-unused-arm64.xml)
# yang membuang beberapa project supaya hemat disk. Soong menganalisis SEMUA
# Android.bp yang ter-sync; kalau satu file yang tersisa mereferensikan modul
# dari repo yang dibuang, bootstrap gagal ("depends on undefined module").
# Skrip ini membaca build.log, mengekstrak modul/variabel yang undefined,
# mencari di mana definisinya (kalau masih ada), dan mengeceknya terhadap
# daftar remove-project di workflow — supaya tidak perlu menebak-nebak.
#
# Pakai:  diagnose-undefined-mods.sh [path/build.log]
# Harness (workflow):  bash .../scripts/diagnose-undefined-mods.sh build.log

set -uo pipefail

LOG="${1:-build.log}"
ROOT="${2:-$PWD}"
cd "$ROOT" || { echo "FATAL: tidak bisa cd ke $ROOT"; exit 1; }
[ -f "$LOG" ] || { echo "FATAL: '$LOG' tidak ada"; exit 1; }

# Lokasi file workflow (untuk baca daftar remove-project)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WF_LOCAL="$SCRIPT_DIR/../.github/workflows/build.yml"
[ -f "$WF_LOCAL" ] || WF_LOCAL=""

echo "=== DIAGNOSA BUILD FAILURE: $LOG ==="
echo

# Tabel modul yang dikenal -> repo manifest tempat definisinya.
# (Hanya modul yang sudah pernah diverifikasi; sisanya dicari otomatis.)
known_repo() {
    case "$1" in
        robolectric-host-android_all)      echo "platform/external/robolectric" ;;
        robolectric-android-all-prebuilts) echo "prebuilts/misc/common/robolectric" ;;
        libvts_vintf_test_common)          echo "platform/test/vts" ;;
        vndk_utils)                        echo "platform/test/vts" ;;
        vts_kernel_utils)                  echo "platform/test/vts" ;;
        vts_vndk_utils)                    echo "platform/test/vts" ;;
        *)                                 echo "" ;;
    esac
}

# Heuristik: kata kunci dari nama modul vs nama repo di remove-project.
# Modul 'xxx_vts_yyy' kemungkinan besar didefinisikan di repo yang mengandung
# kata 'vts'. Cetak kandidat supaya tidak perlu menebak manual.
candidate_repos() {
    local m="$1" lower kw
    lower=$(echo "$m" | tr 'A-Z_' 'a-z ')
    for kw in $lower; do
        case "$kw" in
            vts|vintf|vndk|robolectric|cts|mts|tradefed|asuite|catbox|csuite) ;;
            *) continue ;;
        esac
        if [ -n "$WF_LOCAL" ]; then
            grep -oE "remove-project name=\"[^\"]*$kw[^\"]*\"" "$WF_LOCAL" 2>/dev/null
        fi
    done | sort -u
}

# ---------------------------------------------------------------
# 1. Ekstrak error "undefined module"
# ---------------------------------------------------------------
MODS=$(grep -oE 'depends on undefined module "[^"]+"' "$LOG" \
        | sed -E 's/.*module "([^"]+)"/\1/' | sort -u)

if [ -n "$MODS" ]; then
    echo ">>> MODUL UNDEFINED:"
    for m in $MODS; do
        echo "    - $m"
    done
    echo
    for m in $MODS; do
        echo "--- $m ---"
        # Cari definisi di source tree (butuh beberapa detik, tree besar)
        def=$(grep -rl --include=Android.bp -E "name:[[:space:]]+\"$m\"" . 2>/dev/null | head -5)
        if [ -n "$def" ]; then
            echo "    definisi DITEMUKAN di tree:"
            echo "$def" | sed 's/^/        /'
            echo "    => masalah BUKAN repo hilang; periksa patch/penghapusan di file tsb."
        else
            echo "    definisi TIDAK ADA di tree (repo-nya mungkin di-drop local manifest)."
            kr=$(known_repo "$m")
            [ -n "$kr" ] && echo "    repo definisi (terverifikasi): $kr"
            if [ -z "$kr" ]; then
                cand=$(candidate_repos "$m")
                if [ -n "$cand" ]; then
                    echo "    kandidat repo (heuristik kata kunci):"
                    echo "$cand" | sed 's/^/        /'
                    echo "    => kalau cocok, HAPUS baris remove-project tsb dari build.yml."
                fi
            fi
            if [ -n "$WF_LOCAL" ]; then
                if grep -q "remove-project name=\"$kr\"" "$WF_LOCAL" 2>/dev/null; then
                    echo "    !!! $kr MASIH ada di remove-project build.yml -> HAPUS baris itu."
                else
                    echo "    (repo $kr sudah tidak di remove-project; cari repo lain yang define '$m')"
                fi
            fi
        fi
    done
    echo
fi

# ---------------------------------------------------------------
# 2. Ekstrak error "undefined variable" (Make-variable bocor ke .bp)
# ---------------------------------------------------------------
VARS=$(grep -oE 'undefined variable [A-Za-z0-9_]+' "$LOG" \
        | sed -E 's/undefined variable //' | sort -u)

if [ -n "$VARS" ]; then
    echo ">>> VARIABEL UNDEFINED (biasanya Make-variable bocor ke Android.bp):"
    for v in $VARS; do
        echo "    - $v"
        hit=$(grep -rl --include=Android.bp -E "\$\($v\)|\\\$\{$v\}" . 2>/dev/null | head -5)
        if [ -n "$hit" ]; then
            echo "      dipakai di:"
            echo "$hit" | sed 's/^/          /'
        fi
    done
    echo
fi

# ---------------------------------------------------------------
# 3. Ekstrak error "unrecognized module type"
# ---------------------------------------------------------------
TYPES=$(grep -oE 'unrecognized module type "[^"]+"' "$LOG" \
        | sed -E 's/.*type "([^"]+)"/\1/' | sort -u)

if [ -n "$TYPES" ]; then
    echo ">>> MODULE TYPE TIDAK DIKENAL (repo pemilik type di-drop?):"
    for t in $TYPES; do
        echo "    - $t"
    done
    echo
fi

# ---------------------------------------------------------------
# 4. Ringkasan remove-project aktif di workflow
# ---------------------------------------------------------------
if [ -n "$WF_LOCAL" ]; then
    echo ">>> remove-project AKTIF di workflow (calon sumber modul undefined):"
    grep -oE 'remove-project name="[^"]+"' "$WF_LOCAL" | sed 's/^/        /'
    echo
fi

echo "=== SELESAI DIAGNOSA (informatif, tidak menggagalkan job) ==="
exit 0