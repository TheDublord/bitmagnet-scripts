#!/bin/bash

# HTTP target URL
TARGET_URL="http://192.168.1.4:3333/import"

# Default delay in seconds
DELAY=300
DIRECTORY=""

# Process command line arguments for directory and delay
while [[ $# -gt 0 ]]; do
    case $1 in
        --delay=*)
            DELAY="${1#*=}"
            shift
            ;;
        *)
            if [ -z "$DIRECTORY" ]; then
                DIRECTORY="${1%/}"  # Remove trailing slash
                shift
            else
                echo "Unknown option: $1"
                exit 1
            fi
            ;;
    esac
done

# Validate directory
if [ -z "$DIRECTORY" ]; then
    echo "Usage: $0 /path/to/directory [--delay=seconds]"
    exit 1
fi

if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory '$DIRECTORY' does not exist"
    exit 1
fi

# Load files into array and sort in ascending order
mapfile -t files < <(find "$DIRECTORY" -type f | sort)
file_count=${#files[@]}

echo "Found $file_count files in directory"

# Function to display menu options
display_menu() {
    echo "Select an option:"
    echo "1. Import all files automatically"
    echo "2. Select files to import"
}

# Get user choice from menu
display_menu
read -p "Enter your choice [1-2]: " choice

# Process the choice
if [ "$choice" -eq 1 ]; then
    # Automatic import
    for ((i=0; i<file_count; i++)); do
        file="${files[$i]}"
        echo "Processing file $((i+1))/$file_count: $file"
        # Import logic
        cat "$file" | curl --verbose -H "Content-Type: application/json" -H "Connection: close" --data-binary @- "$TARGET_URL"

        if [ $i -lt $((file_count-1)) ]; then
            echo "Waiting $DELAY seconds before next import..."
            sleep "$DELAY"
        fi
    done
elif [ "$choice" -eq 2 ]; then
    # Semi-automatic import
    echo "Available files:"
    for ((i=0; i<file_count; i++)); do
        echo "$((i+1)): ${files[$i]}"
    done

    read -p "Enter file numbers to process (e.g., 1,3,5-7): " selection

    # Replace commas with spaces and parse selection
    selection="${selection//,/ }"

    # Expand selection into array of indices
    indices=()
    for part in $selection; do
        if [[ $part =~ ^[0-9]+$ ]]; then
            # Single number
            indices+=($((part-1)))
        elif [[ $part =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Range of numbers
            start=${BASH_REMATCH[1]}
            end=${BASH_REMATCH[2]}
            for ((j=start-1; j<=end-1; j++)); do
                indices+=($j)
            done
        else
            echo "Invalid input: $part"
            exit 1
        fi
    done

    # Remove duplicates and sort
    indices=($(printf "%s\n" "${indices[@]}" | sort -nu))

    for idx in "${indices[@]}"; do
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "$file_count" ]; then
            file="${files[$idx]}"
            echo "Processing: $file"
            # Import logic
            cat "$file" | curl --verbose -H "Content-Type: application/json" -H "Connection: close" --data-binary @- "$TARGET_URL"

            if [ "$idx" -ne "${indices[-1]}" ]; then
                echo "Waiting $DELAY seconds before next import..."
                sleep "$DELAY"
            fi
        else
            echo "Invalid file number: $((idx+1))"
        fi
    done
else
    echo "Invalid choice"
    exit 1
fi
