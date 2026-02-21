#!/bin/bash
# One-time cleanup script for diary duplicate session IDs bug
# Removes duplicate session IDs from diary files and rebuilds INDEX.md

DIARY_DIR="$HOME/.claude/memory/diary"
BACKUP_DIR="$HOME/.claude/memory/diary-backup-$(date +%Y%m%d-%H%M%S)"

echo "Creating backup at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp -r "$DIARY_DIR"/*.md "$BACKUP_DIR/" 2>/dev/null

echo "Cleaning duplicate session IDs from diary files..."
for diary_file in "$DIARY_DIR"/202*.md; do
    [[ ! -f "$diary_file" ]] && continue
    [[ "$(basename "$diary_file")" == "INDEX.md" ]] && continue

    # Extract first session ID
    first_session_id=$(grep -m1 "<!-- Session ID:" "$diary_file" | sed 's/.*<!-- Session ID: \(.*\) -->.*/\1/')

    if [[ -n "$first_session_id" ]]; then
        # Remove all session ID lines
        grep -v "<!-- Session ID:" "$diary_file" > "${diary_file}.tmp"

        # Append the first session ID back (only once)
        echo "" >> "${diary_file}.tmp"
        echo "<!-- Session ID: $first_session_id -->" >> "${diary_file}.tmp"

        mv "${diary_file}.tmp" "$diary_file"
        echo "  Cleaned: $(basename "$diary_file")"
    fi
done

echo "Rebuilding INDEX.md from scratch..."
INDEX_FILE="$DIARY_DIR/INDEX.md"
INDEX_TMP="${INDEX_FILE}.new"

# Create header
cat > "$INDEX_TMP" <<'HEADER'
# Diary Index

| Date | File | Project | Created At | Updated At | Summary |
|------|------|---------|------------|------------|---------|
HEADER

# Process each diary file
for diary_file in $(ls -t "$DIARY_DIR"/202*.md 2>/dev/null); do
    [[ "$(basename "$diary_file")" == "INDEX.md" ]] && continue
    [[ ! -f "$diary_file" ]] && continue

    # Extract metadata
    TODAY=$(basename "$diary_file" | cut -d'-' -f1-3)
    SUMMARY=$(sed -n '/^## Task Summary$/,/^##/{/^## Task Summary$/d;/^##/d;p;}' "$diary_file" | head -1 | sed 's/^ *//')
    PROJECT=$(sed -n 's/^\*\*Project\*\*: *//p' "$diary_file" | head -1)
    SESSION_ID=$(grep -m1 "<!-- Session ID:" "$diary_file" | sed 's/.*<!-- Session ID: \(.*\) -->.*/\1/')

    # Extract timestamps
    CREATED_AT=$(stat -c '%w' "$diary_file" 2>/dev/null | cut -d' ' -f1,2 | head -c19)
    if [[ -z "$CREATED_AT" || "$CREATED_AT" == "-" ]]; then
        CREATED_AT=$(stat -c '%y' "$diary_file" 2>/dev/null | cut -d' ' -f1,2 | head -c19)
    fi
    UPDATED_AT=$(stat -c '%y' "$diary_file" 2>/dev/null | cut -d' ' -f1,2 | head -c19)

    ENTRY="| $TODAY | $(basename "$diary_file") | $PROJECT | $CREATED_AT | $UPDATED_AT | $SUMMARY |"
    echo "$ENTRY <!-- $SESSION_ID -->" >> "$INDEX_TMP"
done

mv "$INDEX_TMP" "$INDEX_FILE"
echo "INDEX.md rebuilt successfully"

echo ""
echo "Cleanup complete!"
echo "Backup saved to: $BACKUP_DIR"
echo ""
echo "Statistics:"
echo "  Total diary files: $(ls -1 "$DIARY_DIR"/202*.md 2>/dev/null | grep -v INDEX | wc -l)"
echo "  INDEX.md entries: $(grep -c "^|" "$INDEX_FILE" | tail -1)"
