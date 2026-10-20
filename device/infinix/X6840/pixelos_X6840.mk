#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common PixelOS stuff.
$(call inherit-product, vendor/pixelos/config/common_full_phone.mk)

# Inherit from X6840 device
$(call inherit-product, device/infinix/X6840/device.mk)

PRODUCT_DEVICE := X6840
PRODUCT_NAME := pixelos_X6840
PRODUCT_BRAND := Infinix
PRODUCT_MODEL := Infinix Smart 20
PRODUCT_MANUFACTURER := Infinix

PRODUCT_GMS_CLIENTID_BASE := android-infinix

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="sys_tssi_64_64only_infinix-user 15 AP3A.240905.015.A2 900545 dev-keys"

# Set BUILD_FINGERPRINT to stock fingerprint for Play Integrity
BUILD_FINGERPRINT := Infinix/X6840-OP/X6840:15/AP3A.240905.015.A2/900545:user/release-keys
