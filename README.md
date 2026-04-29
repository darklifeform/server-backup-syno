# server-backup-syno

Automated MySQL database backup scripts for Linux servers (Synology-compatible). Dumps databases with `mysqldump`, compresses with gzip, rotates files older than 7 days, and backs up the crontab.

## Scripts

### `backup-setup.sh`

One-time setup script. Run as root on the target server.

- Creates a dedicated `backupuser` system account in a `backups` group
- Creates `/var/backups/db-backups/` with locked-down permissions (`2750`)
- Generates a 4096-bit RSA key pair for `backupuser` (prints the private key once — save it)
- Installs `backup.sh` to `/root/scripts/backup.sh` with the specified databases
- Registers a nightly cron job (`0 0 * * *`)

**Usage:**
```bash
sudo bash backup-setup.sh db1:"Label 1" db2:"Label 2"
```

### `backup.sh`

Reference only — not meant to be run directly. `backup-setup.sh` generates the real version at `/root/scripts/backup.sh` with your DB names embedded.

- Dumps each database with `--single-transaction` (safe for InnoDB under load)
- Compresses with `gzip -6` to `YYYYMMDD_HHMM_<db>.sql.gz`
- Rotates `.gz` files older than 7 days
- Backs up the current crontab to `/root/scripts/crontab.bak`
- Logs all activity and errors to `log.txt`

## Requirements

- Bash 4+
- `mysqldump` (MySQL / MariaDB client)
- `gzip`
- Root access on the target server

## Setup

Run directly on the server as root:

```bash
# 1. Download and run the setup script (replace with your actual DB names)
mkdir -p /root/scripts && \
wget -qO /root/scripts/backup-setup.sh \
  https://raw.githubusercontent.com/darklifeform/server-backup-syno/main/backup-setup.sh && \
chmod +x /root/scripts/backup-setup.sh && \
bash /root/scripts/backup-setup.sh mydb:"My Database"

# 2. Save the printed private key for the backupuser SSH account
```

## Backup location

`/var/backups/db-backups/` — owned `root:backups`, mode `2750`. Only root and members of the `backups` group can read files.

## Log

Appended to `/var/backups/db-backups/log.txt`. Each line is timestamped.

## License

MIT
