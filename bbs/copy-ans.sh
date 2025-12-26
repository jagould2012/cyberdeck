#!/bin/bash
#
# copy-ans.sh
# Copies .ans files from art/ to text/, handling .append.ans files
# by concatenating them to matching base files with @PAUSE@ @CLS@ between
#

ART_DIR="${1:-./art}"
TEXT_DIR="${2:-./text}"

# Verify source directory exists
if [ ! -d "$ART_DIR" ]; then
    echo "Error: Source directory '$ART_DIR' not found"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$TEXT_DIR"

# Default scroll speed (can be overridden with environment variable)
# Values: 0=unlimited, 1=300, 2=600, 3=1200, 4=2400, 5=4800, 6=9600, 7=19200, 8=38400
SCROLL_SPEED="${SCROLL_SPEED:-8}"

# Maximum screen height (rows) - files will be truncated to fit
# Standard terminal is 24 rows, but we need room for:
# - Clear screen code doesn't add a row
# - But trailing newline in file might
# Setting to 22 to be safe
MAX_ROWS="${MAX_ROWS:-22}"

# ANSI escape sequence for speed control (DECSCS - VT420)
# Format: ESC [ Ps1 ; Ps2 * r  where Ps2 is the speed value
# 0=unlimited, 1=300, 2=600, 3=1200, 4=2400, 5=4800, 6=9600, 7=19200, 8=38400, 11=115200
# Using printf to ensure proper escape character
speed_seq() {
    printf '\033[;%s*r' "$1"
}

# Reset to unlimited speed (value 0) - put at TOP of regular files
# This ensures files after throttled art display at full speed
speed_reset() {
    printf '\033[;0*r'
}

# Count actual display rows in an ANSI file (counts newlines, accounting for ANSI sequences)
count_ansi_rows() {
    local file="$1"
    # Count lines, ignoring SAUCE metadata
    perl -pe 's/\x1a.*//' "$file" | grep -c $'\n' || echo 0
}

# Truncate ANSI content to max rows from the BOTTOM (keep top rows)
# This preserves the top of the art and removes excess from bottom
truncate_ansi() {
    local content="$1"
    local max_rows="$2"
    
    # Use head to keep only the first N lines
    echo "$content" | head -n "$max_rows"
}

# Check if file uses cursor positioning (ESC [ row ; col H)
# Files with cursor positioning shouldn't be truncated by line count
uses_cursor_positioning() {
    local file="$1"
    # Look for ANSI cursor position sequences like ESC[5;1H
    grep -q $'\033\[[0-9]*;[0-9]*H' "$file" 2>/dev/null
}

# Strip SAUCE metadata from a file (outputs to stdout)
# SAUCE records start with EOF char (0x1A / Ctrl-Z) followed by "SAUCE00"
# This removes everything from the 0x1A onward
# Also strips trailing blank lines
strip_sauce() {
    local file="$1"
    # Use perl for portable binary handling across macOS and Linux
    # 1. Removes everything from Ctrl-Z (0x1A) to end of file
    # 2. Removes trailing blank lines (lines with only whitespace/CR/LF)
    perl -pe 's/\x1a.*//' "$file" | perl -0777 -pe 's/[\r\n\s]+$/\n/'
}

# Strip SAUCE and optionally truncate (skip truncation for cursor-positioned files)
strip_and_truncate() {
    local file="$1"
    local max_rows="$2"
    
    if uses_cursor_positioning "$file"; then
        # Don't truncate cursor-positioned files - just strip SAUCE
        strip_sauce "$file"
    else
        # Normal files - strip SAUCE and truncate
        strip_sauce "$file" | head -n "$max_rows"
    fi
}

# Extract SAUCE metadata from a file (outputs to stdout)
# Returns empty if no SAUCE found
get_sauce() {
    local file="$1"
    # Use perl for portable binary handling
    # Extract from 0x1A SAUCE00 to end of file
    perl -ne 'print if s/.*(\x1aSAUCE00.*)/$1/s' "$file" 2>/dev/null
}

