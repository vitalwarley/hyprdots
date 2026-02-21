#!/bin/bash
# SessionStart hook: check for pending active recall questions.
# Reads prediction-log.md and concept briefs to determine if recall is available.
# Outputs context that triggers the Learning Protocol in CLAUDE.md.

# Find project learning directory
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$PROJECT_ROOT" ]]; then
    exit 0
fi

LEARNING_DIR="$PROJECT_ROOT/docs/learning"
if [[ ! -d "$LEARNING_DIR" ]]; then
    exit 0
fi

PREDICTION_LOG="$LEARNING_DIR/prediction-log.md"
CONCEPTS_DIR="$LEARNING_DIR/concepts"

# Count unresolved prediction gaps
PENDING_GAPS=0
if [[ -f "$PREDICTION_LOG" ]]; then
    PENDING_GAPS=$(grep -c "WRONG" "$PREDICTION_LOG" 2>/dev/null || echo 0)
fi

# Count pending predictions (not yet graded)
PENDING_EXAMS=0
if [[ -f "$PREDICTION_LOG" ]]; then
    PENDING_EXAMS=$(grep -c "Status.*Pending" "$PREDICTION_LOG" 2>/dev/null || echo 0)
fi

# Count available concept briefs
CONCEPT_COUNT=0
if [[ -d "$CONCEPTS_DIR" ]]; then
    CONCEPT_COUNT=$(find "$CONCEPTS_DIR" -name "*.md" -not -name ".gitkeep" 2>/dev/null | wc -l)
fi

# Count recall candidates in concept briefs
RECALL_CANDIDATES=0
if [[ -d "$CONCEPTS_DIR" ]] && [[ "$CONCEPT_COUNT" -gt 0 ]]; then
    RECALL_CANDIDATES=$(grep -rl "recall-candidates" "$CONCEPTS_DIR" 2>/dev/null | wc -l)
fi

# Output context if there's learning material available
if [[ "$PENDING_GAPS" -gt 0 || "$CONCEPT_COUNT" -gt 0 || "$PENDING_EXAMS" -gt 0 ]]; then
    echo "Learning: ${PENDING_GAPS} unresolved prediction gaps, ${CONCEPT_COUNT} concept briefs, ${PENDING_EXAMS} pending exams, ${RECALL_CANDIDATES} briefs with recall candidates. Offer active recall to the user before proceeding."
fi
