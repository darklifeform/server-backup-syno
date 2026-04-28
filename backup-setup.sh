#!/bin/bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 db1:\"Label 1\" db2:\"Label 2\""
  exit 1
fi

groupadd -f backups
useradd -r -m -d /home/backupuser -s /bin/bash -g backups backupuser

mkdir -p /var/backups/db-backups
chown root:backups /var/backups/db-backups
chmod 2750 /var/backups/db-backups

TMP_KEY=$(mktemp -d)
ssh-keygen -t rsa -b 4096 -N "" -f "${TMP_KEY}/backupuser_rsa" -C "backupuser@$(hostname)" -q

mkdir -p /home/backupuser/.ssh
chown backupuser:backups /home/backupuser/.ssh
chmod 700 /home/backupuser/.ssh

cat "${TMP_KEY}/backupuser_rsa.pub" >> /home/backupuser/.ssh/authorized_keys
chown backupuser:backups /home/backupuser/.ssh/authorized_keys
chmod 600 /home/backupuser/.ssh/authorized_keys

echo "=== PRIVATE KEY (save now, will be deleted) ==="
cat "${TMP_KEY}/backupuser_rsa"
echo "=== PUBLIC KEY ==="
cat "${TMP_KEY}/backupuser_rsa.pub"
echo "================================================"

rm -rf "${TMP_KEY}"

{ crontab -l 2>/dev/null || true; } | grep -v "/root/scripts/backup.sh" | \
{ cat; echo "0 0 * * * /root/scripts/backup.sh"; } | crontab -

mkdir -p /root/scripts

# Generate backup.sh
BACKUP_CALLS=""
for arg in "$@"; do
  db="${arg%%:*}"
  label="${arg#*:}"
  BACKUP_CALLS+="backup_db \"${db}\" \"${label}\"\n"
done

cat > /root/scripts/backup.sh << EOF
#!/bin/bash
umask 027
set -euo pipefail
cd /var/backups/db-backups/ || exit 1

TS=\$(date +%Y%m%d_%H%M)

log_error() {
  local line="\$1"
  printf '%s [TS=%s] ERROR on line %s\n' \\
    "\$(date +'%Y-%m-%d %T')" "\$TS" "\$line" >> log.txt
}

trap 'log_error \$LINENO' ERR

backup_db() {
  local db="\$1"
  local label="\${2:-\$1}"

  if nice -n 19 mysqldump --add-drop-table --single-transaction -u root "\$db" | gzip -6 -c > "\${TS}_\${db}.sql.gz"; then
    echo "\$(date +"%Y-%m-%d %T") \${label} database backup successful" >> log.txt
  else
    echo "\$(date +"%Y-%m-%d %T") \${label} database backup failed" >> log.txt
    return 1
  fi
}

$(printf "%b" "$BACKUP_CALLS")
find /var/backups/db-backups/ -name "*.gz" -mtime +7 -exec rm {} \;
echo "\$(date +"%Y-%m-%d %T") DB backup rotation completed" >> log.txt

if crontab -l > /root/scripts/crontab.bak; then
  echo "\$(date +"%Y-%m-%d %T") Crontab backup completed" >> log.txt
else
  echo "\$(date +"%Y-%m-%d %T") Crontab backup failed" >> log.txt
  exit 1
fi
EOF

chmod +x /root/scripts/backup.sh

echo "Done."