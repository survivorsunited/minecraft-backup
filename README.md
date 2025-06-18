# WorldEdit Snapshot Backup System

A comprehensive backup solution for Minecraft worlds that creates WorldEdit-compatible snapshots with Docker Compose integration.

## Features

- **WorldEdit Compatible**: Creates backups in the exact structure required by WorldEdit snapshots
- **Scheduled Backups**: Supports cron-like scheduling using a provided cron expression
- **Backup Rotation**: Maintains a rolling limit on the number of backup files
- **Multiple Compression Formats**: Supports ZIP, TAR.GZ, or uncompressed backups
- **Region-Only Option**: Can backup only the region folder to save space
- **Validation**: Ensures all required executables and dependencies are installed before execution
- **State Persistence**: Remembers next backup time across script restarts
- **Docker Support**: Full Docker Compose integration with multiple backup strategies
- **Multi-World Support**: Backup overworld, nether, and end dimensions separately
- **Native PowerShell backup (no Docker required)**
- **Docker-based backup (optional)**

## WorldEdit Snapshot Structure

The script creates backups in the following WorldEdit-compatible structure:

```
backups/
├── 2024-01-15-14-30-00.zip
│   └── world/
│       └── region/
│           ├── r.0.0.mca
│           ├── r.0.1.mca
│           └── ...
├── 2024-01-15-10-00-00.zip
│   └── world/
│       └── region/
└── world_nether/
    └── 2024-01-15-14-30-00.zip
        └── world_nether/
            └── region/
```

## Backup Naming Convention

The backup system uses a standardized naming convention to prevent conflicts when running multiple backup services simultaneously:

### Naming Format
```
{script_type}-{timestamp}-{backup_type}-ret{retention}
```

### Examples:
- **One-time backup**: `now-2024-01-15-14-30-25.zip`
- **Hourly backup**: `hourly-2024-01-15-14-30-25-ret24.zip`
- **Daily backup**: `daily-2024-01-15-14-30-25-ret7.zip`
- **Weekly backup**: `weekly-2024-01-15-14-30-25-ret4.zip`
- **Full backup**: `now-2024-01-15-14-30-25-full.zip`
- **Scheduled full backup**: `daily-2024-01-15-14-30-25-full-ret1.zip`

### Components:
- **Script Type**: `now`, `hourly`, `daily`, `weekly`, `scheduled`
- **Timestamp**: `YYYY-MM-DD-HH-MM-SS` format
- **Backup Type**: `full` (for complete .minecraft backup) or omitted (for world-only backup)
- **Retention**: `ret{N}` where N is the number of backups to keep

### Benefits:
- **No Conflicts**: Multiple backup services can run simultaneously without overwriting each other
- **Easy Identification**: Quickly identify which service created each backup
- **Retention Tracking**: See retention settings directly in the filename
- **Organized Storage**: Backups are clearly categorized by type and schedule

## Quick Start

### 1. Setup Environment

Copy the environment template and update it with your paths:

```bash
cp env.worldedit .env
```

Edit `.env` with your Minecraft server paths:

```bash
# Update these paths to match your setup
MINECRAFT_WORLD_PATH=/path/to/your/minecraft/world
MINECRAFT_WORLD_NETHER_PATH=/path/to/your/minecraft/world_nether
MINECRAFT_WORLD_END_PATH=/path/to/your/minecraft/world_the_end
WORLDEDIT_BACKUP_PATH=/path/to/your/backups
```

### 2. Build and Run

```bash
# Build the Docker image
docker-compose build

# Run a single backup
docker-compose --profile worldedit-backup up worldedit-backup-now

# Start scheduled daily backups
docker-compose up -d worldedit-backup-daily
```

## Docker Compose Services

### Single World Backup Services

| Service | Description | Schedule | Retention | Profile |
|---------|-------------|----------|-----------|---------|
| `worldedit-backup-now` | One-time backup | Manual | N/A | `worldedit-backup` |
| `worldedit-backup-hourly` | Hourly backups | Every hour | 24 backups | None |
| `worldedit-backup-daily` | Daily backups | 2 AM daily | 7 backups | None |
| `worldedit-backup-weekly` | Weekly backups | 3 AM Sundays | 4 backups | None |

### Multi-World Backup Services

For servers with multiple worlds (overworld, nether, end):

