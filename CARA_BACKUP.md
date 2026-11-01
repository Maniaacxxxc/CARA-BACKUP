# CARA BACKUP LENGKAP — ZTE G5TS (root via exploit)

Panduan rinci + script untuk backup SELURUH partisi NAND dan seluruh isi filesystem
device. Tujuan: membandingkan dengan backup lama (sebelum disentuh jasa) untuk
mengetahui PERSIS bagian mana yang diubah.

Ditulis untuk: device ZTE G5TS `BD_IOHIDG5TSV1.0.0B06`, host Linux (tablet).
Tanggal panduan: 1 Nov 2026.

================================================================================
## BAGIAN 0 — RINGKASAN (TL;DR)
================================================================================

Ada 3 jenis data yang harus di-backup untuk perbandingan lengkap:

  1. PARTISI MTD  (mtd0..mtd22)  -> dump mentah, ukuran = ukuran partisi
  2. VOLUME UBI   (etc_rw, rootfs_data, cache, manufacture_data)
  3. FILESYSTEM   (rootfs squashfs + config runtime + /etc_rw + /etc_ro/config)

Cara transfer: device buka server file kecil (tcpsvd) -> host tarik pakai nc.
Kenapa: host & device beda subnet; device TIDAK bisa connect ke host, tapi host
BISA connect ke device. Jadi kita "tarik", bukan "kirim".

================================================================================
## BAGIAN 1 — PERSIAPAN
================================================================================

### 1.1 Kebutulan di HOST (tablet)
- `nc` (netcat)  -> cek: `which nc`
- `python3`      -> untuk script (opsional)
- Ruang disk >= 1 GB di folder tujuan
- Koneksi ke device (ping 192.168.0.1 berhasil)

### 1.2 Dapatkan ROOT SHELL di device
Jalankan exploit priv-esc (auth admin -> root):
```bash
cd /root/ANEWPROJECT/REAL/zte-g5ts-privilege-escalation
export G5TS_HOST=192.168.0.1
export G5TS_PW='<password admin>'
python3 exploit.py shell      # membuka root shell di port 31337
```
Verifikasi: `nc 192.168.0.1 31337` -> prompt `/ #`, ketik `id` -> uid=0(root).

Catatan: kalau device sudah di-restore/userdata diflash, exploit tetap jalan
selama bisa login admin + cgi-io aktif.

### 1.3 Alat di DEVICE (sudah tersedia, dari sesi lalu)
- `/bin/dd`, `gzip`, `md5sum`
- `/usr/bin/tcpsvd`  (server file)
- `/sbin/mtd`  (mtd-utils: write/erase/verify)
- `ubiattach`, `ubidetach`, `ubiformat`, `ubiupdatevol` (mtd-utils)
- TIDAK ADA: python, nc-unix, nanddump, nandwrite

================================================================================
## BAGIAN 2 — CARA TRANSFER (mekanisme inti)
================================================================================

Pola dasar (PULL = tarik dari device ke host):

  DEVICE:  tcpsvd 0.0.0.0 <PORT> cat <file/yang-mau-dikirim> &
  HOST  :  nc 192.168.0.1 <PORT> > <file-lokal>

Karena shell device kita di port 31337 (nc), kita kirim perintahnya lewat situ:

  nc -w 3 192.168.0.1 31337 <<EOF
  tcpsvd 0.0.0.0 47000 cat /dev/mtd14ro &
  EOF
  sleep 1
  nc 192.168.0.1 47000 > /path/lokal/mtd14.bin

Kenapa pakai /dev/mtdXro (bukan mtdX)?
  mtdXro = read-only char device, format dump mentah, AMAN (tak mengganggu live).
  Untuk volume UBI: /dev/ubiN_M (mis. /dev/ubi1_0).

Port: pilih 46000-49000 (hindari bentrok). Satu port per transfer.

================================================================================
## BAGIAN 3 — BACKUP PARTISI MTD (mtd0..mtd22)
================================================================================

Daftar & ukuran partisi (dari `cat /proc/mtd`):
  mtd0  zloader      0xc0000       mtd13 flags          0x3c0000
  mtd1  zloader2     0xc0000       mtd14 imagefs        0x2000000
  mtd2  uboot        0x200000      mtd15 imagefs2       0x2000000
  mtd3  uboot2       0x200000      mtd16 rootfs         0x3200000
  mtd4  atf          0xc0000       mtd17 rootfs2        0x3200000
  mtd5  atf2         0xc0000       mtd18 userdata       0x5000000
  mtd6  rpm          0x100000      mtd19 zterw          0x7d00000
  mtd7  rpm2         0x100000      mtd20 manufacture    0x1400000
  mtd8  nvro         0xc00000      mtd21 oem            0x3c00000
  mtd9  nvfac        0x600000      mtd22 vol_rootfs     0x1f3e000
  mtd10 nvfac2       0x600000      mtd25 cache          (volume UBI)
  mtd11 nvrw         0xa00000      mtd26 manufacture_data (volume UBI)
  mtd12 nvrw2        0xa00000

Cara loop (host, satu partisi per baris):
  for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22; do
    P=$((46100+n))
    nc -w3 192.168.0.1 31337 <<EOF >/dev/null 2>&1
    tcpsvd 0.0.0.0 $P cat /dev/mtd${n}ro &
    EOF
    sleep 1
    nc 192.168.0.1 $P > mtd${n}.bin
    echo "mtd$n: $(stat -c%s mtd${n}.bin) bytes"
  done

