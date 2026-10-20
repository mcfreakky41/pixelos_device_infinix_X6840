#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/infinix/X6840

# --- API ---
PRODUCT_SHIPPING_API_LEVEL := 36

# --- A/B + dynamic partitions + emulated storage ---
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launcher.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# --- SoC / hardware properties ---
PRODUCT_PROPERTY_OVERRIDES += \
    ro.board.platform=mt6768 \
    ro.hardware=mt6768 \
    ro.hardware.egl=meow \
    ro.hardware.vulkan=mali \
    ro.hardware.hwcomposer=mtk_common \
    ro.hardware.gatekeeper=trustonic

# --- Dalvik / ART tuning (device 4GB RAM) ---
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapstartsize=8m \
    dalvik.vm.heapgrowthlimit=192m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.75 \
    dalvik.vm.heapminfree=2m \
    dalvik.vm.heapmaxfree=8m

# --- Display (HD+ 720x1640 -> density 320) ---
PRODUCT_PROPERTY_OVERRIDES += \
    ro.sf.lcd_density=320

# --- Telephony (DSDS + VoLTE, MTK IMS) ---
PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.radio.msimmode=dsds \
    ro.telephony.default_network=9,9 \
    persist.dbg.ims_volte_enable=1

# --- Media / codec ---
PRODUCT_PROPERTY_OVERRIDES += \
    debug.stagefright.omx_default_rank=0

# --- Konfigurasi audio/power/sensor sudah tercakup di vendor.mk (PRODUCT_COPY_FILES) ---
# Tidak perlu copy duplikat di sini.

# --- Inherit vendor blobs ---
$(call inherit-product, vendor/infinix/X6840/X6840-vendor.mk)
