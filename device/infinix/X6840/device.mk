#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/infinix/X6840

# --- API ---
# Target ROM = Android 16 (PixelOS branch sixteen), jadi shipping level 36.
# (Vendor stok API 35, tapi GSI A16 terbukti boot di device ini.)
PRODUCT_SHIPPING_API_LEVEL := 35

# --- A/B + dynamic partitions + emulated storage ---
# Catatan: 'launcher.mk' TIDAK ADA di PixelOS sixteen (error run #19:
#   device.mk:15: build/make/target/product/virtual_ab_ota/launcher.mk does not exist).
# File yang benar = 'launch_with_vendor_ramdisk.mk' karena X6840 launch dengan
# Virtual A/B DAN punya partisi vendor_boot (menurut komentar AOSP, varian ini
# lebih dipilih daripada launch.mk). Ia menyiapkan linker/e2fsck/fsck.f2fs
# untuk vendor_ramdisk.
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)
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

# --- Dynamic partitions: only A/B, logical in super ---
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_SUPER_PARTITION := true

# --- Filesystem / fstab ---
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/fstab.mt6768:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.mt6768

# --- Non-AB OTA / A/B OTA ---
AB_OTA_UPDATER := true

# --- APK stok /vendor (tidak boleh via PRODUCT_COPY_FILES) ---
# 15 APK di vendor/app + vendor/overlay dipasang oleh modul Soong
# prebuilt_any di vendor/infinix/X6840/Android.bp (lihat alasan di file itu).
PRODUCT_PACKAGES += \
    x6840_vendor_NetworkStackGoogleGoResOverlay \
    x6840_vendor_NetworkStackGoogleResOverlay \
    x6840_vendor_NetworkStackResOverlay \
    x6840_vendor_TetheringGoogleResOverlay \
    x6840_vendor_TetheringResOverlay \
    x6840_vendor_CellbroadcastUIResOverlay \
    x6840_vendor_ConnectivityResOverlay \
    x6840_vendor_FrameworkResOverlay \
    x6840_vendor_FrameworkResOverlayExt \
    x6840_vendor_MtkSettingsResOverlay \
    x6840_vendor_MtkTelephonyServiceResOverlay \
    x6840_vendor_SettingsProviderResOverlay \
    x6840_vendor_SystemUIResOverlay \
    x6840_vendor_WifiResMainlineOverlay \
    x6840_vendor_WifiResOverlay

# --- Inherit vendor blobs ---
$(call inherit-product, vendor/infinix/X6840/X6840-vendor.mk)
