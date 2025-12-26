#!/bin/bash
# update-msg-colors.sh
# Updates Synchronet color scheme to match bullseye style:
#
# Color scheme (from bullseye.ans):
# - Dark decorative elements: dark gray (K = black, with H = high intensity)
# - Labels/text: first letter high white (HW), rest normal white/gray (W)
# - All text lowercase
# - Preserves @-codes and block graphics (high ASCII)
#
# This script:
# 1. Resets .msg and .asc files from original docker image
# 2. Updates ctrl/attr.ini with bullseye-style colors
# 3. Converts .msg/.asc file text to lowercase (preserving @-codes and Ctrl-A codes)
# 4. Converts blue color scheme to gray/white
#
# Usage: ./update-msg-colors.sh [sbbs_root] [docker_image]
# Default: current directory, image auto-detected from docker-compose or "bbs-synchronet"
#
# The script expects:

# Get directory where this script is located (for finding update-msg-colors.pl)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   <sbbs_root>/ctrl/attr.ini
#   <sbbs_root>/text/*.msg, *.asc
#   <sbbs_root>/text/menu/*.msg, *.asc

set -e

SBBS_ROOT="${1:-.}"

# Auto-detect docker image name if not provided
if [ -z "$2" ]; then
    # Try to get image from docker-compose (format: directory-service)
    DIR_NAME=$(basename "$(cd "$SBBS_ROOT" && pwd)")
    DOCKER_IMAGE="${DIR_NAME}-synchronet"
else
    DOCKER_IMAGE="$2"
fi

CTRL_DIR="${SBBS_ROOT}/ctrl"
TEXT_DIR="${SBBS_ROOT}/text"

# Verify directories exist
if [ ! -d "$CTRL_DIR" ]; then
    echo "Error: ctrl directory not found at $CTRL_DIR"
    exit 1
fi

if [ ! -d "$TEXT_DIR" ]; then
    echo "Error: text directory not found at $TEXT_DIR"
    exit 1
fi

echo "=============================================="
echo "Synchronet Cyberdeck Theme Installer"
echo "=============================================="
echo ""
echo "SBBS Root:    $SBBS_ROOT"
echo "Docker Image: $DOCKER_IMAGE"
echo ""

# ============================================
# PART 0: Reset files from original docker image
# ============================================
echo "--- Part 0: Resetting files from docker image ---"

# Create temporary container (don't start it)
TEMP_CONTAINER="sbbs_temp_$$"
echo "Creating temporary container from $DOCKER_IMAGE..."

if ! docker create --name "$TEMP_CONTAINER" "$DOCKER_IMAGE" >/dev/null 2>&1; then
    echo "Error: Failed to create container from image '$DOCKER_IMAGE'"
    echo "Make sure the image exists: docker images | grep $DOCKER_IMAGE"
    exit 1
fi

# Copy original files from the container
echo "Copying original .msg and .asc files..."

# Copy text/*.msg and text/*.asc
docker cp "$TEMP_CONTAINER:/sbbs/text/." "$TEXT_DIR/" 2>/dev/null || true

# Copy ctrl/attr.ini
docker cp "$TEMP_CONTAINER:/sbbs/ctrl/attr.ini" "$CTRL_DIR/attr.ini" 2>/dev/null || true

# Copy ctrl/text.dat
docker cp "$TEMP_CONTAINER:/sbbs/ctrl/text.dat" "$CTRL_DIR/text.dat" 2>/dev/null || true

# Remove temporary container
docker rm "$TEMP_CONTAINER" >/dev/null 2>&1

echo "Reset complete."
echo ""

# ============================================
# PART 1: Update ctrl/attr.ini
# ============================================
echo "--- Part 1: Updating ctrl/attr.ini ---"

ATTR_INI="${CTRL_DIR}/attr.ini"

if [ -f "$ATTR_INI" ]; then
    # Create new attr.ini with Cyberdeck color scheme
    cat > "$ATTR_INI" << 'EOF'
; Synchronet Text Attribute Configuration
; Cyberdeck color scheme: dark gray accents, white/gray text
;
; Color codes: K=Black R=Red G=Green Y=Yellow B=Blue M=Magenta C=Cyan W=White
; Modifiers: H=High intensity, I=Blink, 0-7=Background color
;
; Cyberdeck style:
; - Dark elements: KH (high intensity black = dark gray)
; - Highlighted text: WH (high intensity white = bright white)  
; - Normal text: W (white = light gray)
; - Command keys: Y (yellow without H = brown/orange)