Catatan penting:
  - mtd18 (userdata, 80MB) = partisi rw aktif -> isi berubah tiap saat. Ini
    PENTING untuk tahu apa yang diubah jasa (config/overlay ada di sini).
  - OCR: untuk partisi yang sedang di-mount (mtd18), tetap bisa dibaca via mtdXro.

================================================================================
## BAGIAN 4 — BACKUP VOLUME UBI
================================================================================

Volume UBI (dari `ls /sys/class/ubi/`):
  ubi0_0 = vol_rootfs        (squashfs rootfs aktif)   -> /rom
  ubi1_0 = etc_rw            (rw config)               -> /etc_rw
  ubi1_1 = rootfs_data       (overlay)                 -> /overlay
  ubi3_0 = cache             (log/cache)               -> /cache
  ubi4_0 = manufacture_data  (identitas)               -> /etc_ro/manufacture

Cara dump (device /dev/ubiN_M dikirim mentah):
  for v in ubi1_0 ubi1_1 ubi3_0 ubi4_0; do
    P=$((46200+$(echo $v|tr -dc 0-9)))
    nc -w3 192.168.0.1 31337 <<EOF >/dev/null 2>&1
    tcpsvd 0.0.0.0 $P cat /dev/$v &
    EOF
    sleep 1
    nc 192.168.0.1 $P > $v.bin
    echo "$v: $(stat -c%s $v.bin) bytes"
  done

  # ubi0_0 (vol_rootfs) = mtd22 (squashfs) sudah diambil di Bagian 3 sebagai mtd22.

================================================================================
## BAGIAN 5 — BACKUP FILESYSTEM (TAR) — untuk diff config
================================================================================

Selain dump mentah, buat TAR dari filesystem aktif supaya mudah diff (teks).
Device punya tar? Cek: `busybox | tr ',' '\n' | grep tar`.
Kalau ada, buat tar lalu kirim:

  DEVICE (via shell 31337):
    tar czf /tmp/fs_root.tar.gz -C / etc etc_ro etc_rw www usr/lib config 2>/dev/null

  HOST: tarik:
    nc -w3 192.168.0.1 31337 <<EOF >/dev/null 2>&1
    tcpsvd 0.0.0.0 46300 cat /tmp/fs_root.tar.gz &
    EOF
    sleep 1
    nc 192.168.0.1 46300 > fs_root.tar.gz

Kalau tar tak ada, backup per-direktori penting saja:
  - /etc/config/*        (uci runtime)
  - /etc_rw/             (config rw)
  - /etc_ro/config/      (config ro: netprovider.db, locknet.db, roam.db)
  - /etc/config/zwrt_zte_mdm   (lock_status)
  - /overlay/upper/      (overlay fs)
  - /www/ (web UI)       (untuk lihat JS/tombol)
  - /usr/bin, /usr/lib   (binari)

Cara mudah baca rootfs squashfs dari dump mtd22 di HOST:
  unsquashfs -d out_mtd22 mtd22.bin

================================================================================
## BAGIAN 6 — CHECKSUM & VERIFIKASI
================================================================================

Buat daftar md5 semua hasil backup (di folder tujuan):
  md5sum *.bin *.tar.gz > MD5SUMS.txt
  cat MD5SUMS.txt

Verifikasi backup vs device (opsional, untuk mtd):
  Di device:
    mtd verify <file_di_dev> <nama_partisi>
  (Catatan: hash internal mtd != md5, tapi "Success" = cocok)

Verifikasi ukuran MTD:
  Bandingkan `stat -c%s mtdN.bin` dengan ukuran di /proc/mtd (hex).

================================================================================
## BAGIAN 7 — YANG SUDAH TERSEDIA (backup lama)
================================================================================

Di `/root/ANEWPROJECT/REAL/backup/` sudah ada backup LENGKAP dari 31 Okt:
  - mtd0..mtd22.bin, mtd25/26 (0B = volume UBI), ubi*.bin
  - MD5SUMS.txt
  - lib*.so (beberapa library)
Dan di zip: `REAL_backup_full.zip`.

Karena dulu semua partisi sudah terbukti "IDENTIK", untuk mencari apa yang
diubah jasa, bandingkan backup BARU (yang akan Anda buat) vs backup ini:

  cmp backup_lama/mtdN.bin backup_baru/mtdN.bin     # lihat beda/korup
  # atau
  md5sum backup_lama/mtdN.bin backup_baru/mtdN.bin

Kalau beda, cari offset pertama yang beda:
  cmp -l backup_lama/mtdX.bin backup_baru/mtdX.bin | head

Untuk isi FILESYSTEM, ekstrak kedua mtd22 & mtd18 lalu `diff -r`.

================================================================================
## BAGIAN 8 — SCRIPT OTOMATIS
================================================================================

Lihat: `backup_all.sh` di folder ini. Jalankan dari HOST:
  cd /root/ANEWPROJECT/REAL/CARABACKUP
  ./backup_all.sh <folder_tujuan>
Contoh:
  ./backup_all.sh /root/ANEWPROJECT/REAL/backup_baru

Script akan: tarik semua mtd0..22 + volume UBI, buat MD5SUMS, dan lapor ukuran.

================================================================================
## CATATAN KEAMANAN
================================================================================

- Semua operasi di panduan ini HANYA BACA (read-only). Tidak menulis apa pun.
- Jangan pakai /dev/mtdX (tanpa ro) untuk baca - itu device rw.
- Jangan `mtd erase/write` ke partisi yang tidak dipahami.
- Backup partisi `flags` (mtd13), `manufacture` (mtd20), `oem` (mtd21) - ini yang
  sering diubah jasa (identitas/lock).
