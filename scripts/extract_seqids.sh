#!/usr/bin/env bash
#===============================================================================
#  SCRIPT NAME:    extract_prefixes.sh
#  DESCRIPTION:    Lists unique filename prefixes in a directory up to a specified
#                  limiter string. For every file in the directory that contains
#                  the limiter, the portion of the filename before the limiter is
#                  printed, and duplicates are removed.
#  USAGE:          ./extract_prefixes.sh --folder /path/to/folder --limiter _L00
#                    --folder DIRECTORY : Directory to scan for files
#                    --limiter STRING   : Delimiter in filenames (e.g., "_L001")
#  AUTHOR:         Guilherme Bottino
#  DATE CREATED:   2025-06-05
#===============================================================================

# --------------------------------------
# 1) Check that required tools exist
# --------------------------------------
required_tools=( find basename sort )
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
folder=""
limiter=""

# --------------------------------------
# 3) Parse named arguments
# --------------------------------------
# Recognized flags:
#   --folder  : Directory to search (e.g., /Volumes/data/myfolder)
#   --limiter : Substring delimiting where to cut the filename (e.g., "_L001")
while [[ $# -gt 0 ]]; do
  case "$1" in
    --folder)
      if [[ -n "$2" ]]; then
        folder="$2"
        shift 2
      else
        echo "Error: '--folder' requires a directory path." >&2
        exit 1
      fi
      ;;
    --limiter)
      if [[ -n "$2" ]]; then
        limiter="$2"
        shift 2
      else
        echo "Error: '--limiter' requires a non-empty string." >&2
        exit 1
      fi
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 --folder /path/to/folder --limiter _LIMITER" >&2
      exit 1
      ;;
  esac
done

# --------------------------------------
# 4) Validate arguments
# --------------------------------------
if [[ -z "$folder" || -z "$limiter" ]]; then
  echo "Usage: $0 --folder /path/to/folder --limiter _LIMITER" >&2
  exit 1
fi

if [[ ! -d "$folder" ]]; then
  echo "Error: '$folder' is not a valid directory." >&2
  exit 1
fi

# --------------------------------------
# 5) Extract unique prefixes up to the limiter
# --------------------------------------
# For each regular file in the specified directory:
#   1) Check if its basename contains the limiter string.
#   2) If so, split the basename at the first occurrence of limiter.
#   3) Print the prefix (portion before limiter).
# Finally, sort the prefixes and remove duplicates.
echo "[$(date +%T)] Scanning directory: $folder"
echo "[$(date +%T)] Using limiter: '$limiter'"
echo

find "$folder" -maxdepth 1 -type f | while read -r filepath; do
  filename=$(basename "$filepath")

  # Only process files whose name contains the limiter substring
  if [[ "$filename" == *"$limiter"* ]]; then
    # Extract prefix: everything before the first occurrence of limiter
    prefix="${filename%%"$limiter"*}"
    echo "$prefix"
  fi
done | sort -u

echo
echo "[$(date +%T)] Prefix extraction complete."