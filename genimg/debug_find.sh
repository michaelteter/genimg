#!/usr/bin/env bash

# ==============================================================================
# debug_find.sh
#
# Description:
#   A simple script to test finding PNG files in a hardcoded directory
#   using the 'find | sort | while read' construct with process substitution.
#   It just prints the files it finds.
#
# Target Directory (Hardcoded):
#   /Users/mteter/work/genart/swift/genimg/images
# ==============================================================================

# Hardcode the target directory
TARGET_DIR="/Users/mteter/work/genart/swift/genimg/images"

echo "--- Debug Find Script Start ---"
echo "Target Directory: $TARGET_DIR"

# Check if the target directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Hardcoded directory not found: '$TARGET_DIR'" >&2
  exit 1
fi

echo "Navigating into directory..."
# Navigate into the target directory temporarily
pushd "$TARGET_DIR" > /dev/null || { echo "Error: Could not navigate to '$TARGET_DIR'. Check permissions." >&2; exit 1; }

echo "Starting find and loop..."

# Use find to get PNG files ONLY in the current directory (maxdepth 1)
# -type f ensures we only get files.
# -iname '*.png': Case-insensitive matching for the extension.
# -print0 uses null character as separator.
# sort -z sorts the null-separated list alphabetically.
# Use Process Substitution (< <(...)) to feed the while loop.
files_processed=0
while IFS= read -r -d $'\0' file; do
  # Just echo the filename found (relative to the TARGET_DIR)
  echo "  -> Found file: $file"
  files_processed=$((files_processed + 1))
done < <(find . -maxdepth 1 -type f -iname '*.png' -print0 | sort -z)

echo "Finished find and loop."
echo "Total files processed in loop: $files_processed"

# Return to the original directory
popd > /dev/null

echo "Returned from directory."
echo "--- Debug Find Script End ---"

exit 0

