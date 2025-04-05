#!/usr/bin/env bash

# ==============================================================================
# png_to_video.sh
#
# Version: 1.1
#
# Description:
#   Creates a video file from all PNG images (case-insensitive extension) found
#   directly within a specified directory (non-recursive). Each image is
#   displayed for a user-defined duration.
#   Writes absolute paths to the temporary list file for ffmpeg.
#
# Arguments:
#   $1: directory_path - The full or relative path to the directory
#                       containing the PNG images.
#   $2: milliseconds_per_image - The duration (in milliseconds) to display
#                                each image in the resulting video.
#
# Output:
#   Writes a video file named "output_video.mp4" into the target directory.
#
# Requirements:
#   - ffmpeg: Must be installed and accessible in the system's PATH.
#             Install via Homebrew: `brew install ffmpeg`
#   - bc: Basic Calculator, usually pre-installed on macOS. Required for
#         floating-point calculations.
#
# Example Usage:
#   ./png_to_video.sh ~/Pictures/MySlideshow 500
#   (This processes PNGs in ~/Pictures/MySlideshow, showing each for 500ms)
# ==============================================================================

# --- Configuration ---
SCRIPT_VERSION="1.1" # Updated version
OUTPUT_FILENAME="output_video.mp4" # Name for the final video file
DEFAULT_FPS=25 # A standard output frame rate for compatibility

echo "--- PNG to Video Script ---"
echo "Version: $SCRIPT_VERSION"

# --- Helper Functions ---

# Function to print usage instructions and exit
usage() {
  echo "Usage: $0 <directory_path> <milliseconds_per_image>" >&2 # Print errors to stderr
  echo "  <directory_path>: Path to the directory containing PNG images." >&2
  echo "  <milliseconds_per_image>: How long each image should be displayed (e.g., 500 for half a second)." >&2
  exit 1
}

# --- Input Validation ---

# Check for correct number of arguments
if [ "$#" -ne 2 ]; then
  echo "Error: Incorrect number of arguments provided." >&2
  usage
fi

TARGET_DIR="$1"
MS_PER_FRAME="$2"

# Check if the first argument is a valid directory
# Use -e to check if it exists, then -d to check if it's a directory
if [ ! -e "$TARGET_DIR" ]; then
    echo "Error: Path not found: '$TARGET_DIR'" >&2
    exit 1
