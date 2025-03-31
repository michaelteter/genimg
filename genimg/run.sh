#!/bin/bash

# --- Configuration ---
# Set the path to your Swift executable
# Replace 'genimg' with the actual name of your compiled program
# Assumes it's in the standard Xcode build location relative to the script,
# adjust if necessary.
SWIFT_EXECUTABLE="./.build/debug/genimg"

# Default number of images to generate if not provided as an argument
DEFAULT_NUM_IMAGES=15
# Default generator name if not provided
DEFAULT_GENERATOR="basic"

# --- Git Auto-Commit Logic ---
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
    echo "[Error] Failed to commit changes. Please resolve issues manually."
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
echo "Command: $SWIFT_EXECUTABLE $GENERATOR_NAME $NUM_IMAGES $COMMIT_HASH"

# Execute the Swift program, passing generator, num_images, AND the commit hash
"$SWIFT_EXECUTABLE" "$GENERATOR_NAME" "$NUM_IMAGES" "$COMMIT_HASH"

# Check the exit status of the Swift program
EXIT_STATUS=$?
if [[ $EXIT_STATUS -eq 0 ]]; then
  echo "Swift program finished successfully."
else
  echo "[Warning] Swift program exited with status $EXIT_STATUS."
fi

exit $EXIT_STATUS

