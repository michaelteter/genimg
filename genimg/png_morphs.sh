#!/usr/bin/env bash

# ==============================================================================
# png_morphs.sh
#
# Version: 2.0
#
# Description:
#   Creates a video file from all PNG images (case-insensitive extension) found
#   directly within a specified directory (non-recursive). Images transition
#   to the next using a crossfade effect.
#   Uses the 'zoompan' + 'framerate' filter technique as an alternative
#   to xfade chaining.
#
# Arguments:
#   $1: directory_path - Path to the directory containing PNG images.
#   $2: image_duration_ms - How long each image is fully visible (static duration, A).
#   $3: fade_duration_ms - How long the crossfade transition should last (B).
#
# Output:
#   Writes a video file named "output_morph_video.mp4" into the target directory.
#
# Requirements:
#   - ffmpeg: Must be installed and accessible.
#   - ffprobe: Usually installed with ffmpeg. Needed to get image dimensions.
#   - bc: Basic Calculator, usually pre-installed on macOS. Required for
#         floating-point calculations.
#
# Example Usage:
#   ./png_morphs.sh ~/Pictures/MySlideshow 1500 500
#   (Each image visible for 1.5s (A), with a 0.5s (B) crossfade transition)
# ==============================================================================

# --- Configuration ---
SCRIPT_VERSION="2.0" # New major version for different technique
OUTPUT_FILENAME="output_morph_video.mp4" # Name for the final video file
DEFAULT_FPS=25 # Desired output frame rate (Rate)

echo "--- PNG Morph Script (Zoompan Method) ---"
echo "Version: $SCRIPT_VERSION"

# --- Helper Functions ---

# Function to print usage instructions and exit
usage() {
  echo "Usage: $0 <directory_path> <image_duration_ms> <fade_duration_ms>" >&2
  echo "  <directory_path>: Path to the directory containing PNG images." >&2
  echo "  <image_duration_ms>: Static duration each image is visible (milliseconds)." >&2
  echo "  <fade_duration_ms>: Duration of the crossfade transition (milliseconds)." >&2
  exit 1
}

# --- Input Validation ---

# Check for correct number of arguments
if [ "$#" -ne 3 ]; then
  echo "Error: Incorrect number of arguments provided." >&2
  usage
fi

TARGET_DIR="$1"
MS_PER_FRAME="$2" # Duration A
MS_FADE="$3"      # Duration B

# Check if the first argument is a valid directory
if [ ! -e "$TARGET_DIR" ]; then
    echo "Error: Path not found: '$TARGET_DIR'" >&2
    exit 1
