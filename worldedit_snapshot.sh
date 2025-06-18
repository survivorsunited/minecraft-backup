#!/bin/bash

################################################################################
# Script Description:
# This script performs scheduled Minecraft world backups for WorldEdit snapshots,
# rotates backups to maintain a set number of files, and ensures robust validation
# and error handling. The script creates backups in the format required by WorldEdit
# for its snapshot functionality.
#
# Key Feature: It also records the next scheduled backup time to a file so that
# if the script (container) restarts after the scheduled time, it can detect
# a missed backup and perform it immediately. If reading/writing the state file
# fails, the script falls back to a fresh schedule and continues normal operation.
#
# Variables:
# CRON_EXPRESSION       - Cron expression specifying the backup schedule.
# BACKUP_PATH           - Directory where the backup files will be stored.
# WORLD_PATH            - Path to the Minecraft world folder to backup.
# WORLD_NAME            - Name of the world (used in backup structure).
# FILES_TO_KEEP         - Number of backup files to retain before rotating,
#                         if not set, will create a backup with a timestamp.
# TMP_DIR               - Temporary directory used for creating backups.
# COMPRESSION_TYPE      - Type of compression to use (zip, tar.gz, none).
# INCLUDE_REGION_ONLY   - Whether to only backup region folder (true/false).
# FULL_BACKUP           - Whether to backup entire .minecraft folder (true/false).
#                         If true, creates backup with "-full" suffix.
#
# Dependencies (Executables and Libraries):
# - zip                        : For creating ZIP archives (default).
# - tar                        : For creating TAR archives.
# - gzip                       : For compressing TAR archives.
# - ./cron_parser.pl           : A script to calculate the next execution time
#                                 based on the cron expression. Ensure this script
#                                 is executable.
# - libdatetime-event-cron-perl : Perl module required by cron_parser.pl. Install via:
#                                 `sudo apt install libdatetime-event-cron-perl`.
#
# Notes:
# 1) If CRON_EXPRESSION is unset, the script runs exactly one backup immediately
#    and exits (no scheduling).
# 2) If the script is killed before the next scheduled backup, and the container
#    restarts afterwards, the script reads the stored epoch time from file. If it
#    finds that the backup time is in the past, it performs a "catch-up" backup
#    immediately. Then it calculates and saves the next run time for future runs.
# 3) If reading/writing the state file fails for any reason, the script logs a
#    warning and does a fresh calculation for the next backup time, continuing
#    normal operation without persisting state.
# 4) WorldEdit requires specific backup structure: timestamp folders containing
#    world folders with region subfolders.
################################################################################

# File used to record the next scheduled backup time (epoch).
NEXT_RUN_FILE=""

