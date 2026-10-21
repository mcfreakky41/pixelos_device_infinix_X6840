#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# CATATAN: add_lunch_combo sudah OBSOLETE di AOSP modern.
# Lunch combo kini diambil dari COMMON_LUNCH_CHOICES di AndroidProducts.mk.
# File ini sengaja dibiarkan (kompatibilitas) tetapi tidak menambahkan apa pun.
#
# PENTING soal cara lunch:
#   nama product 'pixelos_X6840' memakai underscore. Format legacy
#   'product-variant' di-parse dengan delimiter '-' sehingga variant jadi
#   kosong -> error "Invalid lunch combo".
#   Gunakan format baru: lunch pixelos_X6840 bp2a userdebug
#
# PENTING soal RELEASE config:
#   PixelOS HANYA punya satu release config valid: 'bp2a'
#   (lihat vendor/aosp/release/release_config_map.mk -> declare-release-config).
#   Default envsetup.sh ('trunk_staging') TIDAK ADA di PixelOS -> gagal dgn
#   "panic: Missing config trunk_staging" (run #16).
#   'bp2a' juga cocok dgn fingerprint build vendor device kita:
#   Infinix/X6840-OP/Infinix-X6840:16/BP2A.250605.031.A3/...