elif [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Path is not a directory: '$TARGET_DIR'" >&2
    exit 1
fi

# Check if duration arguments are positive integers
if ! [[ "$MS_PER_FRAME" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Image duration ('$MS_PER_FRAME') must be a positive integer." >&2
  usage
fi
# Fade duration must be positive for calculations (cannot divide by zero)
if ! [[ "$MS_FADE" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Fade duration ('$MS_FADE') must be a positive integer > 0." >&2
  usage
fi

# --- Dependency Checks ---
if ! command -v ffmpeg &> /dev/null; then
  echo "Error: 'ffmpeg' command not found." >&2; exit 1;
fi
if ! command -v ffprobe &> /dev/null; then
  echo "Error: 'ffprobe' command not found (usually installed with ffmpeg)." >&2; exit 1;
fi
if ! command -v bc &> /dev/null; then
  echo "Error: 'bc' command not found." >&2; exit 1;
fi

# --- Preparation ---

# Calculate durations A and B in seconds
bc_sec_per_frame=$(bc <<< "scale=3; $MS_PER_FRAME / 1000")
bc_sec_fade=$(bc <<< "scale=3; $MS_FADE / 1000")
SEC_PER_FRAME=$(printf "%.3f" "$bc_sec_per_frame") # Duration A
SEC_FADE=$(printf "%.3f" "$bc_sec_fade")          # Duration B

# Validate calculated durations (fade must be > 0)
if (( $(echo "$SEC_PER_FRAME <= 0" | bc -l) )); then
    echo "Error: Calculated image duration ($SEC_PER_FRAME s) is not positive." >&2; exit 1;
fi
if (( $(echo "$SEC_FADE <= 0" | bc -l) )); then
    echo "Error: Calculated fade duration ($SEC_FADE s) must be positive." >&2; exit 1;
fi

echo "Info: Image static duration (A): $SEC_PER_FRAME seconds."
echo "Info: Crossfade duration (B): $SEC_FADE seconds."

# Calculate C = floor((A+B)/B) - must be integer >= 1
# Check for division by zero already done by validating SEC_FADE > 0
C_VAL=$(bc <<< "scale=0; ($SEC_PER_FRAME + $SEC_FADE) / $SEC_FADE")
if [ -z "$C_VAL" ] || [ "$C_VAL" -lt 1 ]; then
    echo "Error: Failed to calculate C value or C < 1. Check durations." >&2; exit 1;
fi
echo "Info: Calculated zoompan 'd' value (C = floor((A+B)/B)): $C_VAL"

# Calculate D = 1/B - needs floating point
bc_d_val=$(bc <<< "scale=5; 1 / $SEC_FADE") # Use more precision for intermediate rate
D_VAL=$(printf "%.5f" "$bc_d_val")
if (( $(echo "$D_VAL <= 0" | bc -l) )); then
    echo "Error: Calculated zoompan 'fps' value (D = 1/B) is not positive." >&2; exit 1;
fi
echo "Info: Calculated zoompan 'fps' value (D = 1/B): $D_VAL"


# Resolve absolute path for target directory
if [[ "$TARGET_DIR" == /* ]]; then
  ABS_TARGET_DIR="$TARGET_DIR"
else
  if [ -d "$TARGET_DIR" ]; then
      ABS_TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
  else
      echo "Error: Relative directory '$TARGET_DIR' not found or inaccessible." >&2; exit 1;
  fi
fi
if [ -z "$ABS_TARGET_DIR" ] || [ ! -d "$ABS_TARGET_DIR" ]; then
    echo "Error: Could not resolve absolute path for '$TARGET_DIR'." >&2; exit 1;
fi
OUTPUT_VIDEO_PATH="${ABS_TARGET_DIR}/${OUTPUT_FILENAME}"


# --- Get Image Dimensions and Count Files ---

echo "Info: Searching for PNG files and getting dimensions from first image..."
first_image_path=""
num_images=0

# Use find to get the first PNG file and count total PNGs
# Need to cd first because ffprobe needs path, and find needs to run there
pushd "$ABS_TARGET_DIR" > /dev/null || { echo "Error: Could not navigate to '$ABS_TARGET_DIR'." >&2; exit 1; }

# Find first PNG for ffprobe
first_image_rel_path=$(find . -maxdepth 1 -type f -iname '*.png' -print -quit)

if [ -z "$first_image_rel_path" ]; then
  echo "Error: No PNG files found directly in '$ABS_TARGET_DIR'." >&2
  popd > /dev/null
  exit 1
fi
first_image_path="${ABS_TARGET_DIR}/${first_image_rel_path#./}"

# Count all PNGs (less efficient than finding first, but needed)
# Store paths in array for count, though not used directly by ffmpeg command here
image_files_array=()
while IFS= read -r -d $'\0' file; do
  image_files_array+=("$file") # Store relative path for count is fine
done < <(find . -maxdepth 1 -type f -iname '*.png' -print0 | sort -z)
num_images=${#image_files_array[@]}

popd > /dev/null # Return from directory

echo "Info: Found $num_images PNG files."
echo "Info: Using first image for dimensions: $first_image_path"

# Get dimensions using ffprobe
dimensions=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$first_image_path")
if [ $? -ne 0 ] || ! [[ "$dimensions" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]; then
    echo "Error: Failed to get valid dimensions (WxH) from '$first_image_path' using ffprobe." >&2
    exit 1
fi
IMG_W=$(echo "$dimensions" | cut -d'x' -f1)
IMG_H=$(echo "$dimensions" | cut -d'x' -f2)
echo "Info: Detected dimensions: ${IMG_W}x${IMG_H}"


# --- Build and Run FFmpeg Command ---

# Handle cases based on number of images
if [ "$num_images" -eq 1 ]; then
  # --- Case: Only 1 image ---
  echo "Info: Only one image found. Creating video without transitions..."
  # Simple command: Show the single image for duration A (SEC_PER_FRAME)
  ffmpeg_command="ffmpeg -loop 1 -i '$first_image_path' -t $SEC_PER_FRAME -c:v libx264 -r $DEFAULT_FPS -pix_fmt yuv420p -movflags +faststart -y '$OUTPUT_VIDEO_PATH'"

else
  # --- Case: 2 or more images ---
  echo "Info: Building command using 'zoompan' + 'framerate' filters..."

  # Construct the filter chain string
  # zoompan duplicates frames based on C and outputs at rate D
  # framerate interpolates between all frames from zoompan at the final rate
  filter_chain="zoompan=d=$C_VAL:fps=$D_VAL:s=${IMG_W}x${IMG_H},framerate=fps=$DEFAULT_FPS:interp_start=0:interp_end=255:scene=100"

  # Construct the full ffmpeg command
  # Need to run ffmpeg from *within* the image directory for the glob pattern
  # Use absolute path for output file
  # Use case-insensitive glob pattern
  # NOTE: No explicit output -t needed; should process all images from pattern
  ffmpeg_command="cd '$ABS_TARGET_DIR' && ffmpeg -pattern_type glob -i '*.png' -vf \"$filter_chain\" -c:v libx264 -r $DEFAULT_FPS -pix_fmt yuv420p -movflags +faststart -y '$OUTPUT_VIDEO_PATH'"
  # Alternative input using find | concat demuxer (might be safer for filenames)
  # Requires creating the list file first with 'duration (A+B)' for each file
  # Then: ffmpeg -f concat -safe 0 -i list.txt -vf "..." ...
  # Let's stick with glob for now as it matches the example's likely input method

fi


# --- Execute FFmpeg ---
echo "Info: Starting video creation process..."
echo "Info: Output video will be saved as: '$OUTPUT_VIDEO_PATH'"
# Optional: uncomment to see the full command being executed
echo "Executing FFmpeg command:"
echo "$ffmpeg_command" # Note: This shows the 'cd ... && ffmpeg ...' structure

# Use eval to execute the command string which includes 'cd'
eval "$ffmpeg_command"

# Check the exit status of the ffmpeg command
# $? captures the exit status of the *last* command run by eval (should be ffmpeg)
if [ $? -eq 0 ]; then
  echo "Success: Video created successfully!"
  echo "Output file: '$OUTPUT_VIDEO_PATH'"
else
  echo "Error: ffmpeg command failed during video creation." >&2
  echo "Check ffmpeg output above for specific error messages." >&2
  exit 1 # Exit with a non-zero status to indicate failure
fi

exit 0