# Check if original .msg or .asc file has SAUCE metadata
# If so, return it; otherwise return empty
get_sauce_from_original() {
    local text_dir="$1"
    local basename="$2"
    local original=""
    
    # Check for .msg first, then .asc
    if [ -f "$text_dir/${basename}.msg" ]; then
        original="$text_dir/${basename}.msg"
    elif [ -f "$text_dir/${basename}.asc" ]; then
        original="$text_dir/${basename}.asc"
    else
        return
    fi
    
    get_sauce "$original"
}

# Check for existing .msg or .asc file and extract prefix codes
# Returns the prefix that should be added to the .ans file
# Looks for Ctrl-A codes at the start (like ^Al for clear screen)
get_prefix_from_original() {
    local text_dir="$1"
    local basename="$2"
    local original=""
    
    # Check for .msg first, then .asc
    if [ -f "$text_dir/${basename}.msg" ]; then
        original="$text_dir/${basename}.msg"
    elif [ -f "$text_dir/${basename}.asc" ]; then
        original="$text_dir/${basename}.asc"
    else
        # No original found, use defaults - just clear screen
        speed_reset
        printf '\001l'
        return
    fi
    
    # Check if file starts with Ctrl-A l (clear screen)
    if head -c 2 "$original" | grep -q $'\x01l'; then
        # Original has clear screen
        speed_reset
        printf '\001l'
    else
        # Use Ctrl-A l for clear screen
        speed_reset
        printf '\001l'
    fi
}

