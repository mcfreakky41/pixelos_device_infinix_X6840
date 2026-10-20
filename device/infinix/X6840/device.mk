#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/infinix/X6840

# API level
PRODUCT_SHIPPING_API_LEVEL := 35

# A/B + dynamic partitions
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launcher.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# SoC properties
PRODUCT_PROPERTY_OVERRIDES += \
    ro.board.platform=mt6768 \
    ro.hardware=mt6768

# Dalvik / ART tuning (optimized for 4GB RAM device)
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=192m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=2m \
    dalvik.vm.heapmaxfree=8m

# Display
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=320

# Copy device configs
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml

# Inherit vendor
$(call inherit-product, vendor/infinix/X6840/X6840-vendor.mk)
