# Nota Tulis (Native Android — Flutter)

Rewrite dari versi Next.js/PWA/TWA menjadi aplikasi Android **native**, tanpa
Vercel, tanpa Supabase. Semua data (nota, produk, pengaturan) disimpan 100%
lokal di HP memakai **SQLite** (`sqflite`), state management pakai
**Riverpod**. Fitur, alur kerja, dan tampilan dibuat identik dengan versi
lama:

- Nota Baru: tabel item dengan autocomplete nama/harga barang, swipe untuk
  hapus baris, kalkulator kembalian, simpan & cetak.
- Riwayat: cari & filter tanggal, lihat/print ulang, edit nota (tambah
  barang tanpa ubah nomor/tanggal asli).
- Laporan: omzet, jumlah nota, rata-rata, barang terlaris (hari ini/minggu
  ini/bulan ini).
- Pengaturan: info toko + logo, teks atas/bawah struk, ukuran kertas 58/80mm,
  koneksi printer Bluetooth thermal (ESC/POS via BLE — protokol & UUID
  service/characteristic dipertahankan sama seperti versi Web Bluetooth),
  backup/restore JSON, hapus semua riwayat.

Fitur sinkronisasi cloud (Supabase) di versi lama **sengaja dihapus total**
sesuai permintaan — tidak ada koneksi internet yang dibutuhkan sama sekali.

## Struktur folder yang dikirim

Ini **bukan** proyek Flutter lengkap — sengaja **tidak** ada folder
`android/`, `ios/`, dll di dalam zip maupun di repo. Isinya cuma `lib/`
(seluruh kode Dart), `pubspec.yaml`, dan `.github/workflows/build-apk.yml`.

Karena kamu kerja dari Termux tanpa Flutter SDK terpasang di HP, folder
`android/` **dibuat ulang otomatis oleh GitHub Actions setiap kali build**
(lihat `.github/workflows/build-apk.yml`) — kamu tidak perlu menjalankan
`flutter create` sama sekali, baik di Termux maupun di manapun.

## Langkah di Termux (cuma git, seperti biasa)

```bash
unzip -o nota-tulis-flutter.zip -d nota-tulis-flutter
cd nota-tulis-flutter
git init   # kalau belum ada repo
git remote add origin <url-repo-github-kamu>
git add .
git commit -m "Rewrite ke native Flutter (SQLite + Riverpod)"
git push -u origin main
```

Push ke branch `main` otomatis memicu workflow `build-apk.yml`, yang akan:

1. Install Flutter di runner GitHub.
2. Menjalankan `flutter create --platforms=android --org com.notatulis --project-name app .`
   — ini AMAN, karena `pubspec.yaml` kamu sudah mendeklarasikan dependency
   `flutter`, jadi perintah ini cuma menambah folder `android/` yang belum
   ada, **tidak** menimpa `lib/` atau `pubspec.yaml` yang sudah kamu push.
   `applicationId` hasilnya persis `com.notatulis.app`, sama seperti
   versi TWA lama.
3. Menyisipkan izin Bluetooth ke `AndroidManifest.xml` otomatis (lihat
   detail di bawah).
4. Memastikan `minSdkVersion` 21 (dibutuhkan untuk Bluetooth Low Energy).
5. `flutter pub get` lalu `flutter build apk --release`.
6. Upload hasil APK sebagai artifact bernama **nota-tulis-apk** — bisa
   diunduh dari tab **Actions** di repo GitHub kamu.

Kalau workflow gagal di step "Generate folder platform Android" atau
"Pastikan minSdkVersion", cek log Actions-nya — kemungkinan besar cuma
beda sedikit format `build.gradle` (Groovy vs Kotlin DSL) tergantung
versi Flutter yang dipakai `subosito/flutter-action`, tinggal sesuaikan
pattern `sed` di file workflow-nya.

## Izin Bluetooth (AndroidManifest.xml)

