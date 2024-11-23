#!/bin/bash

# Input file and output directory
input_file="torrents-latest.txt"
output_dir="output_files"  # Change this to your desired output directory
output_prefix="${output_dir}/output"
max_entries=150000

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Initialize variables
entry_count=0
file_count=1
output_file="${output_prefix}.json"

# Initialize the first JSON array
echo "[]" > "$output_file"

# Function to write the JSON array to a file and start a new one
start_new_file() {
    # Finalize the current file
    jq -r --indent 0 '.[] | . * { source: "AnimeTosho" } | del(..|nulls)' "$output_file" > temp.json && mv temp.json "$output_file"

    # Increment file count and calculate the starting entry for the new file
    file_count=$((file_count + 1))
    start_entry=$((entry_count + 1))
    output_file="${output_prefix}-${start_entry}.json"

    # Initialize a new JSON array for the next file
    echo "[]" > "$output_file"
}

# Read each line of the file
while IFS= read -r line; do
    # Use `awk` with a tab as the delimiter
    name=$(echo "$line" | awk -F'\t' '{print $5}')
    size=$(echo "$line" | awk -F'\t' '{print $10}')
    infoHash=$(echo "$line" | awk -F'\t' '{print $7}')

    # Validate the extracted fields
    if [[ -z "$name" || -z "$size" || -z "$infoHash" ]]; then
        echo "Error: Missing data in line: $line"
        continue
    fi

    # Verify that infoHash contains "magnet:"
    if [[ "$infoHash" != magnet:* ]]; then
        echo "Skipping line, infoHash does not contain 'magnet:': $line"
        continue
    fi

    # Build a JSON object for the current line
    json_object=$(jq -n --arg name "$name" \
                          --arg size "$size" \
                          --arg infoHash "$infoHash" \
                          '{name: $name, size: $size, infoHash: $infoHash}')

    # Append the JSON object to the current output file
    jq ". + [$json_object]" "$output_file" > temp.json && mv temp.json "$output_file"

    # Increment entry count
    entry_count=$((entry_count + 1))

    # Check if the current file has reached the max entries
    if (( entry_count % max_entries == 0 )); then
        start_new_file
    fi
done < "$input_file"

# Finalize the last JSON file and ensure "AnimeTosho" is included
jq -r --indent 0 '.[] | . * { source: "AnimeTosho" } | del(..|nulls)' "$output_file" > temp.json && mv temp.json "$output_file"

echo "JSON files created in $output_dir"