| Service | World | Backup Path | Profile |
|---------|-------|-------------|---------|
| `worldedit-backup-overworld-now` | Overworld | `/backups/overworld/` | `worldedit-backup-multi` |
| `worldedit-backup-nether-now` | Nether | `/backups/nether/` | `worldedit-backup-multi` |
| `worldedit-backup-end-now` | End | `/backups/end/` | `worldedit-backup-multi` |

## Usage Examples

### Single World Backup

```bash
# One-time backup
docker-compose --profile worldedit-backup up worldedit-backup-now

# Start daily backups
docker-compose up -d worldedit-backup-daily

# Start hourly backups
docker-compose up -d worldedit-backup-hourly

# Start weekly backups
docker-compose up -d worldedit-backup-weekly
```

### Multi-World Backup

```bash
# Backup all worlds at once
docker-compose --profile worldedit-backup-multi up worldedit-backup-overworld-now worldedit-backup-nether-now worldedit-backup-end-now

# Or backup individual worlds
docker-compose --profile worldedit-backup-multi up worldedit-backup-overworld-now
```

### Monitoring and Logs

```bash
# View logs for daily backup service
docker-compose logs worldedit-backup-daily

# Follow logs in real-time
docker-compose logs -f worldedit-backup-daily

# Check service status
docker-compose ps
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MINECRAFT_WORLD_PATH` | Path to main world folder | `/opt/minecraft/server/world` |
| `MINECRAFT_WORLD_NETHER_PATH` | Path to nether world folder | `/opt/minecraft/server/world_nether` |
| `MINECRAFT_WORLD_END_PATH` | Path to end world folder | `/opt/minecraft/server/world_the_end` |
| `MINECRAFT_WORLD_NAME` | World name for backup structure | `world` |
| `WORLDEDIT_BACKUP_PATH` | Backup storage directory | `/var/backups/minecraft` |
| `WORLDEDIT_TMP_DIR` | Temporary directory | `/tmp/minecraft_backup` |
| `WORLDEDIT_COMPRESSION_TYPE` | Compression format | `zip` |
| `WORLDEDIT_REGION_ONLY` | Backup only region folder | `false` |
| `WORLDEDIT_CRON_HOURLY` | Hourly backup schedule | `0 * * * *` |
| `WORLDEDIT_CRON_DAILY` | Daily backup schedule | `0 2 * * *` |
| `WORLDEDIT_CRON_WEEKLY` | Weekly backup schedule | `0 3 * * 0` |
| `WORLDEDIT_FILES_TO_KEEP_HOURLY` | Hourly backup retention | `24` |
| `WORLDEDIT_FILES_TO_KEEP_DAILY` | Daily backup retention | `7` |
| `WORLDEDIT_FILES_TO_KEEP_WEEKLY` | Weekly backup retention | `4` |

## Configuration Examples

### Basic Setup

```bash
# .env
MINECRAFT_WORLD_PATH=/opt/minecraft/server/world
WORLDEDIT_BACKUP_PATH=/var/backups/minecraft
WORLDEDIT_COMPRESSION_TYPE=zip
WORLDEDIT_REGION_ONLY=false
```

### Advanced Setup with Region-Only Backups

```bash
# .env
MINECRAFT_WORLD_PATH=/opt/minecraft/server/world
WORLDEDIT_BACKUP_PATH=/var/backups/minecraft
WORLDEDIT_COMPRESSION_TYPE=tar.gz
WORLDEDIT_REGION_ONLY=true
WORLDEDIT_CRON_DAILY=0 3 * * *
WORLDEDIT_FILES_TO_KEEP_DAILY=14
```

### Multi-World Setup

```bash
# .env
MINECRAFT_WORLD_PATH=/opt/minecraft/server/world
MINECRAFT_WORLD_NETHER_PATH=/opt/minecraft/server/world_nether
MINECRAFT_WORLD_END_PATH=/opt/minecraft/server/world_the_end
WORLDEDIT_BACKUP_PATH=/var/backups/minecraft
WORLDEDIT_COMPRESSION_TYPE=zip
WORLDEDIT_REGION_ONLY=false
```

## Using Backups with WorldEdit

Once you have backups created by this system, you can use them with WorldEdit:

### List Available Snapshots
```bash
/snap list
```

### Use Latest Snapshot
```bash
/snap use latest
```