# First pass: Process all regular .ans files (not .append.ans)
for file in "$ART_DIR"/*.ans; do
    [ -e "$file" ] || continue  # Skip if no matches
    
    filename=$(basename "$file")
    
    # Skip .append.ans files - they'll be handled separately
    if [[ "$filename" == *.append.ans ]]; then
        continue
    fi
    
    # Get the base name without .ans extension
    basename="${filename%.ans}"
    
    # Check if there's a matching .append.ans file
    append_file="$ART_DIR/${basename}.append.ans"
    
    if [ -f "$append_file" ]; then
        # Concatenate: first file, pause, clear, second file
        echo "Merging: $filename + ${basename}.append.ans -> $TEXT_DIR/$filename"
        {
            get_prefix_from_original "$TEXT_DIR" "$basename"
            strip_and_truncate "$file" "$MAX_ROWS"
            printf '\001p'  # Ctrl-A p = pause
            printf '\001l'  # Ctrl-A l = clear screen
            strip_and_truncate "$append_file" "$MAX_ROWS"
            get_sauce_from_original "$TEXT_DIR" "$basename"
        } > "$TEXT_DIR/$filename"
    else
        # Copy single file, truncated to fit screen (unless cursor-positioned)
        echo "Copying: $filename -> $TEXT_DIR/$filename"
        if uses_cursor_positioning "$file"; then
            echo "  (cursor-positioned art, not truncating)"
        else
            row_count=$(strip_sauce "$file" | wc -l | tr -d ' ')
            if [ -n "$row_count" ] && [ "$row_count" -gt "$MAX_ROWS" ]; then
                echo "  (truncated from $row_count to $MAX_ROWS rows)"
            fi
        fi
        {
            get_prefix_from_original "$TEXT_DIR" "$basename"
            strip_and_truncate "$file" "$MAX_ROWS"
            get_sauce_from_original "$TEXT_DIR" "$basename"
        } > "$TEXT_DIR/$filename"
    fi
done

# Second pass: Process art/menu directory for menu files
MENU_SRC="$ART_DIR/menu"
MENU_DIR="$TEXT_DIR/menu"

if [ -d "$MENU_SRC" ]; then
    echo ""
    echo "Processing menu art from $MENU_SRC..."
    
    # Create menu directory if needed
    mkdir -p "$MENU_DIR"
    
    # Process all regular .ans files in the menu directory (not .append.ans)
    for file in "$MENU_SRC"/*.ans; do
        [ -e "$file" ] || continue  # Skip if no matches
        
        filename=$(basename "$file")
        
        # Skip .append.ans files - they'll be handled separately
        if [[ "$filename" == *.append.ans ]]; then
            continue
        fi
        
        # Get the base name without .ans extension
        basename="${filename%.ans}"
        
        # Check if there's a matching .append.ans file
        append_file="$MENU_SRC/${basename}.append.ans"
        
        if [ -f "$append_file" ]; then
            echo "Merging: menu/$filename + ${basename}.append.ans -> $MENU_DIR/$filename"
            {
                get_prefix_from_original "$MENU_DIR" "$basename"
                strip_and_truncate "$file" "$MAX_ROWS"
                printf '\001p'  # Ctrl-A p = pause
                printf '\001l'  # Ctrl-A l = clear screen
                strip_and_truncate "$append_file" "$MAX_ROWS"
                get_sauce_from_original "$MENU_DIR" "$basename"
            } > "$MENU_DIR/$filename"
        else
            echo "Copying: menu/$filename -> $MENU_DIR/$filename"
            if uses_cursor_positioning "$file"; then
                echo "  (cursor-positioned art, not truncating)"
            else
                row_count=$(strip_sauce "$file" | wc -l | tr -d ' ')
                if [ -n "$row_count" ] && [ "$row_count" -gt "$MAX_ROWS" ]; then
                    echo "  (truncated from $row_count to $MAX_ROWS rows)"
                fi
            fi
            {
                get_prefix_from_original "$MENU_DIR" "$basename"
                strip_and_truncate "$file" "$MAX_ROWS"
                get_sauce_from_original "$MENU_DIR" "$basename"
            } > "$MENU_DIR/$filename"
        fi
    done
fi

# Third pass: Process art/random directory for rotating login screens
RANDOM_SRC="$ART_DIR/random"
MENU_DIR="$TEXT_DIR/menu"

if [ -d "$RANDOM_SRC" ]; then
    echo ""
    echo "Processing random login art..."
    
    # Create menu directory if needed
    mkdir -p "$MENU_DIR"
    
    # Remove existing random_sync_* and random_synch_* files (.msg and .ans)
    echo "Removing existing random_sync* files from $MENU_DIR"
    rm -f "$MENU_DIR"/random_sync*.c80.msg
    rm -f "$MENU_DIR"/random_sync*.c80.ans
    rm -f "$MENU_DIR"/random_sync*.msg
    rm -f "$MENU_DIR"/random_sync*.ans
    rm -f "$MENU_DIR"/random_synch*.c80.msg
    rm -f "$MENU_DIR"/random_synch*.c80.ans
    rm -f "$MENU_DIR"/random_synch*.msg
    rm -f "$MENU_DIR"/random_synch*.ans
    
    # Counter for naming files
    counter=1
    
    # Process all .ans files in the random directory
    for file in "$RANDOM_SRC"/*.ans; do
        [ -e "$file" ] || continue  # Skip if no matches
        
        filename=$(basename "$file")
        # Create new filename: random_sync_N.c80.ans
        new_filename="random_sync_${counter}.c80.ans"
        
        echo "Random art: $filename -> $MENU_DIR/$new_filename (with slow scroll)"
        {
            printf '%s\n' "@POFF@"
            speed_seq "$SCROLL_SPEED"
            cat "$file"
            printf '\n'
            printf '%s\n' "@PON@"
        } > "$MENU_DIR/$new_filename"
        
        ((counter++))
    done
    
    if [ $counter -gt 1 ]; then
        echo "Installed $((counter-1)) random login screens"
    else
        echo "No .ans files found in $RANDOM_SRC"
    fi
fi

echo ""
echo "Done! Files copied to $TEXT_DIR"