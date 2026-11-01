#!/bin/bash
# =============================================================================
# bandingkan.sh - Bandingkan backup BARU vs backup LAMA untuk cari apa yang diubah
#
# Pakai:
#   ./bandingkan.sh <folder_backup_baru> [folder_backup_lama]
# Default lama: /root/ANEWPROJECT/REAL/backup
# =============================================================================
set -u
NEW="${1:?pakai: ./bandingkan.sh <backup_baru> [backup_lama]}"
OLD="${2:-/root/ANEWPROJECT/REAL/backup}"

echo "LAMA : $OLD"
echo "BARU : $NEW"
echo "==============================================="

for f in "$NEW"/mtd*.bin "$NEW"/ubi*.bin; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    o="$OLD/$b"
    if [ ! -f "$o" ]; then
        echo "[BARU-SAJA] $b  ($(stat -c%s "$f") bytes)"
        continue
    fi
    if cmp -s "$o" "$f"; then
        echo "[IDENTIK]   $b"
    else
        off=$(cmp "$o" "$f" 2>&1 | head -1)
        n=$(cmp -l "$o" "$f" 2>/dev/null | wc -l)
        echo "[BEDA]      $b   ($n byte beda)   $off"
    fi
done | sort

echo
echo "=== Untuk partisi yang BEDA, cari rentang offset berbeda ==="
echo "Contoh: cmp -l <lama>/mtdX.bin <baru>/mtdX.bin | head -50"
echo
echo "=== Untuk isi filesystem (rootfs squashfs mtd22) ==="
echo "  unsquashfs -d old_mtd22 <lama>/mtd22.bin"
echo "  unsquashfs -d new_mtd22 <baru>/mtd22.bin"
echo "  diff -r old_mtd22 new_mtd22 | head -100"
