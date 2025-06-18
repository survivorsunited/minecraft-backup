# Sample WorldEdit Snapshot Backup Commands
# These examples show how to run different backup strategies with the new naming convention
# Backup files now include script type and retention info: {script_type}-{timestamp}-ret{retention}

# One-time backup (creates: now-2024-01-15-14-30-25.zip)
.\backup-now.ps1 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -RegionOnly

# Hourly backup with 25-hour retention (creates: hourly-2024-01-15-14-30-25-ret24.zip)
.\backup-daily.ps1 -Schedule "0 * * * *" -Retention 24 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -RegionOnly

# Daily backup with 30-day retention (creates: daily-2024-01-15-14-30-25-ret30.zip)
.\backup-daily.ps1 -Schedule "0 3 * * *" -Retention 30 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -RegionOnly

# Monthly full backup with 1-month retention (creates: daily-2024-01-15-14-30-25-full-ret1.zip)
.\backup-daily.ps1 -Schedule "0 0 1 * *" -Retention 1 -WorldPath "D:\data\.minecraft\world" -BackupPath "C:\data\backups" -FullBackup