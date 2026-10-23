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
# TARGET_USES_64_BIT_BINDER sudah deprecated di A16 (memicu warning build).

TARGET_NO_BOOTLOADER := true

# --- API level ---
# Target ROM = PixelOS sixteen (A16 / API 36).
# Catatan: vendor stok device ini masih Android 15 (ro.vendor.build.version.sdk=35,
# ro.board.api_level=202404) -> A16 tetap kompatibel karena
# PLATFORM_SEPOLICY_COMPAT_VERSIONS memuat 202404.
# PRODUCT_SHIPPING_API_LEVEL TIDAK boleh diset di sini: ia product variable
# yang menjadi .KATI_READONLY sebelum BoardConfig.mk dibaca
# (build/make/core/envsetup.mk:351 product_config.mk -> :368 board_config.mk).
# Nilainya sudah diset di device.mk (file product).
TARGET_BOARD_API_LEVEL := 36
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
# vendor_boot.img (layout MTK). Header vendor_boot_a.img stok:
#   kernel_addr  = 0x40080000
#   ramdisk_addr = 0x47c80000
#   page_size    = 4096
# PENTING: mkbootimg menulis kernel_addr = base + kernel_offset (default
# 0x00008000) dan ramdisk_addr = base + ramdisk_offset
# (system/tools/mkbootimg/mkbootimg.py:158,160), jadi --base TIDAK sama
# dengan kernel_addr. Base yang benar = 0x40080000 - 0x8000 = 0x40078000,
# ramdisk_offset = 0x47c80000 - 0x40078000 = 0x07c08000.
# CATATAN: tags_addr/dtb_addr stok belum terverifikasi -> pakai default
# mkbootimg. vendor_boot.img TIDAK di-flash (kita pakai stok), jadi ini
# hanya memengaruhi image hasil build, bukan proses flashing.
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x07c08000
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

# --- Pengecualian build untuk device berbasis dump blob ---
# build/make/core/Makefile:128-162 (fork PixelOS identik) menjalankan
# check-non-elf-file-checked untuk setiap PRODUCT_COPY_FILES yang tujuannya
# mengandung komponen bin/lib/lib64. Blob vendor/odm kita memang ELF dan
# diletakkan di sana -> build berhenti dengan
#   "found ELF prebuilt in PRODUCT_COPY_FILES".
# Flag ini adalah escape hatch resmi AOSP (board_config.mk:178).
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

# build/make/core/Makefile:105-124: file VINTF di PRODUCT_COPY_FILES
# (vendor/etc/vintf/% dan odm/etc/vintf/%) juga menghentikan build.
# Kita SENGAJA menyalin manifest vintf stok apa adanya (bukan merge lewat
# DEVICE_MANIFEST_FILE) supaya isinya identik dengan /vendor stok.
# Flag ini escape hatch resmi AOSP (board_config.mk:187).
BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES := true

# CATATAN: APK di PRODUCT_COPY_FILES TIDAK punya escape hatch
# (core/Makefile:101-104, error tanpa syarat). 15 APK vendor (app/overlay)
# karena itu dipindah ke modul Soong di vendor/infinix/X6840/Android.bp.

# --- Lokasi file per partisi (semua partisi device ini terpisah) ---
# build/make/core/board_config.mk punya check_image_config() yang MEWAJIBKAN
# TARGET_COPY_OUT_<X> bernilai persis '<X>' bila BOARD_<X>IMAGE_FILE_SYSTEM_TYPE
# diset. Device ini punya partisi terpisah: system_ext, product, vendor, odm,
# vendor_dlkm, odm_dlkm, system_dlkm -> semua wajib diset eksplisit.
# Tanpa ini build error (run #22):
#   board_config.mk:693: error: TARGET_COPY_OUT_VENDOR must be set to 'vendor'
#                     to use a vendor image.
# Nilai yang diizinkan (board_config.mk:675/791/833/873):
#   vendor         : vendor | system/vendor
#   product        : product | system/product
#   system_ext     : system_ext | system/system_ext
#   odm            : odm | system/vendor/odm | vendor/odm
#   vendor_dlkm    : vendor_dlkm | system/vendor/vendor_dlkm | vendor/vendor_dlkm
#   odm_dlkm       : odm_dlkm | system/vendor/odm_dlkm | vendor/odm_dlkm
#   system_dlkm    : system_dlkm | system/system_dlkm
# File blob vendor/odm di vendor/infinix/X6840/X6840-vendor.mk memakai
# $(TARGET_COPY_OUT_VENDOR)/... dan $(TARGET_COPY_OUT_ODM)/... sehingga otomatis
# ikut mengarah ke partisi yang benar.
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

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