elif [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Path is not a directory: '$TARGET_DIR'" >&2
    exit 1
fi

# Check if the second argument is a positive integer
if ! [[ "$MS_PER_FRAME" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Milliseconds per image ('$MS_PER_FRAME') must be a positive integer." >&2
  usage
fi

# Check if ffmpeg command is available
if ! command -v ffmpeg &> /dev/null; then
  echo "Error: 'ffmpeg' command not found." >&2
  echo "Please install ffmpeg to use this script." >&2
  echo "Suggestion: If you use Homebrew, run 'brew install ffmpeg'" >&2
  exit 1
fi

# Check if bc (basic calculator for floating point math) is available
if ! command -v bc &> /dev/null; then
  echo "Error: 'bc' command not found. This script requires 'bc' for time calculations." >&2
  # On most macOS systems, bc should be present. If not, it might require Xcode Command Line Tools.
  exit 1
fi


# --- Preparation ---

# Calculate duration per frame in seconds (using bc for floating-point precision)
# scale=3 means keep 3 decimal places
SEC_PER_FRAME=$(bc <<< "scale=3; $MS_PER_FRAME / 1000")
# Check if bc calculation resulted in a non-positive number (e.g., if MS_PER_FRAME was too small)
# Using bc for comparison handles potential floating point results like 0.000
if (( $(echo "$SEC_PER_FRAME <= 0" | bc -l) )); then
    echo "Error: Calculated seconds per frame ($SEC_PER_FRAME) is not positive. Check milliseconds input ('$MS_PER_FRAME')." >&2
    exit 1
fi
echo "Info: Each image will be shown for $SEC_PER_FRAME seconds."

# Define the full path for the output video file
# Resolve potential relative paths in TARGET_DIR to an absolute path for robustness
# Check if TARGET_DIR is already absolute
if [[ "$TARGET_DIR" == /* ]]; then
  ABS_TARGET_DIR="$TARGET_DIR"
else
  # If relative, combine with current PWD and simplify (remove .. etc)
  # Ensure the directory exists before trying to cd into it for pwd
  if [ -d "$TARGET_DIR" ]; then
      ABS_TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
  else
      # This case should technically be caught earlier, but double-check
      echo "Error: Relative directory '$TARGET_DIR' not found or inaccessible for path resolution." >&2
      exit 1
  fi
fi
# Handle potential failure of cd/pwd if TARGET_DIR becomes invalid between check and here
if [ -z "$ABS_TARGET_DIR" ] || [ ! -d "$ABS_TARGET_DIR" ]; then
    echo "Error: Could not resolve absolute path for '$TARGET_DIR'." >&2
    exit 1
fi
OUTPUT_VIDEO_PATH="${ABS_TARGET_DIR}/${OUTPUT_FILENAME}"


# Create a temporary file to list the input images for ffmpeg's concat demuxer
# Using mktemp is safer as it creates a unique filename and avoids collisions
LIST_FILE=$(mktemp) || { echo "Error: Failed to create temporary file." >&2; exit 1; }

# Ensure the temporary list file is reliably removed when the script exits
# This trap catches normal exit (EXIT), hangup (HUP), interrupt (INT), quit (QUIT), terminate (TERM)
trap 'echo "Info: Cleaning up temporary file: $LIST_FILE"; rm -f "$LIST_FILE"' EXIT HUP INT QUIT TERM

# --- Generate Input List for FFmpeg ---

echo "Info: Searching for PNG files (case-insensitive) in '$ABS_TARGET_DIR' (non-recursive)..."

# Navigate into the target directory temporarily to simplify find paths relative to it
# Use pushd/popd to manage directory stack
pushd "$ABS_TARGET_DIR" > /dev/null || { echo "Error: Could not navigate to '$ABS_TARGET_DIR'. Check permissions." >&2; exit 1; }

# Use find to get PNG files ONLY in the current directory (maxdepth 1)
# -type f ensures we only get files, not directories named .png
# -iname '*.png': Use case-insensitive matching for the extension (matches .png, .PNG, .Png, etc.)
# -print0 uses null character as separator, robust for filenames with spaces/special chars
# sort -z sorts the null-separated list alphabetically
#
# Use Process Substitution (< <(...)) instead of pipe (|)
# This ensures the 'while' loop runs in the current shell, so 'found_files' updates correctly.
#
found_files=0
while IFS= read -r -d $'\0' file; do
  # 'file' contains the relative path (e.g., ./art_....png) from find
  # Remove leading './' if present
  clean_file="${file#./}"

  # *** MODIFIED PART: Construct absolute path ***
  abs_file_path="${ABS_TARGET_DIR}/${clean_file}"

  # Add the *absolute* file path and its duration to the temporary list file
  # Format:
  # file '/path/to/images/image1.png'
  # duration 0.500
  # file '/path/to/images/image2.png'
  # duration 0.500
  # ...
  printf "file '%s'\nduration %s\n" "$abs_file_path" "$SEC_PER_FRAME" >> "$LIST_FILE"
  # *** END OF MODIFIED PART ***

  found_files=$((found_files + 1))
done < <(find . -maxdepth 1 -type f -iname '*.png' -print0 | sort -z)


# Return to the original directory
popd > /dev/null

# Check if any PNG files were actually found (this check should now work correctly)
if [ "$found_files" -eq 0 ]; then
  echo "Error: No PNG files found directly in '$ABS_TARGET_DIR' (checked case-insensitively)." >&2
  echo "Info: This script does NOT search subdirectories because '-maxdepth 1' is used." >&2
  # Trap will still execute for cleanup
  exit 1
fi

echo "Info: Found $found_files PNG files. Prepared ffmpeg input list: $LIST_FILE"
# Optional: uncomment to see the generated list file for debugging
# echo "--- Start of List File ($LIST_FILE) ---"
# cat "$LIST_FILE"
# echo "--- End of List File ---"


# --- Run FFmpeg ---

echo "Info: Starting video creation process..."
echo "Info: Output video will be saved as: '$OUTPUT_VIDEO_PATH'"

# Execute ffmpeg command:
# Since the LIST_FILE now contains absolute paths, ffmpeg can find the images
# regardless of the current working directory.
# -f concat: Use the concatenation demuxer format.
# -safe 0: Still recommended with concat demuxer, especially if paths might contain special chars,
#          even though we now use absolute paths.
# -i "$LIST_FILE": Specify the generated list file as the input source.
# -c:v libx264: Select the H.264 video codec (highly compatible, good quality/compression).
# -r "$DEFAULT_FPS": Set a standard output frame rate (e.g., 25 fps). The concat demuxer
#                    handles the precise timing of *input* frames based on the 'duration' directives.
#                    Setting an output FPS ensures smooth playback in standard players.
# -pix_fmt yuv420p: Choose a common pixel format for maximum compatibility across devices/players.
# -movflags +faststart: Optimize the MP4 container for web streaming by moving metadata to the beginning.
# -y: Overwrite the output file without asking (remove this flag if you prefer confirmation).
ffmpeg -f concat -safe 0 -i "$LIST_FILE" -c:v libx264 -r "$DEFAULT_FPS" -pix_fmt yuv420p -movflags +faststart -y "$OUTPUT_VIDEO_PATH"

# Check the exit status of the ffmpeg command
if [ $? -eq 0 ]; then
  echo "Success: Video created successfully!"
  echo "Output file: '$OUTPUT_VIDEO_PATH'"
else
  echo "Error: ffmpeg command failed during video creation." >&2
  echo "Check ffmpeg output above for specific error messages." >&2
  # Trap will still execute for cleanup
  exit 1 # Exit with a non-zero status to indicate failure
fi

# Script finished successfully. The trap will run for cleanup.
exit 0

