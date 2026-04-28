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

Nightly backup script installed by `backup-setup.sh` (template only — the setup script generates the real version with your DB names embedded).

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

```bash
# 1. Clone the repo on your workstation
git clone https://github.com/darklifeform/server-backup-syno.git
cd server-backup-syno

# 2. Copy setup script to the server
scp backup-setup.sh root@<server>:/root/scripts/

# 3. Run setup on the server (replace with your actual DB names)
ssh root@<server> 'bash /root/scripts/backup-setup.sh mydb:"My Database"'

# 4. Save the printed private key for the backupuser SSH account
```

## Backup location

`/var/backups/db-backups/` — owned `root:backups`, mode `2750`. Only root and members of the `backups` group can read files.

## Log

Appended to `/var/backups/db-backups/log.txt`. Each line is timestamped.

## License

MIT
