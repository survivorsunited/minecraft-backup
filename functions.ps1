# WorldEdit Snapshot Backup - Shared Functions
# PowerShell functions shared across all backup scripts

# Function to detect default Minecraft world path
function Get-DefaultWorldPath {
    $possiblePaths = @(
        "C:\minecraft\server\world",
        "C:\minecraft\world",
        "C:\Program Files\Minecraft Server\world",
        "C:\Program Files (x86)\Minecraft Server\world",
        "$env:USERPROFILE\AppData\Roaming\.minecraft\saves\world",
        "$env:USERPROFILE\Desktop\minecraft\world",
        "$env:USERPROFILE\Documents\minecraft\world"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            if (Test-Path "$path\region") {
                Write-Host "Auto-detected world path: $path" -ForegroundColor Green
                return $path
            }
        }
    }
    
    Write-Host "Could not auto-detect world path. Please specify -WorldPath parameter." -ForegroundColor Red
    Write-Host "Common locations:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        Write-Host "  $path" -ForegroundColor Gray
    }
    exit 1
}

# Function to detect default backup path relative to .minecraft folder
function Get-DefaultBackupPath {
    # First, try to find the .minecraft folder
    $minecraftPaths = @(
        "$env:USERPROFILE\AppData\Roaming\.minecraft",
        "$env:USERPROFILE\.minecraft",
        "C:\.minecraft"
    )
    
    $minecraftPath = $null
    foreach ($path in $minecraftPaths) {
        if (Test-Path $path) {
            $minecraftPath = $path
            break
        }
    }
    
    # If .minecraft folder found, create backup INSIDE .minecraft
    if ($minecraftPath) {
        $backupPath = Join-Path $minecraftPath "backups"
        
        # Check if the backup path already exists
        if (Test-Path $backupPath) {
            Write-Host "Auto-detected backup path: $backupPath" -ForegroundColor Green
            return $backupPath
        }
        
        # Create default backup directory INSIDE .minecraft
        Write-Host "Creating default backup directory: $backupPath" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            Write-Host "Created backup directory: $backupPath" -ForegroundColor Green
            return $backupPath
        }
        catch {
            Write-Host "Failed to create backup directory: $backupPath" -ForegroundColor Red
            Write-Host "Please specify -BackupPath parameter." -ForegroundColor Red
            exit 1
        }
    }
    
    # Fallback to old behavior if .minecraft not found
    $possiblePaths = @(
        "C:\minecraft\backups",
        "C:\backups\minecraft",
        "D:\backups\minecraft",
        "$env:USERPROFILE\Documents\minecraft\backups",
        "$env:USERPROFILE\Desktop\minecraft\backups"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            Write-Host "Auto-detected backup path: $path" -ForegroundColor Green
            return $path
        }
    }
    
    # Create default backup directory
    $defaultPath = "C:\minecraft\backups"
    Write-Host "Creating default backup directory: $defaultPath" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $defaultPath -Force | Out-Null
        Write-Host "Created backup directory: $defaultPath" -ForegroundColor Green
        return $defaultPath
    }
    catch {
        Write-Host "Failed to create backup directory. Please specify -BackupPath parameter." -ForegroundColor Red
        exit 1
    }
}

# Function to check if Docker is available
function Test-DockerAvailable {
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            Write-Host "Docker detected: $dockerVersion" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "Docker not found. Please install Docker Desktop for Windows." -ForegroundColor Red
        return $false
    }
    return $false
}

# Function to check if docker-compose is available
function Test-DockerComposeAvailable {
    try {
        $composeVersion = docker compose version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Docker Compose: Available" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Docker Compose: Not available" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Docker Compose: Not available" -ForegroundColor Red
        return $false
    }
}

