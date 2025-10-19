# Build Script Diagram Counter Issue Analysis

## Problem Description

The build-presentation.sh script was mismatching diagrams in the generated HTML. Specifically, the "Обработка сигналов" (Signals Processing) section was showing `diagram_7_vertical.svg` instead of the correct `diagram_1_sequence.svg`.

## Root Cause Analysis

1. **Multiple Script Runs**: The script was run multiple times with the presentation file in different states, creating duplicate diagram files with different suffixes (e.g., `diagram_1_sequence.svg` and `diagram_1_vertical.svg`).

2. **Sequential Processing Issue**: The original script processes mermaid blocks one by one, extracting and replacing them in sequence. This works correctly when run once, but fails when:
   - The script is interrupted and rerun
   - New mermaid blocks are added to the source file
   - The source file is edited between runs

3. **No Cleanup**: The script doesn't clean up old diagram files before generating new ones, leading to accumulation of incorrectly numbered diagrams.

## Evidence Found

- In the resources directory, there were multiple versions of the same diagram number:
  - `LinuxPython_diagram_1_sequence.svg` (created at 00:04)
  - `LinuxPython_diagram_1_vertical.svg` (created at 23:54)
  
- The HTML file showed diagram references out of order:
  - Line 1704: "Обработка сигналов" → `diagram_7_vertical.svg` (wrong)
  - Line 2139: "Архитектура ProcessManager" → `diagram_1_sequence.svg` (should be elsewhere)

## Solution Implemented

The fixed script (`build-presentation-fixed.sh`) includes these improvements:

1. **Clean Old Diagrams**: Before processing, removes all existing diagram files for the current presentation:
   ```bash
   rm -f "${RESOURCES_DIR}/${INPUT_NAME}_diagram_"*.svg
   rm -f "${RESOURCES_DIR}/${INPUT_NAME}_diagram_"*.png
   ```

2. **Two-Pass Processing**: 
   - First pass: Extract ALL mermaid blocks and save them to temporary files
   - Second pass: Generate images for all diagrams
   - Third pass: Replace mermaid blocks with image references in order

3. **Improved Diagram Type Detection**: The type detection remains the same but is applied consistently to both the extraction and replacement phases.

## How to Use the Fix

1. Replace the original script with the fixed version:
   ```bash
   cp build-presentation-fixed.sh build-presentation.sh
   ```

2. Run the script to regenerate the presentation:
   ```bash
   ./build-presentation.sh "/Users/dmitrii/Obsidian/MySecureNotes/Teaching/Presentations/Python QA/2025-02/28-LinuxPython/LinuxPython.md"
   ```

This will clean up all old diagrams and generate new ones with correct numbering and references.