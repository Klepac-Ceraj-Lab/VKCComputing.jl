#!/usr/bin/env bash
#===============================================================================
#  SCRIPT NAME:    rename_ids.sh
#  DESCRIPTION:    Renames files in a directory by replacing old IDs with new IDs
#                  based on a mapping CSV. The CSV (without header) should have:
#                    old_id,new_id
#                  For each old_id, any file whose name contains old_id will be
#                  renamed so that old_id is replaced with new_id.
#                  Generates:
#                    - A report of all successful renames (rename_report.txt)
#                    - A log of any old_ids that had no matching files (unmatched_ids.log)
#                    - An error log for conflicts or failures (rename_errors.log)
#  USAGE:          ./rename_ids.sh [--dir DIRECTORY] [--csv MAPPING_CSV]
#                    --dir DIRECTORY   : Directory containing files to rename (default: current directory)
#                    --csv MAPPING_CSV : CSV file with "old_id,new_id" mappings (default: echo_rename.csv)
#  AUTHOR:         Guilherme Bottino
#  DATE CREATED:   2025-06-05
#===============================================================================

# --------------------------------------
# 1) Check that required tools exist
# --------------------------------------
required_tools=( tail mv dirname basename tr )
optional_tools=( realpath )  # realpath is preferred but not strictly required
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Error: '$tool' is not installed or not in your PATH." >&2
    echo "       Please install it before running this script." >&2
    exit 1
  fi
done

# Check if 'realpath' is available; if not, we'll fall back to dirname/basename
if command -v realpath &>/dev/null; then
  USE_REALPATH=true
else
  USE_REALPATH=false
  echo "Warning: 'realpath' not found. Using dirname/basename fallback for path normalization." >&2
fi

# --------------------------------------
# 2) Default parameters
# --------------------------------------
DIR="./"
MAPPING_CSV="name_table.csv"
LOG_FILE="unmatched_ids.log"
REPORT_FILE="rename_report.txt"
ERROR_LOG="rename_errors.log"

# --------------------------------------
# 3) Parse input arguments (optional)
# --------------------------------------
#   --dir DIRECTORY   : Directory containing files (default: ./)
#   --csv MAPPING_CSV : CSV file with old_id,new_id pairs (default: echo_rename.csv)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      if [[ -n "$2" ]]; then
        DIR="$2"
        shift 2
      else
        echo "Error: '--dir' requires a directory path." >&2
        exit 1
      fi
      ;;
    --csv)
      if [[ -n "$2" ]]; then
        MAPPING_CSV="$2"
        shift 2
      else
        echo "Error: '--csv' requires a CSV filename." >&2
        exit 1
      fi
      ;;
    *)
      echo "Usage: $0 [--dir DIRECTORY] [--csv MAPPING_CSV]" >&2
      exit 1
      ;;
  esac
done

# --------------------------------------
# 4) Verify that the directory exists
# --------------------------------------
if [[ ! -d "$DIR" ]]; then
  echo "Error: Directory '$DIR' does not exist." >&2
  exit 1
fi

# --------------------------------------
# 5) Verify that the mapping CSV exists
# --------------------------------------
if [[ ! -f "$MAPPING_CSV" ]]; then
  echo "Error: Mapping CSV '$MAPPING_CSV' not found." >&2
  exit 1
fi

# --------------------------------------
# 6) Clear or create log and report files
# --------------------------------------
: > "$LOG_FILE"
: > "$REPORT_FILE"
: > "$ERROR_LOG"

# Write header to report file
echo "Renaming Process - $(date)" > "$REPORT_FILE"
echo "Directory: $DIR"               >> "$REPORT_FILE"
echo "Mapping CSV: $MAPPING_CSV"     >> "$REPORT_FILE"
echo "---------------------------------" >> "$REPORT_FILE"

echo "[$(date +%T)] Starting renaming in directory: $DIR"

# --------------------------------------
# 7) Read the CSV (skip header) and process each mapping
# --------------------------------------
# Using process substitution (< <(...)) ensures that 'exit 1' inside the loop
# will terminate the entire script rather than only the subshell.
while IFS=, read -r old_id new_id; do
  # Skip empty lines or lines where old_id or new_id is blank
  [[ -z "$old_id" || -z "$new_id" ]] && continue

  # Trim whitespace from new_id
  new_id=$(echo "$new_id" | tr -d '[:space:]')

  echo "[$(date +%T)] Processing ID mapping: '$old_id' → '$new_id'"

  match_found=false

  # --------------------------------------
  # 7a) Find and rename files containing old_id
  # --------------------------------------
  shopt -s nullglob
  for file in "$DIR"/*"$old_id"*; do
    # Ensure it is a regular file
    if [[ -f "$file" ]]; then
      # Construct new filename by replacing old_id with new_id
      new_file="${file//$old_id/$new_id}"

      # Check: If a file with new_file already exists, abort with error
      if [[ -e "$new_file" ]]; then
        echo "ERROR: Cannot rename '$file' → '$new_file' (target already exists)" | tee -a "$ERROR_LOG"
        echo "Process interrupted due to naming conflict. See '$ERROR_LOG'." >&2
        exit 1
      fi

      # --------------------------------------
      # 7b) Perform the rename with correct path normalization
      # --------------------------------------
      if [[ "$USE_REALPATH" == true ]]; then
        # Compute the relative path for new_file
        normalized_new=$(realpath --relative-to="." "$new_file")
        mv "$file" "$normalized_new"
      else
        # Fallback: use dirname and basename
        mv "$file" "$(dirname "$new_file")/$(basename "$new_file")"
      fi

      echo "[$(date +%T)] Renamed: '$(basename "$file")' → '$(basename "$new_file")'" | tee -a "$REPORT_FILE"
      match_found=true
    fi
  done
  shopt -u nullglob

  # --------------------------------------
  # 7c) If no file matched this old_id, log it
  # --------------------------------------
  if [[ "$match_found" == false ]]; then
    echo "$old_id" | tee -a "$LOG_FILE"
    echo "[$(date +%T)] No matches found for old_id: '$old_id' (logged to '$LOG_FILE')" >> "$REPORT_FILE"
  fi

done < <(tail -n +2 "$MAPPING_CSV")

echo "[$(date +%T)] Renaming process complete."
echo "Report written to: $REPORT_FILE"
echo "Unmatched IDs logged to: $LOG_FILE"
echo "Errors (if any) logged to: $ERROR_LOG"