#!/usr/bin/env bash
# Installation:
# chmod +x smartcopy.sh
# sudo mv smartcopy.sh /usr/local/bin/

set -e

if [ "$#" -ne 2 ]; then
  echo "Usage: smartcopy <source_dir> <destination_dir>"
  echo "Example:"
  echo "  smartcopy /media/rage/backup/movies/ /mnt/synology/Multimediale/movies/"
  exit 1
fi

SRC="${1%/}/"
DST="${2%/}/"
LOG="$HOME/smartcopy.log"

echo "SmartCopy started at $(date)"
echo "Source:      $SRC"
echo "Destination: $DST"
echo "Log file:    $LOG"
echo

rsync -avh \
  --partial \
  --append-verify \
  --info=progress2 \
  --stats \
  "$SRC" "$DST" \
  | tee -a "$LOG"

echo
echo "SmartCopy finished at $(date)"
