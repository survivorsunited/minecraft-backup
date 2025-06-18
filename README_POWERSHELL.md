# WorldEdit Snapshot Backup - PowerShell Scripts for Windows

A collection of PowerShell scripts for Windows that provide easy-to-use interfaces for WorldEdit snapshot backups with automatic path detection and Docker integration.

## Features

- **Automatic Path Detection**: Automatically finds Minecraft world folders in common locations
- **Interactive Menus**: User-friendly menu system for all backup operations
- **Docker Integration**: Seamless integration with Docker Compose
- **Single World Backup**: Simple and efficient backup of a single Minecraft world
- **Service Management**: Start, stop, and monitor backup services
- **Logging and Monitoring**: View backup logs and service status
- **Cross-Platform Compatibility**: Works with the same Docker setup as Linux
- **Modular Design**: Shared functions for easy maintenance and consistency
- **Smart Backup Paths**: Default backup location relative to .minecraft folder
- **Native PowerShell backup (no Docker required)**
- **Docker-based backup (optional, fallback)**
- **Backup rotation and retention**
- **Compression: zip, tar.gz, none**
- **Region-only backup option**
- **Full backup excludes the backups folder**

## Prerequisites

### Required Software

1. **Docker Desktop for Windows**
   - Download from: https://www.docker.com/products/docker-desktop
   - Ensure Docker Desktop is running before using the scripts

2. **PowerShell 5.1 or later**
   - Windows 10/11 includes PowerShell 5.1 by default
   - For older Windows versions, install PowerShell 5.1 from Microsoft

### Optional Software

- **Windows Terminal** (recommended for better experience)
- **Git Bash** (alternative terminal)

## Backup Naming Convention

The backup scripts now use a standardized naming convention to prevent conflicts when running multiple backup scripts simultaneously:

### Naming Format
```
ret{retention}-{timestamp}-{backup_type}
```

### Examples:
- **One-time backup**: `2024-01-15-14-30-25.zip` (no retention prefix)
- **Hourly backup**: `ret24-2024-01-15-14-30-25.zip`
- **Daily backup**: `ret7-2024-01-15-14-30-25.zip`
- **Weekly backup**: `ret4-2024-01-15-14-30-25.zip`
- **Full backup**: `2024-01-15-14-30-25-full.zip` (no retention prefix)
- **Scheduled full backup**: `ret1-2024-01-15-14-30-25-full.zip`

### Components:
- **Retention**: `ret{N}` where N is the number of backups to keep (omitted for one-time backups)
- **Timestamp**: `YYYY-MM-DD-HH-MM-SS` format
- **Backup Type**: `full` (for complete .minecraft backup) or omitted (for world-only backup)

### Benefits:
- **No Conflicts**: Multiple backup scripts can run simultaneously without overwriting each other
- **Better Grouping**: Backups with the same retention are grouped together alphabetically
- **Retention Tracking**: See retention settings directly in the filename
- **Organized Storage**: Backups are clearly categorized by retention policy

## Scripts Overview

### 1. `functions.ps1` - Shared Functions Library
Contains all shared functions used across the backup scripts.

**Features:**
- Path detection and validation
- Docker and Docker Compose checks
- Environment file generation
- Service management utilities
- User interface helpers

### 2. `backup-now.ps1` - One-Time Backup
Runs a single WorldEdit backup immediately.

**Usage:**
```powershell
.\backup-now.ps1
.\backup-now.ps1 -WorldPath "C:\minecraft\server\world" -BackupPath "D:\backups"
.\backup-now.ps1 -RegionOnly -CompressionType tar.gz
```

**Options:**
- `-WorldPath`: Path to Minecraft world folder (auto-detected if not specified)
- `-BackupPath`: Path to store backups (auto-detected if not specified)
- `-WorldName`: World name for backup structure (default: world)
- `-CompressionType`: Compression type: zip, tar.gz, none (default: zip)
- `-RegionOnly`: Backup only region folder to save space
- `-Help`: Show help message

### 3. `backup-daily.ps1` - Scheduled Daily Backup
Starts a scheduled daily backup service that runs automatically.

