# PixelOS Device Tree untuk Infinix Smart 20 (X6840)
# Direktori utama - Android 16 (API 36)

# Vendor blobs tidak masuk git (ratusan MB)
# Vendor files di-download otomatis via GitHub Release blobs-v1

# Struktur:
# ├── device/                    # Device tree utama
# │   └── infinix/
# │       └── X6840/
# │           ├── AndroidProducts.mk
# │           ├── BoardConfig.mk
# │           ├── device.mk
# │           ├── pixelos_X6840.mk
# │           ├── vendorsetup.sh
# │           ├── rootdir/
# │           └── sepolicy/
# ├── vendor/                    # Vendor tree
# │   └── infinix/
# │       └── X6840/
# │           ├── Android.mk
# │           ├── Android.bp
# │           ├── proprietary-files.txt
# │           └── X6840-vendor.mk
# ├── patches/                   # Patch untuk build system
# │   └── arm64-host/
# ├── scripts/                   # Skrip bantu
# ├── .github/
# │   └── workflows/
# ├── docs/                      # Dokumentasi
# └── README.md