### Use Specific Snapshot
```bash
/snap use 2024-11-09-14-00-00
```

### Restore Selected Area
```bash
//restore
```

### Select Snapshot by Number
```bash
/snap sel 1
```

### Find Snapshots by Time
```bash
/snap before "2024-11-09 15:00:00"
/snap after "last friday"
```

## Compression Types

### ZIP (Default)
- **Pros**: Widely supported, good compression, WorldEdit native support
- **Cons**: Slower than uncompressed
- **Use case**: General purpose, good balance of size and speed

### TAR.GZ
- **Pros**: Better compression than ZIP, standard Linux format
- **Cons**: Requires TrueZip for WorldEdit compatibility
- **Use case**: When disk space is critical

### None (Uncompressed)
- **Pros**: Fastest access, no compression overhead
- **Cons**: Uses more disk space
- **Use case**: When speed is critical, frequent restores

## Cron Expressions

### Example Cron Expressions

| **Schedule**                     | **Cron Expression**     | **Description**                                                                 |
|-----------------------------------|-------------------------|---------------------------------------------------------------------------------|
| Every 6 hours                     | `0 */6 * * *`           | Executes the backup script every 6 hours.                                      |
| Every day at 2 AM                 | `0 2 * * *`             | Executes the backup script every day at 2:00 AM.                               |
| Every 9 AM and 9 PM               | `0 9,21 * * *`          | Executes the backup script at 9:00 AM and 9:00 PM every day.                   |
| Every Sunday at 3 AM              | `0 3 * * 0`             | Executes the backup script every Sunday at 3:00 AM.                            |
| Every hour                        | `0 * * * *`             | Executes the backup script every hour.                                         |
| Every 30 minutes                  | `*/30 * * * *`          | Executes the backup script every 30 minutes.                                   |

### Cron Syntax Reference

A cron expression has five fields:

| **Field**        | **Allowed Values**      | **Special Characters** |
|-------------------|-------------------------|-------------------------|
| **Minute**        | `0-59`                 | `, - * /`              |
| **Hour**          | `0-23`                 | `, - * /`              |
| **Day of Month**  | `1-31`                 | `, - * /`              |
| **Month**         | `1-12` or `JAN-DEC`    | `, - * /`              |
| **Day of Week**   | `0-7` (0 and 7 = Sun)  | `, - * /`              |

- `*` - Matches all possible values
- `,` - Specifies multiple values (e.g., `0,15` for 0th and 15th minute)
- `-` - Specifies a range (e.g., `1-5` for Monday through Friday)
- `/` - Specifies increments (e.g., `*/2` for every 2 minutes)

## Troubleshooting

### Common Issues

| **Issue**                     | **Possible Cause**                              | **Resolution**                              |
|--------------------------------|------------------------------------------------|---------------------------------------------|
| `Build failed`                 | Missing files or incorrect Dockerfile.         | Ensure `worldedit_snapshot.sh` and `cron_parser.pl` exist in the project directory. |
| `Volume mount failed`          | Incorrect volume paths or permissions.         | Verify volume paths exist and have correct permissions. |
| `Container health check failed` | Backup script process not running.             | Check container logs: `docker-compose logs worldedit-backup-daily` |
| `Permission denied`            | Insufficient permissions for backup directory. | Ensure backup directory is writable: `chmod -R 755 /path/to/backups` |
| `World path not found`         | Minecraft world directory doesn't exist.       | Verify `MINECRAFT_WORLD_PATH` points to a valid world directory. |
| `Region folder not found`      | World directory doesn't contain region folder. | Ensure the world directory has a `region/` subfolder. |

### Debugging Commands

```bash
# Check if environment variables are loaded
docker-compose config

# View service logs
docker-compose logs worldedit-backup-daily

# Check container status
docker-compose ps

# Execute commands in running container
docker-compose exec worldedit-backup-daily ls -la /minecraft/world

# Test backup script manually
docker-compose run --rm worldedit-backup-now
```

## Best Practices

### Backup Frequency
- **Active servers**: Every 1-6 hours
- **Development servers**: Every 6-12 hours
- **Archive servers**: Daily

### Storage Considerations
- Use separate storage for backups to prevent data loss from hardware failures
- Consider using `WORLDEDIT_REGION_ONLY=true` for large worlds to save space
- Monitor disk usage and adjust retention settings accordingly