**Usage:**
```powershell
.\backup-daily.ps1
.\backup-daily.ps1 -WorldPath "C:\minecraft\server\world" -BackupPath "D:\backups"
.\backup-daily.ps1 -RegionOnly -Retention 14
.\backup-daily.ps1 -Stop
.\backup-daily.ps1 -Status
```

**Options:**
- `-WorldPath`: Path to Minecraft world folder (auto-detected if not specified)
- `-BackupPath`: Path to store backups (auto-detected if not specified)
- `-WorldName`: World name for backup structure (default: world)
- `-CompressionType`: Compression type: zip, tar.gz, none (default: zip)
- `-RegionOnly`: Backup only region folder to save space
- `-Schedule`: Cron schedule (default: "0 2 * * *" = 2 AM daily)
- `-Retention`: Number of backups to keep (default: 7)
- `-Stop`: Stop the daily backup service
- `-Status`: Show status of the daily backup service
- `-Help`: Show help message

### 4. `backup-manager.ps1` - Interactive Manager
Provides an interactive menu system for all backup operations.

**Usage:**
```powershell
.\backup-manager.ps1
.\backup-manager.ps1 -Help
```

**Features:**
- Interactive menu system
- Guided configuration
- Service management
- Status monitoring
- Log viewing

## Quick Start

### 1. First-Time Setup

1. **Install Docker Desktop for Windows**
   ```powershell
   # Download and install from https://www.docker.com/products/docker-desktop
   # Ensure Docker Desktop is running
   ```

2. **Clone or download the backup scripts**
   ```powershell
   # Ensure all PowerShell scripts are in the same directory as docker-compose.yml
   ```

3. **Run the interactive manager**
   ```powershell
   .\backup-manager.ps1
   ```

### 2. Simple One-Time Backup

```powershell
# Auto-detect paths and run backup
.\backup-now.ps1

# Or specify custom paths
.\backup-now.ps1 -WorldPath "C:\minecraft\server\world" -BackupPath "D:\backups"
```

### 3. Start Scheduled Backups

```powershell
# Start daily backups (2 AM daily, 7 backups retention)
.\backup-daily.ps1

# Custom schedule and retention
.\backup-daily.ps1 -Schedule "0 3 * * *" -Retention 14
```

## Auto-Detection

The scripts automatically detect common Minecraft world locations:

### World Paths Checked:
- `C:\minecraft\server\world`
- `C:\minecraft\world`
- `C:\Program Files\Minecraft Server\world`
- `C:\Program Files (x86)\Minecraft Server\world`
- `%USERPROFILE%\AppData\Roaming\.minecraft\saves\world`
- `%USERPROFILE%\Desktop\minecraft\world`
- `%USERPROFILE%\Documents\minecraft\world`

### Backup Paths Checked (Priority Order):
1. **Relative to .minecraft folder**: `.\minecraft\backups` (preferred)
2. **Absolute .minecraft path**: `%USERPROFILE%\AppData\Roaming\.minecraft\minecraft\backups`
3. **Fallback locations**:
   - `C:\minecraft\backups`
   - `C:\backups\minecraft`
   - `D:\backups\minecraft`
   - `%USERPROFILE%\Documents\minecraft\backups`
   - `%USERPROFILE%\Desktop\minecraft\backups`

**Note**: The scripts now prioritize creating backups relative to the `.minecraft` folder, making it easier to keep backups organized with your Minecraft installation.

## Interactive Manager Usage

### Main Menu Options:

1. **Run One-Time Backup**
   - Guided configuration
   - Auto-detection of paths
   - Customizable settings

2. **Start Daily Backup Service**
   - Configure schedule and retention
   - Start automated backups
   - Service runs in background

3. **Service Management**
   - Start/stop services
   - Restart services
   - View service status

4. **View Backup Status**
   - Check configuration
   - View Docker services
   - Monitor backup health

5. **View Backup Logs**
   - Real-time log viewing
   - Service-specific logs
   - Error troubleshooting

## Service Management

### Starting Services
```powershell
# Start daily backup service
.\backup-daily.ps1

# Start via manager
.\backup-manager.ps1
# Then select option 2
```

### Stopping Services
```powershell
# Stop daily backup service
.\backup-daily.ps1 -Stop

# Stop via manager
.\backup-manager.ps1
# Then select option 3, then option 2
```

