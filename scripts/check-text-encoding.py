#!/usr/bin/env python3
"""Guard encoding file teks sebelum build (BOM / CRLF).

Alasan: file .mk yang diawali UTF-8 BOM membuat GNU make gagal parse dengan
    "vendor/infinix/X6840/X6840-vendor.mk:1: error: missing separator."
karena byte BOM menyatu ke token pertama sehingga '#' tidak lagi dibaca
sebagai awal komentar. Mengeceknya hanya setelah sync + build whole-tree
membazirkan puluhan menit, jadi periksa lebih awal di sini.

Pemeriksaan dilakukan per-byte (bukan lewat grep/sed) supaya hasilnya
deterministik di Linux CI maupun di Windows.

Exit non-zero kalau ada file kritis yang punya BOM atau CRLF.
"""

import os
import sys

BOM = b"\xef\xbb\xbf"

CRITICAL_EXTS = {
    ".mk", ".bp", ".sh", ".xml", ".yml", ".yaml", ".rc", ".cil", ".te", ".contexts",
}

SKIP_DIR_PARTS = {"proprietary", ".git", "out", "node_modules"}


def iter_files(roots):
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_PARTS]
            for name in filenames:
                if os.path.splitext(name)[1].lower() in CRITICAL_EXTS:
                    yield os.path.join(dirpath, name)


def main():
    roots = sys.argv[1:] or ["device/infinix/X6840", "vendor/infinix/X6840"]

    problems = []
    checked = 0
    for path in iter_files(roots):
        checked += 1
        try:
            with open(path, "rb") as fh:
                data = fh.read()
        except OSError as exc:
            print(f"!! tidak bisa baca {path}: {exc}", file=sys.stderr)
            problems.append((path, "read-error"))
            continue
        has_bom = data[:3] == BOM
        has_crlf = b"\r\n" in data
        has_cr = b"\r" in data
        if has_bom:
            problems.append((path, "BOM"))
            print(f"BOM  : {path}")
        if has_crlf or has_cr:
            problems.append((path, "CRLF"))
            print(f"CRLF : {path}")

    print(f"Dicek: {checked} file")
    if problems:
        print(
            f"GAGAL: {len(problems)} file punya BOM/CRLF. Normalisasi dulu sebelum build.",
            file=sys.stderr,
        )
        return 1
    print("OK: semua file kritis bebas BOM dan memakai LF")
    return 0


if __name__ == "__main__":
    sys.exit(main())