# ------------------------------------------------------------------------------
# Function: determine_world_path
# Description: Determines the correct world path for singleplayer vs multiplayer
# ------------------------------------------------------------------------------
determine_world_path() {
    local singleplayer_path="$MINECRAFT_HOME_PATH/saves/$WORLD_NAME"
    local multiplayer_path="$MINECRAFT_HOME_PATH/$WORLD_NAME"
    
    if [[ -d "$singleplayer_path" ]]; then
        echo "$singleplayer_path"
        echo "Detected singleplayer world: $singleplayer_path" >&2
    elif [[ -d "$multiplayer_path" ]]; then
        echo "$multiplayer_path"
        echo "Detected multiplayer/server world: $multiplayer_path" >&2
    else
        echo "Error: World '$WORLD_NAME' not found in either:" >&2
        echo "  Singleplayer: $singleplayer_path" >&2
        echo "  Multiplayer: $multiplayer_path" >&2
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Function: check_prerequisites
# Description: Validates required environment variables and checks for necessary
#              directories, executables, and Perl modules.
# ------------------------------------------------------------------------------
check_prerequisites() {
    # List of all required environment variables
    REQUIRED_VARS=(
        "BACKUP_PATH"
        "WORLD_NAME"
        "TMP_DIR"
    )

    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "Error: Environment variable $var is not set."
            exit 1
        fi
    done

    # Set defaults for optional variables
    if [[ -z "$COMPRESSION_TYPE" ]]; then
        COMPRESSION_TYPE="zip"
    fi

    if [[ -z "$INCLUDE_REGION_ONLY" ]]; then
        INCLUDE_REGION_ONLY="false"
    fi

    if [[ -z "$FULL_BACKUP" ]]; then
        FULL_BACKUP="false"
    fi

    # Determine world path and validate it
    WORLD_PATH=$(determine_world_path)
    if [[ ! -d "$WORLD_PATH" ]]; then
        echo "Error: World path $WORLD_PATH does not exist."
        exit 1
    fi

    # Check if region folder exists (required for WorldEdit)
    if [[ ! -d "$WORLD_PATH/region" ]]; then
        echo "Error: Region folder not found in $WORLD_PATH. This is required for WorldEdit snapshots."
        exit 1
    fi

    # Validate backup path
    if [[ ! -d "$BACKUP_PATH" ]]; then
        echo "Creating backup directory: $BACKUP_PATH"
        mkdir -p "$BACKUP_PATH"
    fi
    if [[ ! -d "$BACKUP_PATH" || ! -w "$BACKUP_PATH" ]]; then
        echo "Error: Backup path $BACKUP_PATH does not exist or is not writable."
        exit 1
    fi

    # Validate temporary directory
    if [[ ! -d "$TMP_DIR" ]]; then
        echo "Creating temporary directory: $TMP_DIR"
        mkdir -p "$TMP_DIR"
    fi

    # List of required executables based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            REQUIRED_EXECUTABLES=("zip" "./cron_parser.pl")
            ;;
        "tar.gz"|"tgz")
            REQUIRED_EXECUTABLES=("tar" "gzip" "./cron_parser.pl")
            ;;
        "none")
            REQUIRED_EXECUTABLES=("./cron_parser.pl")
            ;;
        *)
            echo "Error: Unsupported compression type: $COMPRESSION_TYPE. Supported: zip, tar.gz, tgz, none"
            exit 1
            ;;
    esac

    for exe in "${REQUIRED_EXECUTABLES[@]}"; do
        if ! command -v "$exe" &>/dev/null; then
            if [[ "$exe" == "./cron_parser.pl" ]]; then
                # Special handling for cron_parser.pl (not in PATH)
                if [[ ! -x "$exe" ]]; then
                    echo "Error: Required script $exe is not executable or missing."
                    exit 1
                fi
            else
                echo "Error: Required executable $exe is not installed or available in PATH."
                exit 1
            fi
        fi
    done

    # Validate Perl dependency for cron_parser.pl
    if ! perl -MDateTime::Event::Cron -e 1 &>/dev/null; then
        echo "Error: Perl module libdatetime-event-cron-perl is not installed. Install it using:"
        echo "       sudo apt install libdatetime-event-cron-perl"
        exit 1
    fi

    # Set the next run file path after we confirm BACKUP_PATH
    NEXT_RUN_FILE="$BACKUP_PATH/${WORLD_NAME}.next_run"
}

