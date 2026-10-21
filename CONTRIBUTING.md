# Berkontribusi ke PixelOS X6840

Terima kasih sudah tertarik ikut mengembangkan device tree ini! Setiap bantuan
berarti — baik itu perbaikan bug, penambahan fitur, dokumentasi, maupun sekadar
melaporkan masalah.

Dokumen ini menjelaskan cara ikut berkontribusi **sesuai alur kerja nyata
proyek ini**. Baca dulu sampai habis supaya PR-mu tidak tertolak karena hal
teknis sepele.

---

## 1. Kode Etik

Dengan berpartisipasi, kamu dianggap menyetujui [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
Intinya: bersikap sopan, sabar, dan fokus ke masalah teknis — bukan ke orangnya.

---

## 2. Cara Melaporkan Bug

Buka **Issue** dengan template yang tersedia. Sertakan **selalu**:

| Info | Kenapa penting |
|---|---|
| Model & varian perangkat | X6840 / X6840B |
| Versi ROM + tanggal build | mis. `PixelOS sixteen, build 2026-10-25` |
| Slot aktif (`a`/`b`) | jalankan `adb shell getprop ro.boot.slot_suffix` |
| Firmware stok terakhir | mis. `X6840-16.3.0.140SP09(OP004PF001AZ)` |
| Gejala + langkah reproduksi | langkah minimal, bukan "pokoknya error" |
| Logcat / dmesg relevan | **tempel sebagai teks**, jangan screenshot |
| Build log (kalau gagal build) | tautan run Actions atau potongan error |

**Jangan** melaporkan satu masalah di banyak tempat sekaligus. Satu issue = satu masalah.

Sebelum membuka issue, cari dulu di daftar issue yang ada — mungkin sudah dilaporkan.

---

## 3. Alur Kerja Pull Request

1. **Fork** repositori ini, lalu buat branch baru dengan nama yang deskriptif:
   ```
   fix/volte-no-audio
   feat/add-fod-brightness
   docs/perbaiki-cara-build
   ```
2. Lakukan perubahan. **Jangan** mencampur banyak perubahan tak berhubungan dalam
   satu PR — satu PR = satu tujuan.
3. Tulis pesan commit yang jelas (lihat bagian 5).
4. Push ke fork-mu, lalu buka **Pull Request** ke branch `main`.
5. Isi template PR dengan lengkap.
6. Pastikan build tetap hijau (lihat bagian 4).

Kami akan meninjau secepatnya. Diskusi di komentar PR dulu sebelum memaksa push
perubahan besar.

---

## 4. Menjaga Build Tetap Hijau

Build berjalan di **GitHub Actions** (lihat [`.github/workflows/build.yml`](.github/workflows/build.yml))
di runner `ubuntu-24.04-arm` (host ARM64). Ini penting:

> **Manifest PixelOS/LineageOS tidak mendukung build di host ARM64.**
> Proyek ini menambalnya lewat [`scripts/apply-arm64-host.sh`](scripts/apply-arm64-host.sh)
> yang dijalankan **setelah sync, sebelum build**. Semua patch dan alasannya
> dijelaskan di [`patches/arm64-host/README.md`](patches/arm64-host/README.md).

Kalau PR-mu menyentuh build system, **wajib**:

- Jalankan `bash -n scripts/apply-arm64-host.sh` (cek sintaks) — ini cepat dan
  menangkap sebagian besar kesalahan skrip.
- Pastikan `scripts/apply-arm64-host.sh` tetap **idempoten** dan **non-fatal**:
  - *Idempoten* → aman dijalankan berulang; penanda mencegah patch ganda.
  - *Non-fatal* → kegagalan satu langkah tidak menghentikan langkah lain, supaya
    satu run bisa mengungkap banyak masalah sekaligus.
- Patch terhadap repo AOSP (build/make, build/soong, dsb.) **tidak** boleh ditulis
  sebagai file di device tree — semuanya lewat `apply-arm64-host.sh` dan harus
  memakai **anchor yang diverifikasi langsung ke sumber PixelOS yang relevan**,
  bukan asumsi. Kalau anchor tidak cocok, skrip harus mencetak `WARN`, bukan gagal.

Device bisa diuji lewat:

```bash
# dari root source tree, setelah sync + apply patch
source build/envsetup.sh
lunch pixelos_X6840 bp2a userdebug   # release config: bp2a
mka bacon
```

> `bp2a` adalah **satu-satunya** release config valid di PixelOS
> (`vendor/aosp/release/release_config_map.mk`). `trunk_staging` tidak ada dan
> akan memicu `panic: Missing config trunk_staging`.

Kalau kamu mengubah perilaku build, sebutkan di PR bahwa build perlu di-dispatch
ulang untuk verifikasi.

---

## 5. Konvensi Pesan Commit

Kami memakai [Conventional Commits](https://www.conventionalcommits.org/) yang
sederhana:

```
<tipe>(<cakupan>): <ringkasan singkat>

<penjelasan opsional: kenapa, bukan cuma apa>
```

Tipe yang dipakai: `feat`, `fix`, `docs`, `build`, `ci`, `refactor`, `chore`.

Contoh:
```
fix(arm64-host): pakai int utk hasil getopt() di sepolicy tools

Di aarch64 plain char = unsigned, jadi sentinel -1 dari getopt()
menjadi 0xff dan parser meleset satu iterasi.
```

Tulis pesan dalam bahasa Indonesia **atau** Inggris — yang penting jelas.
Jelaskan **sebab**, bukan cuma akibat.

---

## 6. Aturan soal Blob Vendor

`vendor/infinix/X6840/` berisi blob **proprietary** milik Transsion/MediaTek
(lihat [NOTICE](NOTICE)). Karena itu:

- **Jangan** ubah blob secara manual tanpa alasan kuat; kalau perlu, jelaskan
  asal dan cara mendapatkannya.
- **Jangan** menambahkan blob ke repositori kecuali melalui Release (seperti
  praktik sekarang: Release `blobs-v1`) — repo ini sengaja tidak menyimpan blob
  besar di git.
- Semua perubahan yang menyentuh blob **wajib** dijelaskan di PR: dari mana
  blob itu, dan untuk apa.

---

## 7. Yang Kami Harapkan dari PR

- Perubahan terfokus, dengan penjelasan sebab.
- Tidak ada perubahan yang tak berhubungan (format ulang massal, dsb.).
- Untuk perubahan fungsional (VoLTE, kamera, dsb.): sebutkan cara kamu menguji
  di perangkat nyata, dan apa hasilnya.
- Sabar saat peninjauan. Proyek ini dikerjakan di waktu luang.

---

## 8. Pertanyaan?

Buka issue dengan label `question`, atau diskusikan di PR terkait.
Jangan kirim pertanyaan ke kontak pribadi — supaya jawabannya bisa berguna
untuk orang lain juga.
