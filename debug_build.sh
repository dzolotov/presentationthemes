#!/bin/bash

# Debug version of build-presentation.sh to trace the issue

INPUT_FILE="$1"
TEMP_FILE="temp_debug.md"

cp "$INPUT_FILE" "$TEMP_FILE"

echo "=== Starting mermaid block processing ==="

COUNTER=1

while grep -q '```mermaid' "$TEMP_FILE"; do
    echo ""
    echo "=== Processing block #${COUNTER} ==="
    
    # Show line number of first mermaid block
    LINE_NUM=$(grep -n '```mermaid' "$TEMP_FILE" | head -1 | cut -d: -f1)
    echo "First mermaid block found at line: $LINE_NUM"
    
    # Extract first mermaid block
    awk '/```mermaid/{flag=1; next} /```/{if(flag) exit} flag' "$TEMP_FILE" > "temp_diagram_${COUNTER}.mmd"
    
    # Show first few lines
    echo "Content preview:"
    head -3 "temp_diagram_${COUNTER}.mmd"
    
    # Determine type
    DIAGRAM_TYPE=""
    if grep -q "graph LR\|graph RL" "temp_diagram_${COUNTER}.mmd"; then
        DIAGRAM_TYPE="_horizontal"
    elif grep -q "graph TD\|graph TB" "temp_diagram_${COUNTER}.mmd"; then
        DIAGRAM_TYPE="_vertical"
    elif grep -q "sequenceDiagram" "temp_diagram_${COUNTER}.mmd"; then
        DIAGRAM_TYPE="_sequence"
    fi
    
    echo "Detected type: $DIAGRAM_TYPE"
    echo "Will create: diagram_${COUNTER}${DIAGRAM_TYPE}.svg"
    
    # Create a simple replacement (just for debugging)
    awk -v counter="$COUNTER" -v dtype="$DIAGRAM_TYPE" '
        /```mermaid/ && !replaced {
            print "<!-- REPLACED DIAGRAM " counter dtype " -->"
            flag=1
            replaced=1
            next
        }
        /```/ && flag {
            flag=0
            next
        }
        !flag { print }
    ' "$TEMP_FILE" > "temp_output.md"
    
    mv "temp_output.md" "$TEMP_FILE"
    
    ((COUNTER++))
done

echo ""
echo "=== Processed $((COUNTER-1)) diagrams ==="

# Show all replacement markers
echo ""
echo "=== Replacement markers in output: ==="
grep "REPLACED DIAGRAM" "$TEMP_FILE" | nl

# Cleanup
rm -f temp_diagram_*.mmd
rm -f "$TEMP_FILE"