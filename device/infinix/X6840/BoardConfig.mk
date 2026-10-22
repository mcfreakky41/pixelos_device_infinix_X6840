#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# ============================================================
#  Infinix Smart 20 (X6840) — MediaTek Helio G81 (mt6768)
#  A/B + dynamic partitions + vendor_boot, arm64-v8a only
# ============================================================

DEVICE_PATH := device/infinix/X6840

# --- Device identity ---
# Dipakai oleh guard di Android.mk dan oleh build system.
TARGET_DEVICE := X6840
TARGET_OTA_ASSERT_DEVICE := X6840,Infinix-X6840

# --- Platform / arch ---
TARGET_BOARD_PLATFORM := mt6768
TARGET_BOOTLOADER_BOARD_NAME := mt6768

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := cortex-a55
TARGET_CPU_VARIANT_RUNTIME := cortex-a55
TARGET_2ND_ARCH :=
TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_SUPPORTS_32_BIT_APPS := false
TARGET_USES_64_BIT_BINDER := true

TARGET_NO_BOOTLOADER := true

# --- API level ---
# Device stok = Android 16 (API 36). Target ROM = PixelOS sixteen (A16).
TARGET_BOARD_API_LEVEL := 36
PRODUCT_SHIPPING_API_LEVEL := 36
BOARD_SYSTEMSDK_VERSIONS := 36
BOARD_SYSTEMSDK_VERSIONS += 35
BOARD_SYSTEMSDK_VERSIONS += 34

# --- Kernel (prebuilt from stock dump; no public kernel source) ---
# TARGET_PREBUILT_KERNEL consumed oleh vendor/aosp/build/tasks/kernel.mk
# (KERNEL_BIN := $(TARGET_PREBUILT_KERNEL), tanpa kernel source).
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4

# Base & pagesize TIDAK ada di boot.img pada perangkat ini, melainkan di
# vendor_boot.img (layout MTK). Nilai diambil dari header vendor_boot_a.img
# stok: kernel_addr = 0x40080000, page_size = 4096.
# build/make/core/Makefile:1668-1677 menaruh --base/--pagesize ke vendor_boot
#_image saat BUILDING_VENDOR_BOOT_IMAGE=true -> identik dengan stok.
BOARD_KERNEL_BASE := 0x40080000
BOARD_KERNEL_PAGESIZE := 4096

# Device ini punya vendor_boot (vendor ramdisk) -> generic ramdisk (init_boot)
# harus memuat first_stage_ramdisk/ (build/make/core/Makefile:1208).
# Efek sampingnya boot.img tidak diberi --cmdline/--base/--pagesize,
# persis seperti boot_a_fresh.img stok (kernel_addr=0, page_size=0, cmdline kosong).
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_INCLUDE_DTB_IN_BOOTIMG := false
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2

# Boot image: header v4, arm64
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# --- Boot / init_boot / vendor_boot (measured from device) ---
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := false

# Cmdline vendor_boot sama persis dengan stok (tanpa androidboot.* tambahan):
# stock vendor_boot_a.img -> "bootopt=64S3,32N2,64N2"
# (androidboot.selinux=permissive sengaja TIDAK dipakai: perangkat stok jalan
#  dengan SELinux enforcing, dan kita tidak boleh menyimpang dari stok.)

# --- Dynamic partitions (super) ---
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 9663676416
BOARD_MAIN_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    odm \
    vendor_dlkm \
    odm_dlkm \
    system_dlkm

# --- Partition sizes (measured from device, byte-exact) ---
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3065143296
BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE := 1447092224
BOARD_PRODUCTIMAGE_PARTITION_SIZE := 293580800
BOARD_VENDORIMAGE_PARTITION_SIZE := 409071616
BOARD_ODMIMAGE_PARTITION_SIZE := 658419712
BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE := 13119488
BOARD_ODM_DLKMIMAGE_PARTITION_SIZE := 21872640
BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE := 7278592

BOARD_SUPER_PARTITION_BLOCK_DEVICE_SIZE_OVERRIDE := true

# --- Filesystems (stock device pakai EROFS; ROM build pakai ext4) ---
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4

# userdata = f2fs (sesuai stock)
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

BOARD_USES_METADATA_PARTITION := true

# --- A/B ---
AB_OTA_UPDATER := true
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
BOARD_AVB_ENABLE := true
BOARD_AVB_ALGORITHM := SHA256_RSA2048
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem

BOARD_AVB_VBMETA_SYSTEM := system system_ext product
BOARD_AVB_VBMETA_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

BOARD_AVB_VBMETA_VENDOR := vendor odm vendor_dlkm odm_dlkm
BOARD_AVB_VBMETA_VENDOR_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_VBMETA_VENDOR_ALGORITHM := SHA256_RSA2048
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION := 2

# --- VNDK ---
BOARD_VNDK_VERSION := current

# --- Display / GPU (Mali "meow" driver on this SoC) ---
TARGET_USES_HWC2 := true
NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3

# --- Media / Camera ---
TARGET_USES_ION := true

# --- Health / power ---
BOARD_HAS_NO_SELECT_BUTTON := true

# --- Recovery / bootconfig ---
BOARD_BOOTCONFIG := \
    androidboot.hardware=mt6768 \
    androidboot.hardware.platform=mt6768

# --- SELinux ---
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# --- init_boot: ROM kita taruh init di init_boot ---
BOARD_USES_INIT_BOOT := true
TARGET_INIT_BOOT_USE_RECOVERY := false