### WorldEdit Integration
- Ensure your WorldEdit configuration points to the correct backup directory
- Test snapshot restoration in a safe environment before using in production
- Keep multiple backup formats if using non-ZIP compression (for TrueZip compatibility)

### Security
- Ensure backup directories have appropriate permissions
- Consider encrypting backups for sensitive worlds
- Regularly test backup restoration procedures

### Docker Best Practices
- Use read-only volume mounts for world folders (`:ro`)
- Separate backup storage from world storage
- Use health checks to monitor backup services
- Implement proper logging and monitoring

## Testing

### Test Single Backup
```bash
# Test one-time backup
docker-compose --profile worldedit-backup up worldedit-backup-now

# Check backup was created
ls -la /path/to/your/backups/
```

### Test Cron Parser
```bash
# Test cron expression parsing
docker-compose run --rm worldedit-backup-now /cron_parser.pl "0 2 * * *"
```

### Verify Backup Structure
```bash
# Check backup contents
unzip -l /path/to/your/backups/2024-11-09-14-00-00.zip
# Should show: world/region/ files
```

## File Structure

```
minecraft-backup/
├── docker-compose.yml          # Docker Compose configuration
├── Dockerfile                  # Docker image definition
├── worldedit_snapshot.sh       # Main backup script
├── cron_parser.pl              # Cron expression parser
├── env.worldedit               # Environment variables template
├── README.md                   # This documentation
└── .gitignore                  # Git ignore file
```

## Notes

1. Ensure all required environment variables are correctly set in `.env`
2. The `cron_parser.pl` script must be in the same directory as the backup script
3. Use the retention variables to configure the maximum number of backup files to retain
4. WorldEdit requires specific backup structure with timestamps and world folders containing region subfolders
5. Consider using `WORLDEDIT_REGION_ONLY=true` for large worlds to reduce backup size and time
6. Ensure sufficient permissions for the backup and temporary directories
7. The script automatically handles missed backups when restarted after the scheduled time
8. Docker Compose services use profiles to organize different backup strategies
9. Multi-world backups require separate volume mounts and backup paths for each world

## Native PowerShell Backup (No Docker Required)

You can now run backups directly from PowerShell using the included `tools/7zip/7za.exe` (7zip command-line tool). **Docker is not required!**

### Requirements
- Windows with PowerShell
- `tools/7zip/7za.exe` present (see below)

### Usage
```powershell
# Run a world backup (native, default)
.\backup-now.ps1

# Run a full backup (native, default)
.\backup-now.ps1 -FullBackup

# Force Docker mode (if needed)
$env:BACKUP_MODE="docker"; .\backup-now.ps1
```

### 7zip Setup
- The script expects `tools/7zip/7za.exe` to exist.
- You can download the portable 7-Zip from [7-zip.org](https://www.7-zip.org/download.html) and place `7za.exe` in `tools/7zip/`.

### Switching Modes
- By default, the script uses **native** mode.
- To force Docker mode, set `BACKUP_MODE=docker` in your environment or `.env` file.
- To force native mode, set `BACKUP_MODE=native` (default).

### Environment Variable
- `BACKUP_MODE=native` (default, uses PowerShell + 7zip)
- `BACKUP_MODE=docker` (uses Docker container)

## Docker-Based Backup (Optional)

If you prefer Docker, all previous Docker-based workflows are still supported. The script will fall back to Docker if 7zip is missing.

### Usage
```powershell
# Run a world backup using Docker
$env:BACKUP_MODE="docker"; .\backup-now.ps1

# Or use Docker Compose directly (V2 syntax):
docker compose --profile worldedit-backup build worldedit-backup-now
docker compose --profile worldedit-backup up worldedit-backup-now
docker compose --profile worldedit-backup down
```

## Features & Options
- Automatic world path detection (singleplayer/multiplayer)
- Backup rotation and retention
- Compression: zip, tar.gz, none
- Region-only backup option
- Full backup excludes the backups folder to prevent recursion

## Troubleshooting
- If you see an error about 7zip missing, download `7za.exe` and place it in `tools/7zip/`.
- If Docker is not installed and 7zip is missing, the script will not run.

---

For more details, see `README_POWERSHELL.md` for PowerShell-specific usage and advanced options. 