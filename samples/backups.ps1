# Sample WorldEdit Snapshot Backup Commands
# These examples show how to run different backup strategies with the new naming convention
# Backup files now include backup type and retention: {backup_type}{retention}-{timestamp}-{backup_type}

# One-time backup (creates: 2024-01-15-14-30-25.zip)
.\backup-now.ps1 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -RegionOnly

# Hourly backup with 24-hour retention (creates: region24-2024-01-15-14-30-25.zip)
.\backup-daily.ps1 -Schedule "0 * * * *" -Retention 24 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -RegionOnly

# Daily backup with 30-day retention (creates: region30-2024-01-15-14-30-25.zip)
.\backup-daily.ps1 -Schedule "0 3 * * *" -Retention 30 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -RegionOnly

# Monthly full backup with 1-month retention (creates: full1-2024-01-15-14-30-25-full.zip)
.\backup-daily.ps1 -Schedule "0 0 1 * *" -Retention 1 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -RegionOnly -FullBackup