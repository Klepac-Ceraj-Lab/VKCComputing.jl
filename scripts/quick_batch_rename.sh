#!/usr/bin/env bash
#===============================================================================
#  SCRIPT NAME:    rename_substr.sh
#  DESCRIPTION:    Renames all files in the current directory by replacing a
#                  specified substring in their filenames with another string.
#                  Example usage replaces “_6MO” with “-6MO” in all matching files.
#  USAGE:          ./rename_substr.sh --find "_6MO" --replace "-6MO"
#                    --find STRING    : Substring to search for in filenames
#                    --replace STRING : Substring to replace it with
#  AUTHOR:         Guilherme Bottino
#  DATE CREATED:   2025-06-05
#===============================================================================

# --------------------------------------
# 1) Check that required tools exist
# --------------------------------------
required_tools=( mv )
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Error: '$tool' is not installed or not in your PATH." >&2
    echo "       Please install it before running this script." >&2
    exit 1
  fi
done

# --------------------------------------
# 2) Default parameter values
# --------------------------------------
find_str=""
replace_str=""

# --------------------------------------
# 3) Parse named arguments
# --------------------------------------
# Recognized flags:
#   --find    : Substring to find in filenames
#   --replace : Substring to replace the found substring
while [[ $# -gt 0 ]]; do
  case "$1" in
    --find)
      if [[ -n "$2" ]]; then
        find_str="$2"
        shift 2
      else
        echo "Error: '--find' requires a non-empty argument." >&2
        exit 1
      fi
      ;;
    --replace)
      if [[ -n "$2" ]]; then
        replace_str="$2"
        shift 2
      else
        echo "Error: '--replace' requires a non-empty argument." >&2
        exit 1
      fi
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --find STRING --replace STRING" >&2
      exit 1
      ;;
  esac
done

# --------------------------------------
# 4) Validate input arguments
# --------------------------------------
if [[ -z "$find_str" || -z "$replace_str" ]]; then
  echo "Error: Both --find and --replace must be provided." >&2
  echo "Usage: $0 --find STRING --replace STRING" >&2
  exit 1
fi

echo "[$(date +%T)] Starting substring rename:"
echo "  Find    = '$find_str'"
echo "  Replace = '$replace_str'"
echo

# --------------------------------------
# 5) Loop through files containing the find_str
# --------------------------------------
# For each file in the current directory whose name contains the find_str:
#   1) Construct the new filename by replacing find_str → replace_str.
#   2) If newfilename does not already exist, perform the move (rename).
#   3) Otherwise, skip and report that the target already exists.
shopt -s nullglob
for file in *"$find_str"*; do
  # Double-check that it’s a regular file
  if [[ ! -f "$file" ]]; then
    continue
  fi

  newfile="${file//$find_str/$replace_str}"

  # Only proceed if the new name differs from the old
  if [[ "$file" == "$newfile" ]]; then
    continue
  fi

  # --------------------------------------
  # 5a) Check for naming conflicts
  # --------------------------------------
  if [[ -e "$newfile" ]]; then
    echo "[$(date +%T)] Skipped (target exists): '$file' → '$newfile'"
    continue
  fi

  # --------------------------------------
  # 5b) Perform the rename
  # --------------------------------------
  mv "$file" "$newfile"
  if [[ $? -eq 0 ]]; then
    echo "[$(date +%T)] Renamed: '$file' → '$newfile'"
  else
    echo "[$(date +%T)] ERROR: Failed to rename '$file' → '$newfile'" >&2
  fi
done
shopt -u nullglob

echo
echo "[$(date +%T)] Substring rename process complete."