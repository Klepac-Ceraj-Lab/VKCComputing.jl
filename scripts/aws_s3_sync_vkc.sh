#!/usr/bin/env bash
#===============================================================================
#  SCRIPT NAME:    aws_s3_sync_vkc.sh
#  DESCRIPTION:    Syncs data from an AWS S3 bucket (vkc‐nextflow) to a local
#                  directory. By default, it does a dry run; you can disable dry-run
#                  to actually copy files. Students will see clear timestamped
#                  messages for each step.
#  USAGE:          ./aws_s3_sync_vkc.sh [--dryrun] [--no-dryrun]
#                               [--profile PROFILE] [--source S3_PATH] [--dest LOCAL_PATH]
#  AUTHOR:         Guilherme Bottino
#  DATE CREATED:   2025-06-05
#===============================================================================

# --------------------------------------
# 1) Check that AWS CLI is installed
# --------------------------------------
if ! command -v aws &>/dev/null; then
  echo "Error: 'aws' CLI is not installed or not in your PATH." >&2
  echo "       Please install AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)" >&2
  exit 1
fi

# --------------------------------------
# 2) Default parameters
# --------------------------------------
# By default, we sync from s3://vkc-nextflow/ → /Volumes/thunderbay/Data/vkc-nextflow
# using profile "gbottino" and enabling --dryrun (so no files are copied until users remove --dryrun).
SOURCE="s3://vkc-nextflow/"
DEST="/Volumes/thunderbay/Data/vkc-nextflow"
PROFILE="gbottino"
DRYRUN="--dryrun"

# --------------------------------------
# 3) Parse input arguments (optional)
# --------------------------------------
# Allow users to override defaults via:
#   --dryrun       → keep dry-run mode on
#   --no-dryrun    → disable dry-run (actually copy the files)
#   --profile NAME → use AWS profile "NAME" instead of "gbottino"
#   --source PATH  → sync from a different S3 path
#   --dest PATH    → sync into a different local directory
#
# Example:
#   ./aws_s3_sync_vkc.sh --no-dryrun --profile mylab --source s3://my-bucket/ --dest /data/my-bucket
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dryrun)
      DRYRUN="--dryrun"
      shift
      ;;
    --no-dryrun)
      DRYRUN=""
      shift
      ;;
    --profile)
      if [[ -n "$2" ]]; then
        PROFILE="$2"
        shift 2
      else
        echo "Error: '--profile' requires an argument." >&2
        exit 1
      fi
      ;;
    --source)
      if [[ -n "$2" ]]; then
        SOURCE="$2"
        shift 2
      else
        echo "Error: '--source' requires an argument." >&2
        exit 1
      fi
      ;;
    --dest)
      if [[ -n "$2" ]]; then
        DEST="$2"
        shift 2
      else
        echo "Error: '--dest' requires an argument." >&2
        exit 1
      fi
      ;;
    *)
      echo "Usage: $0 [--dryrun] [--no-dryrun] [--profile PROFILE] [--source S3_PATH] [--dest LOCAL_PATH]" >&2
      exit 1
      ;;
  esac
done

# --------------------------------------
# 4) Display chosen configuration
# --------------------------------------
# This helps students verify that their flags were parsed correctly.
echo "[$(date +%T)] Sync configuration:"
echo "  Source S3 bucket: $SOURCE"
echo "  Destination:      $DEST"
echo "  AWS profile:      $PROFILE"
if [[ -n "$DRYUN" ]]; then
  echo "  Mode:             DRY RUN (files WILL NOT be copied)"
else
  echo "  Mode:             EXECUTE  (files WILL be copied)"
fi
echo

# --------------------------------------
# 5) Ensure destination directory exists
# --------------------------------------
# Creating the folder if it doesn't already exist avoids a cryptic error later.
if [[ ! -d "$DEST" ]]; then
  echo "[$(date +%T)] Creating destination directory: $DEST"
  mkdir -p "$DEST"
fi

# --------------------------------------
# 6) Run the aws s3 sync command
# --------------------------------------
#   --exact-timestamps ensures we only transfer if timestamps differ.
#   $DRYRUN will be either "--dryrun" or "" depending on flags.
echo "[$(date +%T)] Running: aws s3 sync $SOURCE → $DEST $DRYRUN"
aws s3 sync "$SOURCE" "$DEST" --profile "$PROFILE" --exact-timestamps $DRYRUN

# --------------------------------------
# 7) Completion message
# --------------------------------------
echo "[$(date +%T)] Done."