#!/bin/bash
# cyberdeck-auth.sh
# PAM authentication script for Cyberdeck Login
# This script is called by pam_exec to verify BLE authentication

set -e

TRIGGER_FILE="/tmp/cyberdeck-login-trigger"
MAX_AGE_SECONDS=10

# Check if trigger file exists
if [ ! -f "$TRIGGER_FILE" ]; then
    exit 1
fi

# Verify file is recent
FILE_TIME=$(stat -c %Y "$TRIGGER_FILE" 2>/dev/null || echo 0)
CURRENT_TIME=$(date +%s)
FILE_AGE=$((CURRENT_TIME - FILE_TIME))

if [ $FILE_AGE -gt $MAX_AGE_SECONDS ]; then
    rm -f "$TRIGGER_FILE" 2>/dev/null
    exit 1
fi

# Read and verify trigger data
TRIGGER_DATA=$(cat "$TRIGGER_FILE" 2>/dev/null)
TRIGGER_USER=$(echo "$TRIGGER_DATA" | jq -r '.user' 2>/dev/null)
TRIGGER_ACTION=$(echo "$TRIGGER_DATA" | jq -r '.action' 2>/dev/null)

# Verify user matches
if [ -z "$PAM_USER" ] || [ "$PAM_USER" != "$TRIGGER_USER" ]; then
    rm -f "$TRIGGER_FILE" 2>/dev/null
    exit 1
fi

# Verify action is unlock
if [ "$TRIGGER_ACTION" != "unlock" ]; then
    rm -f "$TRIGGER_FILE" 2>/dev/null
    exit 1
fi

# Success - remove trigger file and allow login
rm -f "$TRIGGER_FILE" 2>/dev/null

# Log successful authentication
logger -t cyberdeck-login "BLE authentication successful for user: $PAM_USER"

exit 0