mnehigh           = WH                  ; Mnemonic Prompts High (first letter) - bright white
mnelow            = W                   ; Mnemonic Prompts Low (rest of text) - gray
mnecmd            = Y                   ; Mnemonic Commands (j, p, c, etc.) - brown/orange
inputline         = WH                  ; String Input Text
error             = KH                  ; Error/Warning Message (dark gray instead of red)
nodenum           = W                   ; Node Number in Node Status
nodeuser          = W                   ; User Name in Node Status
nodestatus        = W                   ; Node Status
nodedoing         = W                   ; Node Activity
filename          = WH                  ; File Name in Listings
filecdt           = W                   ; File Points in Listings
filedesc          = W                   ; File Descriptions in Listings
filelisthdrbox    = KH                  ; File Listings Header Box (dark gray)
filelistline      = KH                  ; File Listings Title Underline (dark gray)
chatlocal         = WH                  ; Chat Text Input Locally
chatremote        = W                   ; Chat Text Input Remotely
multichat         = W                   ; Multi-node Chat Text Input
external          = W                   ; External Programs (default attribute)
votes_full        = WH                  ; Votes Full
votes_empty       = KH                  ; Votes Empty (dark gray)
progress_complete = WH                  ; Progress Complete
progress_empty    = KH                  ; Progress Incomplete (dark gray)
; Status line colors
submenu           = W                   ; Sub-menu name
subnum            = W                   ; Sub-board/area number  
grpname           = W                   ; Message group name
; Additional system colors
title             = WH                  ; Titles
prompt            = W                   ; Standard prompts
; Monochrome grayscale rainbow:
rainbow           = WH,W,KH
EOF
    
    echo "Updated:   $ATTR_INI"
else
    echo "Warning: $ATTR_INI not found, creating new file"
    cat > "$ATTR_INI" << 'EOF'
; Synchronet Text Attribute Configuration
; Cyberdeck color scheme
mnehigh           = WH
mnelow            = W
mnecmd            = Y
inputline         = WH
error             = KH
nodenum           = W
nodeuser          = W
nodestatus        = W
nodedoing         = W
filename          = WH
filecdt           = W
filedesc          = W
filelisthdrbox    = KH
filelistline      = KH
chatlocal         = WH
chatremote        = W
multichat         = W
external          = W
votes_full        = WH
votes_empty       = KH
progress_complete = WH
progress_empty    = KH
submenu           = W
subnum            = W
grpname           = W
title             = WH
prompt            = W
rainbow           = WH,W,KH
EOF
    echo "Created:   $ATTR_INI"
fi

echo ""

# ============================================
# PART 1a: Update ctrl/modopts.ini for JS module colors
# ============================================
echo "--- Part 1a: Updating ctrl/modopts.ini ---"

MODOPTS_INI="${CTRL_DIR}/modopts.ini"

if [ -f "$MODOPTS_INI" ]; then
    # Remove empty/default entries that would override our settings
    sed -i.bak '/^[[:space:]]*first_caller_msg[[:space:]]*=$/d' "$MODOPTS_INI"
    sed -i.bak '/^[[:space:]]*last_few_callers_msg[[:space:]]*=$/d' "$MODOPTS_INI"
    sed -i.bak '/^[[:space:]]*last_few_callers_fmt[[:space:]]*=$/d' "$MODOPTS_INI"
    sed -i.bak '/^[[:space:]]*logonlist_fmt[[:space:]]*=$/d' "$MODOPTS_INI"
    sed -i.bak '/^[[:space:]]*logons_header_fmt[[:space:]]*=$/d' "$MODOPTS_INI"
    sed -i.bak '/^[[:space:]]*nobody_logged_on_fmt[[:space:]]*=$/d' "$MODOPTS_INI"
    rm -f "$MODOPTS_INI.bak"
    
    # Remove any existing color settings we're about to add (clean slate)
    sed -i.bak '/^first_caller_msg/d' "$MODOPTS_INI"
    sed -i.bak '/^last_few_callers_msg/d' "$MODOPTS_INI"
    sed -i.bak '/^logonlist_fmt/d' "$MODOPTS_INI"
    rm -f "$MODOPTS_INI.bak"
    
    # Add settings with ACTUAL Ctrl-A characters (not escaped text)
    # Perl \x01 creates real byte value 1 (Ctrl-A)
    # Color scheme: \x01n=normal, \x01w=white, \x01h=high, \x01k=black(gray with h)
    perl -i -pe 's/^\[logonlist\]$/[logonlist]\nfirst_caller_msg = \x01n\x01w\x01hYou are the first caller of the day!\nlast_few_callers_msg = \x01n\x01wLast few callers:\x01n\r\n/' "$MODOPTS_INI"
    
    echo "Updated logonlist colors in $MODOPTS_INI (using Ctrl-A characters)"