### Checking Status
```powershell
# Check service status
.\backup-daily.ps1 -Status

# View via manager
.\backup-manager.ps1
# Then select option 4
```

### Viewing Logs
```powershell
# View logs via manager
.\backup-manager.ps1
# Then select option 5

# Or directly with Docker
docker compose logs -f worldedit-backup-daily
```

## Configuration

### Environment File (.env)
The scripts automatically create a `.env` file with your configuration:

```bash
# WorldEdit Snapshot Backup Configuration
MINECRAFT_WORLD_PATH=C:/minecraft/server/world
MINECRAFT_WORLD_NAME=world
WORLDEDIT_BACKUP_PATH=./minecraft/backups
WORLDEDIT_COMPRESSION_TYPE=zip
WORLDEDIT_REGION_ONLY=false
WORLDEDIT_CRON_DAILY=0 2 * * *
WORLDEDIT_FILES_TO_KEEP_DAILY=7
```

### Customizing Settings

You can modify the `.env` file directly or use script parameters:

```powershell
# Custom compression and retention
.\backup-daily.ps1 -CompressionType tar.gz -Retention 14

# Region-only backup
.\backup-now.ps1 -RegionOnly

# Custom schedule
.\backup-daily.ps1 -Schedule "0 3 * * *"
```

## Troubleshooting

### Common Issues

| **Issue** | **Solution** |
|-----------|--------------|
| Docker not found | Install Docker Desktop for Windows |
| Permission denied | Run PowerShell as Administrator |
| World path not found | Specify `-WorldPath` parameter |
| Backup directory not writable | Check folder permissions |
| Service won't start | Check Docker Desktop is running |
| Script execution policy | Set execution policy to allow scripts |

### Debugging Commands

```powershell
# Check Docker status
docker --version
docker compose --version

# Check service status
.\backup-daily.ps1 -Status

# View logs
docker compose logs worldedit-backup-daily

# Test configuration
docker compose config

# Check PowerShell execution policy
Get-ExecutionPolicy
```

### Error Messages

**"Docker not found"**
- Install Docker Desktop for Windows
- Ensure Docker Desktop is running
- Restart PowerShell after installation

**"World path not found"**
- Verify Minecraft world exists
- Check path spelling
- Use `-WorldPath` parameter to specify manually

**"Permission denied"**
- Run PowerShell as Administrator
- Check folder permissions
- Ensure user has write access to backup directory

**"Script execution policy"**
- Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- Or run PowerShell as Administrator and set policy

## Examples

### Basic Usage Examples

```powershell
# Simple one-time backup
.\backup-now.ps1

# Daily backup with custom settings
.\backup-daily.ps1 -Retention 14 -CompressionType tar.gz

# Interactive management
.\backup-manager.ps1
```

### Advanced Usage Examples

```powershell
# Custom paths and settings
.\backup-now.ps1 -WorldPath "D:\games\minecraft\world" -BackupPath "E:\backups" -RegionOnly

# Custom schedule (3 AM daily)
.\backup-daily.ps1 -Schedule "0 3 * * *" -Retention 30

# Hourly backups (every hour on the hour)
.\backup-daily.ps1 -Schedule "0 * * * *" -Retention 168

# Hourly backups (every hour at 30 minutes past)
.\backup-daily.ps1 -Schedule "30 * * * *" -Retention 168

# Every 5 minutes
.\backup-daily.ps1 -Schedule "*/5 * * * *" -Retention 288

# Service management
.\backup-daily.ps1 -Stop
.\backup-daily.ps1 -Status
```

## Native PowerShell Backup (Default)

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
- Download the portable 7-Zip from [7-zip.org](https://www.7-zip.org/download.html)
- Place `7za.exe` in `tools/7zip/` in your project directory

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

## Troubleshooting
- If you see an error about 7zip missing, download `7za.exe` and place it in `tools/7zip/`.
- If Docker is not installed and 7zip is missing, the script will not run.

## Advanced Options
- All previous options (region-only, full backup, compression type, etc.) are supported in both modes.
- The script will automatically detect the best world path and backup location.

---

For more details, see the main `README.md`.