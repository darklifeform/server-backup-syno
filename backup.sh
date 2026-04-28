#!/bin/bash
umask 027
set -euo pipefail
cd /var/backups/db-backups/ || exit 1

TS=$(date +%Y%m%d_%H%M)

log_error() {
  local line="$1"
  printf '%s [TS=%s] ERROR on line %s\n' \
    "$(date +'%Y-%m-%d %T')" "$TS" "$line" >> log.txt
}

trap 'log_error $LINENO' ERR

backup_db() {
  local db="$1"
  local label="${2:-$1}"

  if nice -n 19 mysqldump --add-drop-table --single-transaction -u root "$db" | gzip -6 -c > "${TS}_${db}.sql.gz"; then
    echo "$(date +"%Y-%m-%d %T") ${label} database backup successful" >> log.txt
  else
    echo "$(date +"%Y-%m-%d %T") ${label} database backup failed" >> log.txt
    return 1
  fi
}

backup_db DB_NAME "DB_LABEL"

find /var/backups/db-backups/ -name "*.gz" -mtime +7 -exec rm {} \;
echo "$(date +"%Y-%m-%d %T") DB backup rotation completed" >> log.txt

if crontab -l > /root/scripts/crontab.bak; then
  echo "$(date +"%Y-%m-%d %T") Crontab backup completed" >> log.txt
else
  echo "$(date +"%Y-%m-%d %T") Crontab backup failed" >> log.txt
  exit 1
fi