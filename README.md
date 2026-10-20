# PixelOS untuk Infinix Smart 20 (X6840)

Device-specific ROM untuk **Infinix Smart 20 (X6840 / X6840B)**
SoC MediaTek Helio G81 Ultimate (mt6768), kernel 6.6.

> Status: **Work in Progress** — device tree sedang dibangun dari nol.

## Device
| | |
|---|---|
| Model | Infinix Smart 20 (X6840) |
| SoC | MediaTek Helio G81 (mt6768) |
| Kernel | 6.6.x |
| Android | 15/16 |
| Partisi | A/B + dynamic (super) + vendor_boot |

## Struktur repo
- `device/infinix/X6840` — device tree
- `vendor/infinix/X6840` — vendor blobs
- `hardware/transsion` — HAL khusus Transsion

## Build
Dibangun via GitHub Actions (cloud). Lihat `.github/workflows/build.yml`.

## Kredit
- Referensi device kembar: X6728 (Infinix HOT 60i) — rama-firmware-dumps
- PixelOS project