Ditambahkan otomatis oleh CI, tepat sebelum tag `<application ...>`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="30" />
```

`neverForLocation` boleh dihapus dari file workflow kalau nanti ternyata
printer tidak ditemukan saat scan di sebagian HP Android lama — beberapa
printer BLE murah butuh izin lokasi klasik untuk discoverable.

## Keystore signing (opsional — tidak dipakai secara default)

Workflow `build-apk.yml` saat ini build **debug APK** (`flutter build apk
--debug`), otomatis ditandatangani pakai debug key bawaan Flutter — tidak
butuh keystore atau secrets apapun. Cukup untuk sideload/pakai sendiri.

Kalau nanti berubah pikiran dan mau build **release** (APK lebih kecil &
teroptimasi, dan supaya update antar versi bisa saling menimpa dengan rapi
tanpa uninstall dulu), generate keystore lalu daftarkan sebagai secrets:

Karena ini proyek baru yang terpisah dari versi TWA/Vercel lama, generate
keystore baru (sekali saja) di Termux:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias nota-tulis
```

Nanti akan diminta bikin password keystore & isi data (nama, organisasi,
dst — boleh asal, tidak memengaruhi fungsi app). **Simpan file
`upload-keystore.jks` ini baik-baik di luar repo** (jangan sampai hilang,
kalau hilang update selanjutnya bakal bermasalah lagi).

Lalu encode ke base64 dan daftarkan sebagai **GitHub Secrets** di
`https://github.com/muhamad-holis/Nota-tulis-offline/settings/secrets/actions`:

```bash
base64 -w 0 upload-keystore.jks
# copy hasilnya (satu baris panjang) buat secret ANDROID_KEYSTORE_BASE64
```

Tambahkan 4 secrets ini (New repository secret):

| Nama secret | Isi |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | hasil `base64` di atas |
| `ANDROID_KEYSTORE_PASSWORD` | password yang kamu buat saat `keytool -genkey` |
| `ANDROID_KEY_ALIAS` | `nota-tulis` |
| `ANDROID_KEY_PASSWORD` | password key (kalau tidak diminta terpisah, sama dengan storePassword) |

**Catatan:** langkah-langkah signing di atas belum otomatis di
`build-apk.yml` (workflow sekarang murni build debug). Kalau sudah siap
pakai release + keystore, bilang saja — saya tambahkan lagi step
signing-nya ke workflow.

## Nama aplikasi & warna tema

- `applicationId` hasil build: **`com.notatulis.app`** — persis sama dengan
  packageId TWA lama (lihat langkah 2 workflow di atas), jadi kalau ada
  APK lama ter-install, ini dianggap update, bukan aplikasi baru.
- Nama tampilan: **Nota Tulis**
- Warna tema (brand-600): `#2563EB`
- Nama launcher & ikon masih default bawaan `flutter create` (label
  "app", ikon Flutter). Kalau mau diganti jadi "Nota Tulis" + ikon lama
  (`public/icons/icon-512.png` dari repo Next.js), tambahkan step lagi
  di `build-apk.yml` setelah step "Generate folder platform Android"
  untuk mengganti `android:label` di `AndroidManifest.xml` dan menimpa
  file di `android/app/src/main/res/mipmap-*` — beri tahu saya kalau mau
  saya buatkan step-nya sekalian.

## Catatan teknis

- Cetak Bluetooth pakai `flutter_blue_plus` (BLE/GATT) dengan service UUID
  `000018f0-...` & characteristic `00002af1-...` — sama persis dengan versi
  Web Bluetooth lama, supaya kompatibel dengan printer thermal murah yang
  sama.
- Logo toko & gambar disimpan sebagai base64 PNG di kolom `logo` tabel
  `settings` (setara `dataURL` di versi lama).
- Backup/restore JSON formatnya kompatibel 1:1 dengan file backup dari versi
  lama (`nota-tulis-backup-YYYY-MM-DD.json`).
- Dependency versi di `pubspec.yaml` pakai `^` (boleh naik minor version).
  Kalau `flutter pub get` menarik versi `flutter_blue_plus` yang API-nya
  sedikit berubah, source lengkap ada di `lib/services/printer_service.dart`
  — tinggal sesuaikan pemanggilan method yang error.
