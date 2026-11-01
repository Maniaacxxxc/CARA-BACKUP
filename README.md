# CARA-BACKUP — ZTE G5TS

Panduan & script backup lengkap untuk ZTE G5TS (root via exploit).

## Isi
- `CARA_BACKUP.md` — panduan rinci (persiapan, transfer, partisi MTD, volume UBI, filesystem, checksum)
- `backup_all.sh` — script otomatis backup semua partisi + UBI + filesystem
- `bandingkan.sh` — bandingkan backup baru vs lama untuk cari yang diubah

## Cepat
```bash
# 1. root shell
cd zte-g5ts-privilege-escalation
export G5TS_HOST=192.168.0.1 G5TS_PW='<password>'
python3 exploit.py shell

# 2. backup
cd CARABACKUP
./backup_all.sh /path/backup_baru

# 3. bandingkan
./bandingkan.sh /path/backup_baru /path/backup_lama
```
