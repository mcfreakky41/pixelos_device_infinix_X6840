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
#   Gunakan format baru: lunch pixelos_X6840 trunk_staging userdebug