# ------------------------------------------------------------------------------
# Function: save_next_run_time
# Description: Writes an epoch timestamp to NEXT_RUN_FILE. Logs a warning and
#              returns non-zero if writing fails.
# ------------------------------------------------------------------------------
save_next_run_time() {
    local epoch_time="$1"

    if ! echo "$epoch_time" > "$NEXT_RUN_FILE" 2>/dev/null; then
        echo "Warning: Unable to write next run time to $NEXT_RUN_FILE. Continuing without persisted state."
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Function: load_next_run_time
# Description: Reads the epoch timestamp from NEXT_RUN_FILE if it exists and is valid.
#              Echoes the timestamp on success, or returns non-zero if invalid/missing.
# ------------------------------------------------------------------------------
load_next_run_time() {
    # If file doesn't exist or is not readable, return 1
    if [[ ! -r "$NEXT_RUN_FILE" ]]; then
        return 1
    fi

    local stored_time
    stored_time=$(cat "$NEXT_RUN_FILE" | tr -d ' \t\r\n')
    if [[ "$stored_time" =~ ^[0-9]+$ ]]; then
        echo "$stored_time"
        return 0
    fi

    # If the file is corrupt or empty, return 1
    return 1
}

# ------------------------------------------------------------------------------
# Function: calculate_next_run_time
# Description: Uses cron_parser.pl to calculate the next run time based on
#              CRON_EXPRESSION and returns the epoch timestamp.
#              Exits if calculation fails.
# ------------------------------------------------------------------------------
calculate_next_run_time() {
    local cron_expr="$CRON_EXPRESSION"
    local next_time

    next_time=$(./cron_parser.pl "$cron_expr")
    if [[ -z "$next_time" ]]; then
        echo "Error: Unable to parse the cron expression or calculate the next execution time."
        exit 1
    fi
    echo "$next_time"
}

# ------------------------------------------------------------------------------
# Function: create_full_backup
# Description: Creates a backup of the entire .minecraft folder with "-full" suffix.
# ------------------------------------------------------------------------------
create_full_backup() {
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local script_type="${SCRIPT_TYPE:-now}"
    local files_to_keep="${FILES_TO_KEEP:-0}"
    local backup_name="${script_type}-${timestamp}-full"
    if [[ "$files_to_keep" -gt 0 ]]; then
        backup_name="${backup_name}-ret${files_to_keep}"
    fi
    local minecraft_home="${MINECRAFT_HOME_PATH:-/minecraft}"
    local final_backup_path=""

    echo "Creating full .minecraft backup: $backup_name"
    echo "Excluding backups folder to prevent recursion"

    # Create final backup based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            final_backup_path="$BACKUP_PATH/$backup_name.zip"
            echo "Creating ZIP archive with 7zip: $final_backup_path"
            # Use 7zip to create zip archive, excluding backups folder
            cd "$minecraft_home" && 7z a -tzip "$final_backup_path" . -x!backups >/dev/null 2>&1
            ;;
        "tar.gz"|"tgz")
            final_backup_path="$BACKUP_PATH/$backup_name.tar.gz"
            echo "Creating TAR.GZ archive with 7zip: $final_backup_path"
            # Use 7zip to create tar.gz archive, excluding backups folder
            cd "$minecraft_home" && 7z a -ttar "$final_backup_path" . -x!backups >/dev/null 2>&1
            ;;
        "none")
            final_backup_path="$BACKUP_PATH/$backup_name"
            echo "Creating uncompressed backup: $final_backup_path"
            # Use 7zip to create uncompressed archive, excluding backups folder
            cd "$minecraft_home" && 7z a -ttar "$final_backup_path" . -x!backups >/dev/null 2>&1
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create full backup archive."
        exit 1
    fi

    echo "Full .minecraft backup completed: $final_backup_path"
    echo "Backup structure: .minecraft/ (Complete Minecraft installation, excluding backups)"
}

# ------------------------------------------------------------------------------
# Function: create_worldedit_backup
# Description: Creates a backup in the WorldEdit-compatible format with proper
#              timestamp and world structure.
# ------------------------------------------------------------------------------
create_worldedit_backup() {
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local script_type="${SCRIPT_TYPE:-now}"
    local files_to_keep="${FILES_TO_KEEP:-0}"
    local backup_name="${script_type}-${timestamp}"
    if [[ "$files_to_keep" -gt 0 ]]; then
        backup_name="${backup_name}-ret${files_to_keep}"
    fi
    local final_backup_path=""
    
    # Calculate world path from minecraft home and world name
    local minecraft_home="${MINECRAFT_HOME_PATH:-/minecraft}"
    local world_path="$minecraft_home/saves/$WORLD_NAME"

    echo "Creating WorldEdit snapshot backup: $backup_name"

    # Create final backup based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            final_backup_path="$BACKUP_PATH/$backup_name.zip"
            echo "Creating ZIP archive with 7zip: $final_backup_path"
            if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
                cd "$world_path" && 7z a -tzip "$final_backup_path" region >/dev/null 2>&1
            else
                cd "$world_path" && 7z a -tzip "$final_backup_path" . >/dev/null 2>&1
            fi
            ;;
        "tar.gz"|"tgz")
            final_backup_path="$BACKUP_PATH/$backup_name.tar.gz"
            echo "Creating TAR.GZ archive with 7zip: $final_backup_path"
            if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
                cd "$world_path" && 7z a -ttar "$final_backup_path" region >/dev/null 2>&1
            else
                cd "$world_path" && 7z a -ttar "$final_backup_path" . >/dev/null 2>&1
            fi
            ;;
        "none")
            final_backup_path="$BACKUP_PATH/$backup_name"
            echo "Creating uncompressed backup: $final_backup_path"
            if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
                cp -r "$world_path/region" "$final_backup_path"
            else
                cp -r "$world_path" "$final_backup_path"
            fi
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create backup archive."
        exit 1
    fi

    echo "WorldEdit snapshot backup completed: $final_backup_path"
    echo "Backup structure: $WORLD_NAME/region/ (WorldEdit compatible)"
}

