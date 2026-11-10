#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/infinix/X6840

# ============================================================
# API & Platform
# ============================================================
# Target ROM = Android 16 (PixelOS branch sixteen, API 36)
# Vendor stok device ini masih Android 15 (API 35), tapi A16 compatible
PRODUCT_SHIPPING_API_LEVEL := 36

# ============================================================
# Platform Properties
# ============================================================
PRODUCT_SYSTEM_PROPERTIES += \
    ro.board.platform=mt6768 \
    ro.hardware=mt6768 \
    ro.hardware.egl=meow \
    ro.hardware.vulkan=mali \
    ro.hardware.hwcomposer=mtk_common \
    ro.hardware.gatekeeper=trustonic

# ============================================================
# Dalvik / ART tuning (device 4GB RAM)
# ============================================================
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=192m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=2m \
    dalvik.vm.heapmaxfree=8m

# ============================================================
# Display
# ============================================================
PRODUCT_SYSTEM_PROPERTIES += \
    ro.sf.lcd_density=320

# ============================================================
# Telephony (DSDS + VoLTE, MTK IMS)
# ============================================================
PRODUCT_SYSTEM_PROPERTIES += \
    persist.vendor.radio.msimmode=dsds \
    ro.telephony.default_network=9,9 \
    persist.dbg.ims_volte_enable=1

# ============================================================
# Media / codec
# ============================================================
PRODUCT_SYSTEM_PROPERTIES += \
    debug.stagefright.omx_default_rank=0

# ============================================================
# Dynamic partitions
# ============================================================
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := true

# ============================================================
# Filesystem / fstab
# ============================================================
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6768

# ============================================================
# A/B OTA (Virtual A/B)
# ============================================================
AB_OTA_UPDATER := true

# ============================================================
# Inherit vendor blobs
# ============================================================
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/../../vendor/infinix/X6840/proprietary,vendor)

$(call inherit-product, vendor/infinix/X6840/X6840-vendor.mk)