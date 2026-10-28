#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Screen resolution (HD+ 720x1640) — HARUS sebelum inherit vendor/aosp
# karena bootanimation.mk dievaluasi saat common_full_phone.mk di-inherit
TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1640

# Inherit some common PixelOS stuff.
# NB: pada manifest PixelOS (branch sixteen) vendor config ada di vendor/aosp,
#     bukan vendor/pixelos.
$(call inherit-product, vendor/aosp/config/common_full_phone.mk)

# Inherit from X6840 device
$(call inherit-product, device/infinix/X6840/device.mk)

PRODUCT_DEVICE := X6840
PRODUCT_NAME := pixelos_X6840
PRODUCT_BRAND := Infinix
PRODUCT_MODEL := Infinix X6840
PRODUCT_MANUFACTURER := Infinix

PRODUCT_GMS_CLIENTID_BASE := android-infinix

# Catatan: `PRIVATE_BUILD_DESC` TIDAK lagi dipakai di Android 16.
# build/make A16 tidak punya variabel ini (0 referensi di seluruh build/make)
# dan `ro.build.description` pun sudah tidak digenerate
# (lihat build/make/core/sysprop.mk:71-85 - hanya date/fingerprint/id/tags/type/
# version.* yang dibuat). Menaruhnya di PRODUCT_BUILD_PROP_OVERRIDES hanya
# menghasilkan properti asing bernama `PRIVATE_BUILD_DESC` di build.prop.
#
# BUILD_FINGERPRINT: fingerprint sistem stok Infinix X6840 Android 16.
# Catatan: ROM ini ditandatangani dengan test/dev keys, jadi Play Integrity
# "DEVICE integrity" tetap tidak akan lolos (menuntut release key OEM).
BUILD_FINGERPRINT := Infinix/X6840-OP/Infinix-X6840:16/BP2A.250605.031.A3/301400019:user/release-keys
