#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/infinix/X6840

# --- Device identity ---
TARGET_OTA_ASSERT_DEVICE := X6840,Infinix-X6840

# --- Platform / arch ---
TARGET_BOARD_PLATFORM := mt6768
TARGET_BOOTLOADER_BOARD_NAME := mt6768

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := cortex-a55
TARGET_CPU_VARIANT_RUNTIME := cortex-a55
TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_SUPPORTS_32_BIT_APPS := false

TARGET_NO_BOOTLOADER := true

# --- Kernel ---
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4

# Kernel offsets (dari stock vendor_boot)
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x07c08000
BOARD_KERNEL_PAGESIZE := 4096

BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_INCLUDE_DTB_IN_BOOTIMG := false
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2

BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)

# --- Boot partition sizes ---
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := false

# --- Dynamic partitions (super) ---
# Perangkat memakai Virtual A/B: super hanya mengalokasikan satu slot;
# slot kedua dibuat sebagai snapshot saat OTA. Karena itu group "main"
# boleh memakai hampir seluruh super (dikurangi overhead metadata).
# Kalau ternyata perangkat memakai A/B biasa (bukan Virtual A/B), nilai
# BOARD_MAIN_SIZE harus <= setengah super. Verifikasi dengan:
#   fastboot getvar current-slot
#   adb shell getprop ro.virtual_ab.enabled   # dari vendor stok
#
# CATATAN PENTING: build ini TIDAK mem-flash super.img (hanya partisi logis
# system/system_ext/product). Jadi angka di bawah tidak menulis ulang layout
# super di perangkat; partisi stok seperti tr_region/tr_product tetap ada.
# Angka ini relevan kalau suatu saat super.img ikut dibangun/di-flash.
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 9659482112
BOARD_MAIN_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    odm \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm

# --- Filesystems ---
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4

# --- Escape patches for blob-based vendor ---
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES := true

# --- Partition output paths ---
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

# --- User data ---
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_USES_METADATA_PARTITION := true

# --- A/B OTA ---
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    odm \
    odm_dlkm \
    product \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor \
    vendor_boot \
    vendor_dlkm

# --- AVB ---
# PERINGATAN: kunci di bawah adalah AOSP test key (dev only).
# Build ini BUKAN build produksi dan tidak boleh dipakai dengan
# verified boot terkunci. Untuk kunci sendiri, timpa lewat environment
# atau local.mk, misalnya:
#   BOARD_AVB_KEY_PATH=/path/to/releasekey.pem
#   BOARD_AVB_VBMETA_SYSTEM_KEY_PATH=...
#   BOARD_AVB_VBMETA_VENDOR_KEY_PATH=...
# (dipakai ?= supaya nilai dari environment tidak ditimpa file ini)
BOARD_AVB_ENABLE := true
BOARD_AVB_ALGORITHM := SHA256_RSA2048
BOARD_AVB_KEY_PATH ?= external/avb/test/data/testkey_rsa2048.pem

# system_dlkm HARUS ikut vbmeta_system: fstab memasangnya dengan
# avb=vbmeta_system. Tanpa entri ini descriptor AVB-nya tidak dibuat
# dan mount first-stage bisa gagal.
BOARD_AVB_VBMETA_SYSTEM := system system_ext product system_dlkm
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH ?= external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

# Catatan: tr_manifest TIDAK masuk daftar ini karena image-nya berasal dari
# stok (tidak dibangun), sehingga tidak punya descriptor di vbmeta_vendor
# hasil build. fstab karena itu tidak memakai avb= untuk tr_manifest.
BOARD_AVB_VBMETA_VENDOR := vendor odm vendor_dlkm odm_dlkm
BOARD_AVB_VBMETA_VENDOR_KEY_PATH ?= external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 2

# --- Hardware ---
BOARD_HAS_NO_SELECT_BUTTON := true

# --- Recovery / bootconfig ---
BOARD_BOOTCONFIG := \
    androidboot.hardware=mt6768 \
    androidboot.hardware.platform=mt6768

# --- SELinux ---
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# --- init_boot ---
BOARD_USES_INIT_BOOT := true
TARGET_INIT_BOOT_USE_RECOVERY := false
