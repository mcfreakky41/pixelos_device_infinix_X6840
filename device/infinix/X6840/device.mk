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
PRODUCT_VENDOR_PROPERTIES += \
    persist.vendor.radio.msimmode=dsds \
    persist.vendor.dbg.ims_volte_enable=1

PRODUCT_SYSTEM_PROPERTIES += \
    ro.telephony.default_network=9,9

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
# SATU-SATUNYA mekanisme pemasangan fstab: PRODUCT_COPY_FILES di sini.
# (Dulu rootdir/Android.mk juga memasang modul dengan tujuan yang sama;
#  itu sudah dihapus supaya tidak ada dua sumber untuk file yang sama.)
# fstab harus berasal dari device tree (bukan vendor blobs) agar flag AVB
# hasil perbaikan tidak tertimpa versi stok.
# Lihat docs/FLASHING.md bagian "Mengapa vendor/odm tetap stok".
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6768

# ============================================================
# A/B OTA (Virtual A/B)
# ============================================================
# AB_OTA_UPDATER saja TIDAK cukup untuk mengaktifkan Virtual A/B.
# Layout super perangkat ini hanya mengalokasikan satu slot (slot B dibuat
# sebagai snapshot saat update), sehingga konfigurasi yang benar adalah
# Virtual A/B. Tanpa inherit ini, build memakai aturan A/B biasa yang
# membatasi ukuran group ke setengah super -> tidak cocok dengan
# BOARD_MAIN_SIZE di BoardConfig.mk.
AB_OTA_UPDATER := true
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

# ============================================================
# Inherit vendor blobs
# ============================================================
# Semua blob dipasang lewat mapping eksplisit PRODUCT_COPY_FILES di
# X6840-vendor.mk. JANGAN tambahkan find-copy-subdir-files di sini:
#   - $(LOCAL_PATH) tidak didefinisikan di product makefile
#   - ../../vendor dari device/infinix/X6840 menunjuk device/vendor
#   - prefix tujuan "vendor" membuat vendor/vendor/... atau salah partisi
#     (odm/vendor_dlkm ikut tercopy ke vendor)
# fstab.mt6768 dikecualikan dari blob karena disediakan device tree.
$(call inherit-product, vendor/infinix/X6840/X6840-vendor.mk)