else
    echo "Warning: $MODOPTS_INI not found"
fi

echo ""

# ============================================
# PART 1b: Create ctrl/text.ini for shell prompt colors
# ============================================
echo "--- Part 1b: Creating ctrl/text.ini ---"

TEXT_INI="${CTRL_DIR}/text.ini"

# Generate text.ini with actual Ctrl-A characters using perl
# Style: lowercase text with bright white first letter
perl -e '
my $CA = "\x01";
print "; Synchronet Text String Overrides\n";
print "; Cyberdeck color scheme: grayscale\n";
print "; Style: lowercase with bright white first letter\n";
print ";\n\n";

print "[default.js]\n";
# Shell prompt begin: gray bullet, bright white
print "shell_prompt_begin = ${CA}-${CA}w\xfe ${CA}h${CA}w\n";
# Shell prompt middle: gray bullet, bright white
print "shell_prompt_middle = ${CA}n${CA}w\xfe ${CA}h${CA}w\n";
# Main menu prompt end - single backslash, lowercase
print "shell_main_prompt_end = ${CA}n${CA}w[${CA}h\@GN\@${CA}n${CA}w] \@GRP\@ [${CA}h\@SN\@${CA}n${CA}w] \@SUB\@: ${CA}n\n";
# File menu prompt end - single backslash, lowercase
print "shell_file_prompt_end = ${CA}n${CA}w(${CA}h\@LN\@${CA}n${CA}w) \@LIB\@ (${CA}h\@DN\@${CA}n${CA}w) \@DIR\@: ${CA}n\n";
# Menu labels - bright first letter, rest gray lowercase
print "Main = ${CA}h${CA}wM${CA}n${CA}wain\n";
print "File = ${CA}h${CA}wF${CA}n${CA}wile\n";
print "\n[js]\n";
print "; Global JS text overrides\n";
' > "$TEXT_INI"

echo "Created:   $TEXT_INI"

echo ""

# ============================================
# PART 1b: Update ctrl/text.dat colors
# ============================================
echo "--- Part 1b: Updating ctrl/text.dat colors ---"

TEXT_DAT="${CTRL_DIR}/text.dat"

if [ -f "$TEXT_DAT" ]; then
    # Process text.dat with the perl script
    perl "$SCRIPT_DIR/update-text-dat.pl" "$TEXT_DAT"
    echo "Updated:   $TEXT_DAT"
else
    echo "Warning: $TEXT_DAT not found, skipping"
fi

echo ""

# ============================================
# PART 2: Update .msg/.asc files
# ============================================
echo "--- Part 2: Updating .msg and .asc files ---"

process_msg_file() {
    local file="$1"
    local relpath="${file#$SBBS_ROOT/}"
    
    # Run the perl transformation script (SCRIPT_DIR defined at top of script)
    perl "$SCRIPT_DIR/update-msg-colors.pl" "$file"
    
    echo "  Processed: $relpath"
}

# Count files
count=0

# Process text/*.msg and text/*.asc
echo "Scanning: $TEXT_DIR/*.msg and *.asc"
shopt -s nullglob
for f in "$TEXT_DIR"/*.msg "$TEXT_DIR"/*.asc; do
    if [ -f "$f" ]; then
        process_msg_file "$f"
        count=$((count + 1))
    fi
done

# Process text/menu/*.msg and text/menu/*.asc (not subdirectories)
echo "Scanning: $TEXT_DIR/menu/*.msg and *.asc"
for f in "$TEXT_DIR/menu"/*.msg "$TEXT_DIR/menu"/*.asc; do
    if [ -f "$f" ]; then
        process_msg_file "$f"
        count=$((count + 1))
    fi
done
shopt -u nullglob

echo ""
echo "=============================================="
echo "Done!"
echo "=============================================="
echo ""
echo "Changes made:"
echo "  - Reset files from docker image: $DOCKER_IMAGE"
echo "  - Updated ctrl/attr.ini with bullseye colors"
echo "  - Processed $count .msg and .asc files (lowercase text, blue->gray)"
echo ""
echo "Color scheme applied:"
echo "  - Mnemonic highlight: WH (bright white)"
echo "  - Mnemonic normal:    W  (gray)"
echo "  - Dark accents:       KH (dark gray)"
echo "  - Blue (b) -> Black (k)"
echo "  - Cyan (c) -> White (w)"
echo ""
echo "Restart Synchronet BBS to apply changes."