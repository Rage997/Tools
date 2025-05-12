#!/bin/bash

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS] INPUT_FOLDER OUTPUT_FILE"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -s, --size SIZE      Force specific square size in pixels (optional)"
    echo "  -f, --filter PATTERN Filter images by pattern (e.g., '*.png', default: all images)"
    echo "  -r, --resize         Resize images instead of cropping (preserves content but may distort)"
    echo ""
    echo "Examples:"
    echo "  $0 ./screenshots combined.png               # Process all images"
    echo "  $0 -f '*.png' ./screenshots combined.png    # Process only PNG files"
    echo "  $0 -s 300 ./release_images combined.png     # Force 300x300 square size"
    exit 1
}

# Default values
FILTER="*.jpg *.jpeg *.png *.gif *.bmp *.tiff"
FORCE_SIZE=0
RESIZE=false

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -s|--size)
            FORCE_SIZE=$2
            shift 2
            ;;
        -f|--filter)
            FILTER=$2
            shift 2
            ;;
        -r|--resize)
            RESIZE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

INPUT_FOLDER=$1
OUTPUT_FILE=$2

# Check if ImageMagick is installed
if ! command -v identify &> /dev/null || ! command -v convert &> /dev/null; then
    echo "ImageMagick is not installed. Please install it with 'sudo apt-get install imagemagick'"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Creating temporary directory: $TEMP_DIR"

# Find all image files in the input folder
echo "Searching for images in: $INPUT_FOLDER"
IMAGE_FILES=()
for pattern in $FILTER; do
    while IFS= read -r -d $'\0' file; do
        IMAGE_FILES+=("$file")
    done < <(find "$INPUT_FOLDER" -maxdepth 1 -type f -name "$pattern" -print0 | sort -z)
done

# Check if any images were found
if [ ${#IMAGE_FILES[@]} -eq 0 ]; then
    echo "No image files found in $INPUT_FOLDER matching the pattern: $FILTER"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Found ${#IMAGE_FILES[@]} images"

# Calculate minimum dimension if not forced
if [ $FORCE_SIZE -eq 0 ]; then
    # Get dimensions of all images
    min_size=999999
    for img in "${IMAGE_FILES[@]}"; do
        dimensions=$(identify -format "%w %h" "$img")
        width=$(echo $dimensions | cut -d' ' -f1)
        height=$(echo $dimensions | cut -d' ' -f2)
        
        # Find the smaller dimension of this image
        if [ $width -lt $height ]; then
            img_min=$width
        else
            img_min=$height
        fi
        
        # Update the global minimum if needed
        if [ $img_min -lt $min_size ]; then
            min_size=$img_min
        fi
    done
else
    min_size=$FORCE_SIZE
fi

echo "Using square size of ${min_size}x${min_size} pixels"

# Process each image
processed_files=()
count=0
for img in "${IMAGE_FILES[@]}"; do
    count=$((count + 1))
    filename=$(basename "$img")
    output_path="${TEMP_DIR}/${count}_${filename}"
    
    echo "Processing ($count/${#IMAGE_FILES[@]}): $filename"
    
    if [ "$RESIZE" = true ]; then
        # Resize the image (may distort)
        convert "$img" -resize ${min_size}x${min_size}! "$output_path"
    else
        # Crop the image to a square from the center
        convert "$img" -gravity center -crop ${min_size}x${min_size}+0+0 +repage "$output_path"
    fi
    
    processed_files+=("$output_path")
done

# Combine all images horizontally
echo "Combining images into: $OUTPUT_FILE"
convert "${processed_files[@]}" +append "$OUTPUT_FILE"

# Clean up
echo "Cleaning up temporary files"
rm -rf "$TEMP_DIR"

echo "Done! Combined ${#IMAGE_FILES[@]} images into $OUTPUT_FILE"
