#!/bin/bash

# HTTP target URL
TARGET_URL="http://192.168.1.4:3333/import"

# Default delay in seconds
DELAY=300

# Process command line arguments for delay
for arg in "$@"; do
    if [[ $arg == --delay=* ]]; then
        DELAY="${arg#*=}"
    fi
done

# Function to display menu options
display_menu() {
    echo "Select an option:"
    echo "1. Import all files in the supplied folder automatically"
    echo "2. Semi-automatic import (select files to import)"
    echo "3. Supply an alternate folder"
}

# Function to save progress
save_progress() {
    echo "$file" > progress.txt
}

# Check if progress file exists
if [ -f progress.txt ]; then
    last_file=$(cat progress.txt)
    echo "Resuming from last processed file: $last_file"
else
    last_file=""
fi

# Get user choice from menu
display_menu
read -p "Enter your choice [1-3]: " choice

# Process the choice
if [ "$choice" -eq 1 ] || [ "$choice" -eq 2 ]; then
    if [ -z "$1" ]; then
        echo "Usage: $0 /path/to/directory [--delay=seconds]"
        exit 1
    fi
    DIRECTORY="${1%/}"  # Remove trailing slash if any

    # Load files into array and sort
    mapfile -t files < <(find "$DIRECTORY" -type f -print0 | sort -z | xargs -0)
    file_count=${#files[@]}
    
    echo "Found $file_count files in directory"

    if [ "$choice" -eq 1 ]; then
        # Automatic import
        for ((i=0; i<file_count; i++)); do
            file="${files[$i]}"
            echo "Processing file $((i+1))/$file_count: $file"
            # Your import logic here
            
            save_progress
            
            if [ $i -lt $((file_count-1)) ]; then
                echo "Waiting $DELAY seconds before next import..."
                sleep "$DELAY"
            fi
        done
    else
        # Semi-automatic import
        echo "Available files:"
        for ((i=0; i<file_count; i++)); do
            echo "$((i+1)): ${files[$i]}"
        done
        
        read -p "Enter file numbers to process (e.g., 1-3 5 7-9): " selection
        
        # Convert selection to array of numbers
        numbers=$(echo "$selection" | tr ',' ' ' | tr '-' ' ' | tr ' ' '\n' | sort -nu)
        
        for num in $numbers; do
            if [ "$num" -le "$file_count" ]; then
                file="${files[$((num-1))]}""
                echo "Processing: $file"
                # Your import logic here
                
                save_progress
                
                echo "Waiting $DELAY seconds before next import..."
                sleep "$DELAY"
            fi
        done
    fi

elif [ "$choice" -eq 3 ]; then
    # Option 3: Prompt for alternate folder
    read -p "Enter the path to the alternate folder: " DIRECTORY
    DIRECTORY="${DIRECTORY%/}"  # Remove trailing slash if any
    if [ ! -d "$DIRECTORY" ]; then
        echo "Error: The supplied path is not a valid directory."
        exit 1
    fi
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Get all "database-*.json" files sorted in descending order
files=($(ls -1 "$DIRECTORY"/database-*.json 2>/dev/null | sort -r))
file_count=${#files[@]}

if [ "$file_count" -eq 0 ]; then
    echo "No matching files found."
    exit 1
fi

# Debugging output for file list
echo "Files to process:"
for f in "${files[@]}"; do echo "$f"; done

# Ask user if they wish to import a specific range of files
if [ "$semi_automatic" = true ]; then
    read -p "Do you want to import a specific range of files? (y/n): " range_choice
    if [ "$range_choice" = "y" ]; then
        echo "Total files found: $file_count"
        read -p "Enter the file numbers to import (e.g., '1', '1-5', '1,3,5'): " file_selection

        # Parse file selection input
        selected_files=()
        IFS=',' read -ra entries <<< "$file_selection"
        for entry in "${entries[@]}"; do
            if [[ "$entry" =~ ^[0-9]+-[0-9]+$ ]]; then
                # Range of files
                start=${entry%-*}
                end=${entry#*-}
                for ((i=start; i<=end; i++)); do
                    selected_files+=("${files[i-1]}")
                done
            elif [[ "$entry" =~ ^[0-9]+$ ]]; then
                # Single file
                selected_files+=("${files[entry-1]}")
            fi
        done
    else
        # Prompt for approval of each file
        for file in "${files[@]}"; do
            read -p "Approve import of $file? (y/n): " approval
            if [ "$approval" = "y" ]; then
                selected_files+=("$file")
            fi
        done
    fi
else
    selected_files=("${files[@]}")
fi

# Loop through each selected file with a counter
counter=1
for file in "${selected_files[@]}"; do
    # Skip to the last processed file if resuming
    if [ -n "$last_file" ] && [ "$file" == "$last_file" ]; then
        last_file=""  # Clear so it only skips until last processed file
        continue
    fi

    if [ -f "$file" ]; then
        echo "Processing file #$counter: $file"

        # Run the command with the current file content
        cat "$file" | curl --verbose -H "Content-Type: application/json" -H "Connection: close" --data-binary @- "$TARGET_URL"

        # Save progress if in semi-automatic mode
        if [ "$semi_automatic" = true ]; then
            save_progress
        fi

        # Increment counter
        ((counter++))

        # Wait for 5 minute before processing the next file
        echo "Waiting for 5 minute..."
        sleep 300
    fi
done

# Cleanup progress file after completion
if [ "$semi_automatic" = true ] && [ -f progress.txt ]; then
    rm progress.txt
fi

echo "All files processed."
