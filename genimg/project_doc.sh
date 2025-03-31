#!/bin/bash

# --- Configuration ---

# The root directory to scan. Default is the current directory (.).
TARGET_DIR="."

# List of file extensions to include (e.g., ".swift" ".java" ".py" ".md").
# Add or remove extensions as needed. Remember the dot!
# Use spaces to separate extensions within the parentheses.
FILE_EXTENSIONS=(".swift")

# Character used for the divider line.
DIVIDER_CHAR="*"

# Approximate total length of the divider line.
DIVIDER_LENGTH=80

# --- End of Configuration ---

# --- Script Logic ---

# Function to print a divider line with the filename
print_divider() {
    local filename=$1
    local padding_char=$DIVIDER_CHAR
    local total_length=$DIVIDER_LENGTH

    # Prepare the core text: "**** <filename> "
    local prefix="**** ${filename} "
    local prefix_len=${#prefix}

    # Calculate how many padding characters are needed
    local suffix_len=$((total_length - prefix_len))

    # Ensure suffix_len is not negative (if filename is very long)
    if [ $suffix_len -lt 4 ]; then
        suffix_len=4 # Minimum padding
    fi

    # Create the suffix string of padding characters
    # 'printf' is used for creating repeated characters
    local suffix=$(printf "%${suffix_len}s" | tr ' ' "$padding_char")

    # Print the complete divider line
    echo "${prefix}${suffix}"
}

# 1. Output Directory Tree
echo "--- Project Directory Tree ---"
if command -v tree &> /dev/null; then
    # Use 'tree' if available. Exclude hidden files/dirs and common build/dependency dirs.
    # Add or remove exclusions as needed for your project type.
    tree "$TARGET_DIR" -I '.git|.DS_Store|*.xcodeproj|*.xcworkspace|build|Pods|node_modules|DerivedData' || echo "Tree command failed."
elif command -v find &> /dev/null; then
     # Fallback using 'find' if 'tree' is not installed
     echo "WARNING: 'tree' command not found. Using 'find' for a basic listing."
     echo "Install 'tree' for a better visual representation (e.g., 'brew install tree' or 'sudo apt install tree')."
     find "$TARGET_DIR" -not \( \
         \( -path "$TARGET_DIR/.git" -o -path "$TARGET_DIR/*.xcodeproj" -o -path "$TARGET_DIR/*.xcworkspace" -o -path "$TARGET_DIR/build" -o -path "$TARGET_DIR/Pods" -o -path "$TARGET_DIR/node_modules" -o -path "$TARGET_DIR/DerivedData" \) -prune \
         \) -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'
 else
    echo "ERROR: Neither 'tree' nor 'find' command found. Cannot generate directory listing."
 fi
echo # Add a newline for spacing
echo "--- Source File Contents ---"
echo # Add a newline for spacing


# 2. Construct 'find' command options for extensions
find_opts=()
if [ ${#FILE_EXTENSIONS[@]} -gt 0 ]; then
    first_ext=true
    for ext in "${FILE_EXTENSIONS[@]}"; do
        # Skip empty or invalid entries
        if [[ -z "$ext" || "$ext" == "." ]]; then
            continue
        fi
        # Add '-o' (OR operator) before the second and subsequent extensions
        if [ "$first_ext" = true ]; then
            first_ext=false
        else
            find_opts+=("-o")
        fi
        # Add the name pattern for the current extension
        find_opts+=("-name" "*${ext}")
    done
else
    echo "WARNING: No file extensions specified in FILE_EXTENSIONS array. No files will be processed."
    exit 0 # Exit cleanly if no extensions are defined
fi

# Check if we actually generated any options (prevents find error if array was empty/invalid)
if [ ${#find_opts[@]} -eq 0 ]; then
     echo "WARNING: No valid file extensions found in FILE_EXTENSIONS array. No files will be processed."
     exit 0
fi


# 3. Find and process files
# Use -print0 and read -d $'\0' for safety with filenames containing spaces or special chars
# Group the -name options with \( ... \) for correct precedence with -o
find "$TARGET_DIR" -type f \( "${find_opts[@]}" \) -print0 | while IFS= read -r -d $'\0' file; do
    # Exclude files within common hidden/build directories (redundant with tree exclusion, but safer)
     if [[ "$file" == *".git/"* || \
           "$file" == *".xcodeproj/"* || \
           "$file" == *".xcworkspace/"* || \
           "$file" == *"build/"* || \
           "$file" == *"Pods/"* || \
           "$file" == *"node_modules/"* || \
           "$file" == *"DerivedData/"* ]]; then
         continue # Skip this file
     fi

    # Get just the filename part
    filename=$(basename "$file")
    # Get the relative path from TARGET_DIR for better context in the divider
    relative_path="${file#$TARGET_DIR/}"
    if [[ "$TARGET_DIR" == "." ]]; then
         relative_path="${file#./}"
    fi


    # Print the top divider
    print_divider "$relative_path"

    # Print the file content
    cat "$file"

    # Print a couple of newlines for separation before the next file's divider
    echo
    echo
done

echo "--- End of Context ---"

# --- End of Script ---