# ------------------------------------------------------------------------------
# Function: create_backup_timestamp
# Description: Creates a backup file name using a timestamp suffix.
# ------------------------------------------------------------------------------
create_backup_timestamp() {
    create_worldedit_backup
}

# ------------------------------------------------------------------------------
# Function: create_backup_rotated
# Description: Creates a backup using a rotation scheme based on a file list in an index file.
#              Maintains a list of backup files and removes the oldest when limit is reached.
# ------------------------------------------------------------------------------
create_backup_rotated() {
    local current_index_file="$BACKUP_PATH/${WORLD_NAME}.index"
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local script_type="${SCRIPT_TYPE:-scheduled}"
    local files_to_keep="${FILES_TO_KEEP:-7}"
    local backup_name="${script_type}-${timestamp}-ret${files_to_keep}"
    local final_backup_path=""
    local backup_filename=""
    
    # Calculate world path from minecraft home and world name
    local minecraft_home="${MINECRAFT_HOME_PATH:-/minecraft}"
    local world_path="$minecraft_home/saves/$WORLD_NAME"

    echo "Creating rotated WorldEdit snapshot backup: $backup_name"

    # Create final backup based on compression type
    case "$COMPRESSION_TYPE" in
        "zip")
            backup_filename="$backup_name.zip"
            final_backup_path="$BACKUP_PATH/$backup_filename"
            echo "Creating ZIP archive with 7zip: $final_backup_path"
            if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
                cd "$world_path" && 7z a -tzip "$final_backup_path" region >/dev/null 2>&1
            else
                cd "$world_path" && 7z a -tzip "$final_backup_path" . >/dev/null 2>&1
            fi
            ;;
        "tar.gz"|"tgz")
            backup_filename="$backup_name.tar.gz"
            final_backup_path="$BACKUP_PATH/$backup_filename"
            echo "Creating TAR.GZ archive with 7zip: $final_backup_path"
            if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
                cd "$world_path" && 7z a -ttar "$final_backup_path" region >/dev/null 2>&1
            else
                cd "$world_path" && 7z a -ttar "$final_backup_path" . >/dev/null 2>&1
            fi
            ;;
        "none")
            backup_filename="$backup_name"
            final_backup_path="$BACKUP_PATH/$backup_filename"
            echo "Creating uncompressed backup: $final_backup_path"
            if [[ "$INCLUDE_REGION_ONLY" == "true" ]]; then
                cp -r "$world_path/region" "$final_backup_path"
            else
                cp -r "$world_path" "$final_backup_path"
            fi
            ;;
    esac

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create backup archive."
        exit 1
    fi

    # Update the index file with the new backup
    update_backup_index "$current_index_file" "$backup_filename"

    echo "Rotated WorldEdit snapshot backup completed: $final_backup_path"
    echo "Backup structure: $backup_name/$WORLD_NAME/region/ (WorldEdit compatible)"
}

# ------------------------------------------------------------------------------
# Function: update_backup_index
# Description: Updates the backup index file by adding a new backup file and
#              removing old backups to maintain the retention limit.
# Parameters:
#   $1 - Index file path
#   $2 - New backup filename to add
# ------------------------------------------------------------------------------
update_backup_index() {
    local index_file="$1"
    local new_backup="$2"
    local temp_index_file="${index_file}.tmp"

    # Create index file if it doesn't exist
    if [[ ! -f "$index_file" ]]; then
        touch "$index_file"
    fi

    # Add the new backup to the end of the list
    echo "$new_backup" >> "$index_file"

    # Count total backups and remove oldest if we exceed the limit
    local total_backups=$(wc -l < "$index_file")
    local files_to_keep=${FILES_TO_KEEP:-7}  # Default to 7 if not set

    if [[ $total_backups -gt $files_to_keep ]]; then
        echo "Backup count ($total_backups) exceeds retention limit ($files_to_keep). Removing oldest backups..."
        
        # Get the list of backups to remove (oldest first)
        local backups_to_remove=$(head -n $((total_backups - files_to_keep)) "$index_file")
        
        # Remove the old backup files
        while IFS= read -r old_backup; do
            if [[ -n "$old_backup" ]]; then
                local old_backup_path="$BACKUP_PATH/$old_backup"
                if [[ -f "$old_backup_path" ]]; then
                    echo "Removing old backup: $old_backup"
                    rm -f "$old_backup_path"
                else
                    echo "Warning: Old backup file not found: $old_backup_path"
                fi
            fi
        done <<< "$backups_to_remove"
        
        # Update the index file to keep only the newest backups
        tail -n "$files_to_keep" "$index_file" > "$temp_index_file"
        mv "$temp_index_file" "$index_file"
        
        echo "Retention cleanup completed. Kept $files_to_keep most recent backups."
    else
        echo "Backup count ($total_backups) is within retention limit ($files_to_keep)."
    fi
}

