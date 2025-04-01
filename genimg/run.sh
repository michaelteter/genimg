#!/bin/bash

# --- Configuration ---
# Set your Xcode scheme name.
# You confirmed it is 'genimg'.
XCODE_SCHEME_NAME="genimg"

# Set the relative path from this script's directory to the .xcodeproj file
# Since your script is in a subdirectory, this will likely be '../<YourProjectName>.xcodeproj'
# Assuming your project file is named 'genimg.xcodeproj' in the parent directory:
XCODE_PROJECT_FILE="../genimg.xcodeproj" # <-- ADJUST IF YOUR .xcodeproj FILE IS NAMED DIFFERENTLY OR LOCATED ELSEWHERE

# Default number of images to generate if not provided as an argument
DEFAULT_NUM_IMAGES=1
# Default generator name if not provided
DEFAULT_GENERATOR="basic"

# --- Check if Project File Exists ---
if [[ ! -e "$XCODE_PROJECT_FILE" ]]; then
    echo "[Error] Xcode project file not found at the specified path:"
    echo "        '$XCODE_PROJECT_FILE'"
    echo "        Please check the XCODE_PROJECT_FILE variable in this script."
    exit 1
fi

# --- Build Project with xcodebuild ---
echo "Building project '$XCODE_PROJECT_FILE' with xcodebuild (Scheme: $XCODE_SCHEME_NAME)..."
# Build using xcodebuild, specifying the project file.
# Add -quiet for less verbose output, remove it for debugging build issues.
xcodebuild -quiet -project "$XCODE_PROJECT_FILE" -scheme "$XCODE_SCHEME_NAME" build # -quiet

# Check the exit status of xcodebuild
BUILD_STATUS=$?
if [[ $BUILD_STATUS -ne 0 ]]; then
  echo "[Error] xcodebuild failed with status $BUILD_STATUS. Please check build logs."
  echo "        Build output might be suppressed if '-quiet' is used above."
  exit 1 # Exit the script if build fails
else
  echo "Xcode build successful."
fi

# --- Dynamically Determine Executable Path ---
echo "Determining executable path from build settings..."
# Get build settings, specifying the project file
BUILD_SETTINGS=$(xcodebuild -project "$XCODE_PROJECT_FILE" -scheme "$XCODE_SCHEME_NAME" -showBuildSettings)

# Extract TARGET_BUILD_DIR
# Uses grep to find the line, then awk to get the value after '= '
TARGET_BUILD_DIR=$(echo "${BUILD_SETTINGS}" | grep -E '^\s*TARGET_BUILD_DIR =' | awk -F '= ' '{print $2}')

# Extract EXECUTABLE_PATH
# Uses grep to find the line, then awk to get the value after '= '
EXECUTABLE_PATH=$(echo "${BUILD_SETTINGS}" | grep -E '^\s*EXECUTABLE_PATH =' | awk -F '= ' '{print $2}')

# Check if paths were extracted successfully
if [[ -z "$TARGET_BUILD_DIR" || -z "$EXECUTABLE_PATH" ]]; then
    echo "[Error] Could not parse TARGET_BUILD_DIR or EXECUTABLE_PATH from xcodebuild settings."
    echo "        Run 'xcodebuild -project \"$XCODE_PROJECT_FILE\" -scheme \"$XCODE_SCHEME_NAME\" -showBuildSettings' manually to check."
    exit 1
fi

# Construct the full path
# Note: EXECUTABLE_PATH usually includes the executable name itself.
DYNAMIC_EXECUTABLE_PATH="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"

# Check if the dynamically found executable exists and is executable
if [[ ! -x "$DYNAMIC_EXECUTABLE_PATH" ]]; then
    echo "[Error] Dynamically determined executable path does not exist or is not executable:"
    echo "        '$DYNAMIC_EXECUTABLE_PATH'"
    echo "        Check build settings and permissions."
    exit 1
fi

echo "Found executable at: $DYNAMIC_EXECUTABLE_PATH"


# --- Git Auto-Commit Logic ---
# IMPORTANT: Assumes this script is within the Git repository, even if in a subfolder.
# Git commands generally operate relative to the repository root found by searching upwards.
echo "Checking for uncommitted changes..."

# Check git status. --porcelain gives script-friendly output.
# If output is empty, repo is clean.
if [[ -z $(git status --porcelain) ]]; then
  echo "No changes detected. Using current commit."
else
  echo "Changes detected. Staging and committing..."
  # Add all changes (respects .gitignore)
  git add .

  # Commit changes with a generic message
  # Use --quiet to reduce output unless there's an error
  if git commit --quiet -m "Auto-commit before run [$(date)]"; then
    echo "Changes committed successfully."
  else
    echo "[Error] Failed to commit changes. Please resolve issues manually (e.g., merge conflicts)."
    exit 1 # Exit the script if commit fails
  fi
fi

# --- Get Commit Hash ---
# Get the short version of the latest commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)
if [[ -z "$COMMIT_HASH" ]]; then
  echo "[Error] Failed to get Git commit hash."
  exit 1
fi
echo "Using commit hash: $COMMIT_HASH"

# --- Parse Optional Arguments for Swift Program ---
# Use defaults if arguments are not provided
GENERATOR_NAME=${1:-$DEFAULT_GENERATOR} # Use first arg or default
NUM_IMAGES=${2:-$DEFAULT_NUM_IMAGES}    # Use second arg or default

# --- Execute Swift Program ---
echo "Running generative art program..."
echo "Executable: $DYNAMIC_EXECUTABLE_PATH"
echo "Arguments: $GENERATOR_NAME $NUM_IMAGES $COMMIT_HASH"

# Execute the Swift program, passing generator, num_images, AND the commit hash
# Use the dynamically determined path. Ensure it's quoted.
"$DYNAMIC_EXECUTABLE_PATH" "$GENERATOR_NAME" "$NUM_IMAGES" "$COMMIT_HASH"

# Check the exit status of the Swift program
EXIT_STATUS=$?
if [[ $EXIT_STATUS -eq 0 ]]; then
  echo "Swift program finished successfully."
else
  echo "[Warning] Swift program exited with status $EXIT_STATUS."
fi

exit $EXIT_STATUS

