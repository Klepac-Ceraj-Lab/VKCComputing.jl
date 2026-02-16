#!/usr/bin/env bash
#===============================================================================
#  SCRIPT NAME:    rename_metaphlan_profiles.sh
#  DESCRIPTION:    Renames Metaphlan profile files to include the database name.
#                  For each file matching "*_profile.tsv", this script:
#                    1) Reads the first line (database identifier) from the TSV.
#                    2) Strips the leading "#" and any whitespace from that line.
#                    3) Renames all files sharing the same prefix by appending
#                       "_<DB_NAME>" before the original suffix.
#  USAGE:          ./rename_metaphlan_profiles.sh [--dir DIRECTORY]
#                  --dir DIRECTORY   : Directory containing files (default: current directory)
#  AUTHOR:         Guilherme Bottino
#  DATE CREATED:   2025-06-05
#===============================================================================

# --------------------------------------
# 1) Check that required tools exist
# --------------------------------------
# We rely on standard POSIX utilities: head, tr, and mv.
required_tools=( head tr mv )
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "Error: '$tool' is not installed or not in your PATH." >&2
    echo "       Please install it before running this script." >&2
    exit 1
  fi
done

# --------------------------------------
# 2) Default parameters
# --------------------------------------
# By default, process files in the current directory.
DIR="./"

# --------------------------------------
# 3) Parse input arguments (optional)
# --------------------------------------
# Allow users to specify a different directory via --dir
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
    *)
      echo "Usage: $0 [--dir DIRECTORY]" >&2
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
# 5) Rename Metaphlan profiles to include DB name
# --------------------------------------
# For each file matching "*_profile.tsv" in $DIR:
#   a) Extract the prefix (everything before "_profile.tsv").
#   b) Read the first line of that TSV (should start with "#").
#   c) Strip the "#" and whitespace to get the database name.
#   d) Rename all files sharing the same prefix by inserting "_<DB_NAME>".
#
# Example:
#   Input files:
#     sampleA_profile.tsv      (first line: "# mpa_v30_CHOCOPhlAn_201901")
#     sampleA_clade.tsv
#     sampleA_others.txt
#
#   After running:
#     sampleA_mpa_v30_CHOCOPhlAn_201901_profile.tsv
#     sampleA_mpa_v30_CHOCOPhlAn_201901_clade.tsv
#     sampleA_mpa_v30_CHOCOPhlAn_201901_others.txt

echo "[$(date +%T)] Starting renaming of Metaphlan profiles in directory: $DIR"

# Iterate over all files ending in "_profile.tsv"
shopt -s nullglob
for profile_file in "$DIR"/*_profile.tsv; do
  # Extract the path without the "_profile.tsv" suffix
  base_path="${profile_file%_profile.tsv}"
  base_name="$(basename "$base_path")"

  # --------------------------------------
  # 5a) Read the first line to get the DB name
  # --------------------------------------
  if [[ -f "$profile_file" ]]; then
    # Read first line, remove leading '#' and strip whitespace
    db_name=$(head -n 1 "$profile_file" | tr -d '#' | tr -d '[:space:]')
    if [[ -z "$db_name" ]]; then
      echo "Warning: Database name is empty in file: $profile_file" >&2
      continue
    fi

    echo "[$(date +%T)] Processing prefix '$base_name' with DB name '$db_name'..."

    # --------------------------------------
    # 5b) Rename all files sharing this prefix
    # --------------------------------------
    for file in "$DIR"/"$base_name"*; do
      # Skip if the file already contains the DB name (to avoid double renaming)
      if [[ "$file" == *"_${db_name}"* ]]; then
        continue
      fi

      # Determine the suffix (everything after the base prefix)
      suffix="${file#$DIR/$base_name}"
      # Construct the new filename: <base>_<db_name><suffix>
      new_name="$DIR/${base_name}_${db_name}${suffix}"

      # Perform the move/rename
      echo "  → Renaming '$(basename "$file")' → '$(basename "$new_name")'"
      mv "$file" "$new_name"
    done
  else
    echo "Warning: Expected file '$profile_file' not found. Skipping." >&2
  fi
done
shopt -u nullglob

echo "[$(date +%T)] Renaming complete."