# ------------------------------------------------------------------------------
# Function: create_backup
# Description: Chooses between timestamp-based or rotated backups depending
#              on whether FILES_TO_KEEP is set.
# ------------------------------------------------------------------------------
create_backup() {
    if [[ -z "$FILES_TO_KEEP" ]]; then
        echo "FILES_TO_KEEP is not set. Using timestamp-based backup."
        create_backup_timestamp
    else
        create_backup_rotated
    fi
}

# ------------------------------------------------------------------------------
# Function: main
# Description: Orchestrates the script flow:
#              1) Checks prerequisites.
#              2) If CRON_EXPRESSION is unset, performs a single backup immediately.
#              3) Otherwise, loads or calculates the next run time.
#              4) If the stored time is in the past, run a missed backup now.
#              5) If the stored time is in the future, sleep until that time,
#                 then run the backup.
#              6) Calculates & saves the new next run time.
#              7) Exits (container may restart it depending on your setup).
# ------------------------------------------------------------------------------
main() {
    # Run prerequisite checks
    check_prerequisites

    # If CRON_EXPRESSION is unset, do a single immediate backup and exit
    if [[ -z "$CRON_EXPRESSION" ]]; then
        echo "CRON_EXPRESSION is not set. Running backup immediately..."
        if [[ "$FULL_BACKUP" == "true" ]]; then
            echo "FULL_BACKUP is set to true. Creating full .minecraft backup..."
            create_full_backup
        else
            create_backup
        fi
        exit 0
    fi

    local current_time
    current_time="$(date +%s)"

    # Try loading a previously stored next run time
    local stored_time
    if ! stored_time="$(load_next_run_time)"; then
        echo "Warning: No valid or readable next run time found in $NEXT_RUN_FILE."
        echo "Will calculate a fresh next run time."
        stored_time=""  # Force a new calculation below
    else
        echo "Loaded next run time from file: $stored_time"
    fi

    # If no stored time, calculate a new one and attempt to save it
    if [[ -z "$stored_time" ]]; then
        stored_time="$(calculate_next_run_time)"
        if ! save_next_run_time "$stored_time"; then
            # If saving fails, we just log a warning and continue in-memory
            echo "Continuing with in-memory next run time: $stored_time"
        fi
        echo "Next scheduled backup (epoch): $stored_time"
    fi

    # If the stored time is in the past, we've missed the backup => run immediately
    if (( stored_time <= current_time )); then
        echo "Detected a missed backup (originally scheduled for $stored_time). Running now..."
        create_backup
    else
        # Otherwise, sleep until the stored time
        local sleep_duration=$(( stored_time - current_time ))
        echo "Sleeping for $sleep_duration seconds, next backup at $(date -d @"$stored_time")..."
        sleep "$sleep_duration"

        echo "Backup time reached. Starting backup."
        create_backup
    fi

    # Once this backup is done, compute and save the next run time for future use
    local next_run
    next_run="$(calculate_next_run_time)"

    # Attempt to save the new run time; if it fails, we log a warning and continue
    if ! save_next_run_time "$next_run"; then
        echo "Warning: Could not save next run time to file. Will rely on in-memory value only."
    fi

    echo "Scheduled next run time (epoch): $next_run"
    echo "Backup completed at $(date). Exiting..."
}

# Start the script
main 
# ------------------------------------------------------------------------------