# Function to validate world path
function Test-WorldPath {
    param([string]$Path, [string]$WorldType = "World")
    
    if ([string]::IsNullOrEmpty($Path)) {
        return $false
    }
    
    if (-not (Test-Path $Path)) {
        Write-Host "$WorldType path does not exist: $Path" -ForegroundColor Red
        return $false
    }
    
    if (-not (Test-Path "$Path\region")) {
        Write-Host "$WorldType path does not contain region folder: $Path" -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Function to validate compression type
function Test-CompressionType {
    param([string]$CompressionType)
    
    $validCompressionTypes = @("zip", "tar.gz", "tgz", "none")
    if ($validCompressionTypes -notcontains $CompressionType) {
        Write-Host "Invalid compression type: $CompressionType" -ForegroundColor Red
        Write-Host "Valid types: $($validCompressionTypes -join ', ')" -ForegroundColor Yellow
        return $false
    }
    return $true
}

# Function to create .env file for single world backup
function New-EnvFile {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType,
        [bool]$RegionOnly,
        [bool]$FullBackup = $false
    )
    
    # Calculate the Minecraft home path (parent of saves folder)
    $minecraftHomePath = (Split-Path (Split-Path $WorldPath -Parent) -Parent).Replace('\', '/')
    
    $envContent = @"
# WorldEdit Snapshot Backup Configuration
# Generated by PowerShell script

# Backup Mode (native/docker) - Default to native for better performance
BACKUP_MODE=native

# Minecraft Home Path (points to .minecraft folder)
MINECRAFT_HOME_PATH=$minecraftHomePath
MINECRAFT_WORLD_NAME=$WorldName

# WorldEdit Backup Configuration
WORLDEDIT_BACKUP_PATH=$($BackupPath.Replace('\', '/'))
WORLDEDIT_TMP_DIR=/tmp/minecraft_backup
WORLDEDIT_COMPRESSION_TYPE=$CompressionType
WORLDEDIT_REGION_ONLY=$($RegionOnly.ToString().ToLower())
WORLDEDIT_FULL_BACKUP=$($FullBackup.ToString().ToLower())

# WorldEdit Backup Schedules (Cron Expressions)
WORLDEDIT_CRON_HOURLY=0 * * * *
WORLDEDIT_CRON_DAILY=0 2 * * *
WORLDEDIT_CRON_WEEKLY=0 3 * * 0

# WorldEdit Backup Retention
WORLDEDIT_FILES_TO_KEEP_HOURLY=24
WORLDEDIT_FILES_TO_KEEP_DAILY=7
WORLDEDIT_FILES_TO_KEEP_WEEKLY=4

# Timezone
TZ=UTC
"@
    
    $envContent | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host "Created .env file with configuration" -ForegroundColor Green
}

# Function to create .env file with custom schedule and retention
function New-EnvFileWithSchedule {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType,
        [bool]$RegionOnly,
        [string]$Schedule,
        [int]$Retention
    )
    
    $envContent = @"
# WorldEdit Snapshot Backup Configuration
# Generated by PowerShell script

# Minecraft World Paths
MINECRAFT_WORLD_PATH=$($WorldPath.Replace('\', '/'))
MINECRAFT_WORLD_NAME=$WorldName

# WorldEdit Backup Configuration
WORLDEDIT_BACKUP_PATH=$($BackupPath.Replace('\', '/'))
WORLDEDIT_TMP_DIR=/tmp/minecraft_backup
WORLDEDIT_COMPRESSION_TYPE=$CompressionType
WORLDEDIT_REGION_ONLY=$($RegionOnly.ToString().ToLower())

# WorldEdit Backup Schedules (Cron Expressions)
WORLDEDIT_CRON_HOURLY=0 * * * *
WORLDEDIT_CRON_DAILY=$Schedule
WORLDEDIT_CRON_WEEKLY=0 3 * * 0

# WorldEdit Backup Retention
WORLDEDIT_FILES_TO_KEEP_HOURLY=24
WORLDEDIT_FILES_TO_KEEP_DAILY=$Retention
WORLDEDIT_FILES_TO_KEEP_WEEKLY=4

# Timezone
TZ=UTC
"@
    
    $envContent | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host "Created .env file with configuration" -ForegroundColor Green
}

# Function to build Docker image
function Build-DockerImage {
    param([string]$ServiceName, [string]$Profile = "")
    
    Write-Host "Building Docker image..." -ForegroundColor Yellow
    try {
        if ($Profile) {
            docker compose --profile $Profile build $ServiceName
        } else {
            docker compose build $ServiceName
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to build Docker image" -ForegroundColor Red
            return $false
        }
        return $true
    }
    catch {
        Write-Host "Failed to build Docker image: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to show service status
function Show-ServiceStatus {
    param([string]$ServiceName = "worldedit-backup-daily")
    
    Write-Host "`nChecking $ServiceName service status..." -ForegroundColor Yellow
    
    try {
        $containers = docker compose ps $ServiceName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Service Status:" -ForegroundColor Green
            Write-Host $containers -ForegroundColor White
        } else {
            Write-Host "Service is not running" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Failed to check service status: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Show recent logs
    Write-Host "`nRecent logs:" -ForegroundColor Yellow
    try {
        docker compose logs --tail=10 $ServiceName
    }
    catch {
        Write-Host "No logs available" -ForegroundColor Gray
    }
}

# Function to display backup configuration
function Show-BackupConfiguration {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType,
        [bool]$RegionOnly,
        [string]$Schedule = "",
        [int]$Retention = 0,
        [bool]$FullBackup = $false
    )
    
    Write-Host "`nBackup Configuration:" -ForegroundColor Yellow
    Write-Host "  World Path: $WorldPath" -ForegroundColor White
    Write-Host "  Backup Path: $BackupPath" -ForegroundColor White
    Write-Host "  World Name: $WorldName" -ForegroundColor White
    Write-Host "  Compression: $CompressionType" -ForegroundColor White
    Write-Host "  Region Only: $RegionOnly" -ForegroundColor White
    Write-Host "  Full Backup: $FullBackup" -ForegroundColor White
    
    if ($Schedule) {
        Write-Host "  Schedule: $Schedule" -ForegroundColor White
    }
    if ($Retention -gt 0) {
        Write-Host "  Retention: $Retention backups" -ForegroundColor White
    }
}

# Function to check prerequisites
function Test-Prerequisites {
    if (-not (Test-DockerAvailable)) {
        return $false
    }
    
    if (-not (Test-DockerComposeAvailable)) {
        return $false
    }
    
    return $true
}

# Function to validate and create backup directory
function Test-AndCreateBackupDirectory {
    param([string]$BackupPath)
    
    if (-not (Test-Path $BackupPath)) {
        Write-Host "Creating backup directory: $BackupPath" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
            return $true
        }
        catch {
            Write-Host "Failed to create backup directory: $BackupPath" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

# Function to get user choice for interactive menus
function Get-UserChoice {
    param([string]$Prompt = "Enter your choice: ")
    
    do {
        $choice = Read-Host $Prompt
        if ($choice -match '^\d+$') {
            return [int]$choice
        }
        Write-Host "Please enter a valid number." -ForegroundColor Red
    } while ($true)
}

# Function to show help for scripts
function Show-ScriptHelp {
    param([string]$ScriptName, [string]$HelpText)
    
    Write-Host $HelpText
    exit 0
}

# Function to pause and wait for user input
function Wait-ForUserInput {
    param([string]$Message = "Press any key to continue...")
    
    Write-Host "`n$Message" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Function to validate retention number
function Test-Retention {
    param([int]$Retention)
    
    if ($Retention -lt 1) {
        Write-Host "Retention must be at least 1" -ForegroundColor Red
        return $false
    }
    return $true
}

# Function to run Docker Compose command with error handling
function Invoke-DockerCompose {
    param(
        [string]$Command,
        [string]$ServiceName = "",
        [string]$Profile = ""
    )
    
    $args = @("compose")
    
    if ($Profile) {
        $args += "--profile"
        $args += $Profile
    }
    
    # Split the command into separate arguments
    $commandArgs = $Command -split '\s+'
    $args += $commandArgs
    
    if ($ServiceName) {
        $args += $ServiceName
    }
    
    try {
        & docker @args
        return $LASTEXITCODE
    }
    catch {
        Write-Host "Failed to run Docker Compose command: $($_.Exception.Message)" -ForegroundColor Red
        return 1
    }
}

# ------------------------------------------------------------------------------
# Minecraft Backup Functions
# Description: Shared functions for Minecraft backup operations
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Function: Test-7ZipAvailable
# Description: Tests if 7zip is available in the tools directory or system PATH
# ------------------------------------------------------------------------------
function Test-7ZipAvailable {
    $toolsPath = Join-Path $PSScriptRoot "tools\7zip\7za.exe"
    $systemPath = "7z"
    
    if (Test-Path $toolsPath) {
        return $toolsPath
    }
    
    try {
        $null = Get-Command $systemPath -ErrorAction Stop
        return $systemPath
    }
    catch {
        return $null
    }
}

# ------------------------------------------------------------------------------
# Function: Get-WorldPath
# Description: Determines the correct world path for singleplayer vs multiplayer
# ------------------------------------------------------------------------------
function Get-WorldPath {
    param(
        [string]$MinecraftHomePath,
        [string]$WorldName
    )
    
    $singleplayerPath = Join-Path $MinecraftHomePath "saves\$WorldName"
    $multiplayerPath = Join-Path $MinecraftHomePath $WorldName
    
    if (Test-Path $singleplayerPath) {
        Write-Host "Detected singleplayer world: $singleplayerPath" -ForegroundColor Green
        return $singleplayerPath
    }
    elseif (Test-Path $multiplayerPath) {
        Write-Host "Detected multiplayer/server world: $multiplayerPath" -ForegroundColor Green
        return $multiplayerPath
    }
    else {
        Write-Error "World '$WorldName' not found in either:"
        Write-Error "  Singleplayer: $singleplayerPath"
        Write-Error "  Multiplayer: $multiplayerPath"
        exit 1
    }
}

# ------------------------------------------------------------------------------
# Function: New-NativeBackup
# Description: Creates a backup using PowerShell and 7zip
# ------------------------------------------------------------------------------
function New-NativeBackup {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType = "zip",
        [bool]$RegionOnly = $false,
        [bool]$FullBackup = $false,
        [string]$Timestamp,
        [int]$Retention = 0
    )
    
    $7zipPath = Test-7ZipAvailable
    if (-not $7zipPath) {
        Write-Error "7zip not found. Please install 7zip or ensure 7za.exe is in tools\7zip\"
        exit 1
    }
    
    # Save original directory to return to later
    $originalDirectory = Get-Location
    
    try {
        # Create backup name with retention at front for better grouping
        $backupName = if ($FullBackup) { "$Timestamp-full" } else { $Timestamp }
        if ($Retention -gt 0) {
            $backupType = if ($FullBackup) { "full" } else { "region" }
            $backupName = "$backupType$Retention-$backupName"
        }
        $finalBackupPath = ""
        
        Write-Host "Creating backup: $backupName" -ForegroundColor Cyan
        
        switch ($CompressionType.ToLower()) {
            "zip" {
                $finalBackupPath = Join-Path $BackupPath "$backupName.zip"
                Write-Host "Creating ZIP archive with 7zip: $finalBackupPath" -ForegroundColor Yellow
                
                if ($FullBackup) {
                    # Full backup - exclude backups folder
                    # Determine the correct minecraft home path
                    # If the provided path ends with the world name, it's a world path
                    # Otherwise, assume it's already a minecraft home path
                    if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
                        # User provided a world path, calculate minecraft home
                        $minecraftHome = Split-Path (Split-Path $WorldPath -Parent) -Parent
                    } else {
                        # User provided a minecraft home path directly
                        $minecraftHome = $WorldPath
                    }
                    
                    Write-Host "Full backup: Archiving minecraft home directory: $minecraftHome" -ForegroundColor Yellow
                    Set-Location $minecraftHome
                    & $7zipPath a -tzip $finalBackupPath . -x!backups | Out-Null
                }
                else {
                    # World backup
                    Set-Location $WorldPath
                    if ($RegionOnly) {
                        & $7zipPath a -tzip $finalBackupPath region | Out-Null
                    }
                    else {
                        & $7zipPath a -tzip $finalBackupPath . | Out-Null
                    }
                }
            }
            "tar.gz" {
                $finalBackupPath = Join-Path $BackupPath "$backupName.tar.gz"
                Write-Host "Creating TAR.GZ archive with 7zip: $finalBackupPath" -ForegroundColor Yellow
                
                if ($FullBackup) {
                    # Determine the correct minecraft home path
                    if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
                        # User provided a world path, calculate minecraft home
                        $minecraftHome = Split-Path (Split-Path $WorldPath -Parent) -Parent
                    } else {
                        # User provided a minecraft home path directly
                        $minecraftHome = $WorldPath
                    }
                    
                    Write-Host "Full backup: Archiving minecraft home directory: $minecraftHome" -ForegroundColor Yellow
                    Set-Location $minecraftHome
                    & $7zipPath a -ttar $finalBackupPath . -x!backups | Out-Null
                }
                else {
                    Set-Location $WorldPath
                    if ($RegionOnly) {
                        & $7zipPath a -ttar $finalBackupPath region | Out-Null
                    }
                    else {
                        & $7zipPath a -ttar $finalBackupPath . | Out-Null
                    }
                }
            }
            "none" {
                $finalBackupPath = Join-Path $BackupPath $backupName
                Write-Host "Creating uncompressed backup: $finalBackupPath" -ForegroundColor Yellow
                
                if ($FullBackup) {
                    # Determine the correct minecraft home path
                    if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
                        # User provided a world path, calculate minecraft home
                        $minecraftHome = Split-Path (Split-Path $WorldPath -Parent) -Parent
                    } else {
                        # User provided a minecraft home path directly
                        $minecraftHome = $WorldPath
                    }
                    
                    Write-Host "Full backup: Copying minecraft home directory: $minecraftHome" -ForegroundColor Yellow
                    Copy-Item -Path $minecraftHome -Destination $finalBackupPath -Recurse -Exclude "backups"
                }
                else {
                    if ($RegionOnly) {
                        Copy-Item -Path (Join-Path $WorldPath "region") -Destination $finalBackupPath -Recurse
                    }
                    else {
                        Copy-Item -Path $WorldPath -Destination $finalBackupPath -Recurse
                    }
                }
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create backup archive."
            # Check if it's a file access error (Minecraft server running)
            if ($LASTEXITCODE -eq 1) {
                Write-Host "This appears to be a file access error. The Minecraft server may be running and locking the files." -ForegroundColor Yellow
                Write-Host "Consider using Docker mode or stopping the Minecraft server temporarily." -ForegroundColor Yellow
                # Return a special exit code to indicate file access issues
                exit 2
            }
            exit 1
        }
        
        Write-Host "Backup completed: $finalBackupPath" -ForegroundColor Green
        return $finalBackupPath
    }
    finally {
        # Always return to original directory, even if an error occurred
        Set-Location $originalDirectory
    }
}

# ------------------------------------------------------------------------------
# Function: Update-BackupIndex
# Description: Updates backup index file and manages retention
# ------------------------------------------------------------------------------
function Update-BackupIndex {
    param(
        [string]$IndexFile,
        [string]$NewBackup,
        [int]$FilesToKeep = 7
    )
    
    # Create index file if it doesn't exist
    if (-not (Test-Path $IndexFile)) {
        New-Item -Path $IndexFile -ItemType File | Out-Null
    }
    
    # Add new backup to the beginning of the list
    $content = Get-Content $IndexFile -ErrorAction SilentlyContinue
    $newContent = @($NewBackup) + $content
    $newContent | Set-Content $IndexFile
    
    # Remove old backups if we exceed the limit
    if ($newContent.Count -gt $FilesToKeep) {
        $linesToRemove = $newContent.Count - $FilesToKeep
        $oldBackups = $newContent | Select-Object -Last $linesToRemove
        
        Write-Host "Removing $linesToRemove old backup(s):" -ForegroundColor Yellow
        foreach ($oldBackup in $oldBackups) {
            $oldPath = Join-Path (Split-Path $IndexFile -Parent) $oldBackup
            if (Test-Path $oldPath) {
                Remove-Item $oldPath -Recurse -Force
                Write-Host "  Removed: $oldBackup" -ForegroundColor Red
            }
        }
        
        # Update index file to keep only the newest backups
        $newContent | Select-Object -First $FilesToKeep | Set-Content $IndexFile
    }
}

# ------------------------------------------------------------------------------
# Native Backup Functions
# Description: Functions for PowerShell-based backup execution without Docker
# ------------------------------------------------------------------------------

# Function to test if 7zip is available in the tools directory or system PATH
function Test-7ZipAvailable {
    $toolsPath = Join-Path $PSScriptRoot "tools\7zip\7za.exe"
    $systemPath = "7z"
    
    if (Test-Path $toolsPath) {
        return $toolsPath
    }
    
    try {
        $null = Get-Command $systemPath -ErrorAction Stop
        return $systemPath
    }
    catch {
        return $null
    }
}

# Function to determine the correct world path for singleplayer vs multiplayer
function Get-WorldPath {
    param(
        [string]$MinecraftHomePath,
        [string]$WorldName
    )
    
    $singleplayerPath = Join-Path $MinecraftHomePath "saves\$WorldName"
    $multiplayerPath = Join-Path $MinecraftHomePath $WorldName
    
    if (Test-Path $singleplayerPath) {
        Write-Host "Detected singleplayer world: $singleplayerPath" -ForegroundColor Green
        return $singleplayerPath
    }
    elseif (Test-Path $multiplayerPath) {
        Write-Host "Detected multiplayer/server world: $multiplayerPath" -ForegroundColor Green
        return $multiplayerPath
    }
    else {
        Write-Error "World '$WorldName' not found in either:"
        Write-Error "  Singleplayer: $singleplayerPath"
        Write-Error "  Multiplayer: $multiplayerPath"
        exit 1
    }
}

# Function to create a backup using PowerShell and 7zip
function New-NativeBackup {
    param(
        [string]$WorldPath,
        [string]$BackupPath,
        [string]$WorldName,
        [string]$CompressionType = "zip",
        [bool]$RegionOnly = $false,
        [bool]$FullBackup = $false,
        [string]$Timestamp,
        [int]$Retention = 0
    )
    
    $7zipPath = Test-7ZipAvailable
    if (-not $7zipPath) {
        Write-Error "7zip not found. Please install 7zip or ensure 7za.exe is in tools\7zip\"
        exit 1
    }
    
    # Save original directory to return to later
    $originalDirectory = Get-Location
    
    try {
        # Create backup name with retention at front for better grouping
        $backupName = if ($FullBackup) { "$Timestamp-full" } else { $Timestamp }
        if ($Retention -gt 0) {
            $backupType = if ($FullBackup) { "full" } else { "region" }
            $backupName = "$backupType$Retention-$backupName"
        }
        $finalBackupPath = ""
        
        Write-Host "Creating backup: $backupName" -ForegroundColor Cyan
        
        switch ($CompressionType.ToLower()) {
            "zip" {
                $finalBackupPath = Join-Path $BackupPath "$backupName.zip"
                Write-Host "Creating ZIP archive with 7zip: $finalBackupPath" -ForegroundColor Yellow
                
                if ($FullBackup) {
                    # Full backup - exclude backups folder
                    # Determine the correct minecraft home path
                    # If the provided path ends with the world name, it's a world path
                    # Otherwise, assume it's already a minecraft home path
                    if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
                        # User provided a world path, calculate minecraft home
                        $minecraftHome = Split-Path (Split-Path $WorldPath -Parent) -Parent
                    } else {
                        # User provided a minecraft home path directly
                        $minecraftHome = $WorldPath
                    }
                    
                    Write-Host "Full backup: Archiving minecraft home directory: $minecraftHome" -ForegroundColor Yellow
                    Set-Location $minecraftHome
                    & $7zipPath a -tzip $finalBackupPath . -x!backups | Out-Null
                }
                else {
                    # World backup
                    Set-Location $WorldPath
                    if ($RegionOnly) {
                        & $7zipPath a -tzip $finalBackupPath region | Out-Null
                    }
                    else {
                        & $7zipPath a -tzip $finalBackupPath . | Out-Null
                    }
                }
            }
            "tar.gz" {
                $finalBackupPath = Join-Path $BackupPath "$backupName.tar.gz"
                Write-Host "Creating TAR.GZ archive with 7zip: $finalBackupPath" -ForegroundColor Yellow
                
                if ($FullBackup) {
                    # Determine the correct minecraft home path
                    if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
                        # User provided a world path, calculate minecraft home
                        $minecraftHome = Split-Path (Split-Path $WorldPath -Parent) -Parent
                    } else {
                        # User provided a minecraft home path directly
                        $minecraftHome = $WorldPath
                    }
                    
                    Write-Host "Full backup: Archiving minecraft home directory: $minecraftHome" -ForegroundColor Yellow
                    Set-Location $minecraftHome
                    & $7zipPath a -ttar $finalBackupPath . -x!backups | Out-Null
                }
                else {
                    Set-Location $WorldPath
                    if ($RegionOnly) {
                        & $7zipPath a -ttar $finalBackupPath region | Out-Null
                    }
                    else {
                        & $7zipPath a -ttar $finalBackupPath . | Out-Null
                    }
                }
            }
            "none" {
                $finalBackupPath = Join-Path $BackupPath $backupName
                Write-Host "Creating uncompressed backup: $finalBackupPath" -ForegroundColor Yellow
                
                if ($FullBackup) {
                    # Determine the correct minecraft home path
                    if ((Split-Path $WorldPath -Leaf) -eq $WorldName) {
                        # User provided a world path, calculate minecraft home
                        $minecraftHome = Split-Path (Split-Path $WorldPath -Parent) -Parent
                    } else {
                        # User provided a minecraft home path directly
                        $minecraftHome = $WorldPath
                    }
                    
                    Write-Host "Full backup: Copying minecraft home directory: $minecraftHome" -ForegroundColor Yellow
                    Copy-Item -Path $minecraftHome -Destination $finalBackupPath -Recurse -Exclude "backups"
                }
                else {
                    if ($RegionOnly) {
                        Copy-Item -Path (Join-Path $WorldPath "region") -Destination $finalBackupPath -Recurse
                    }
                    else {
                        Copy-Item -Path $WorldPath -Destination $finalBackupPath -Recurse
                    }
                }
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create backup archive."
            # Check if it's a file access error (Minecraft server running)
            if ($LASTEXITCODE -eq 1) {
                Write-Host "This appears to be a file access error. The Minecraft server may be running and locking the files." -ForegroundColor Yellow
                Write-Host "Consider using Docker mode or stopping the Minecraft server temporarily." -ForegroundColor Yellow
                # Return a special exit code to indicate file access issues
                exit 2
            }
            exit 1
        }
        
        Write-Host "Backup completed: $finalBackupPath" -ForegroundColor Green
        return $finalBackupPath
    }
    finally {
        # Always return to original directory, even if an error occurred
        Set-Location $originalDirectory
    }
}

# Function to update backup index file and manage retention
function Update-BackupIndex {
    param(
        [string]$IndexFile,
        [string]$NewBackup,
        [int]$FilesToKeep = 7
    )
    
    # Create index file if it doesn't exist
    if (-not (Test-Path $IndexFile)) {
        New-Item -Path $IndexFile -ItemType File | Out-Null
    }
    
    # Add new backup to the beginning of the list
    $content = Get-Content $IndexFile -ErrorAction SilentlyContinue
    $newContent = @($NewBackup) + $content
    $newContent | Set-Content $IndexFile
    
    # Remove old backups if we exceed the limit
    if ($newContent.Count -gt $FilesToKeep) {
        $linesToRemove = $newContent.Count - $FilesToKeep
        $oldBackups = $newContent | Select-Object -Last $linesToRemove
        
        Write-Host "Removing $linesToRemove old backup(s):" -ForegroundColor Yellow
        foreach ($oldBackup in $oldBackups) {
            $oldPath = Join-Path (Split-Path $IndexFile -Parent) $oldBackup
            if (Test-Path $oldPath) {
                Remove-Item $oldPath -Recurse -Force
                Write-Host "  Removed: $oldBackup" -ForegroundColor Red
            }
        }
        
        # Update index file to keep only the newest backups
        $newContent | Select-Object -First $FilesToKeep | Set-Content $IndexFile
    }
} 