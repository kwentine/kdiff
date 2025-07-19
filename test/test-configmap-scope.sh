#!/bin/bash
# Test: ConfigMap diff scoped to .data section only

set -euo pipefail

# Change to project root directory
cd "$(dirname "$0")/.."

# Test configuration
TEST_NAME="ConfigMap scope filtering (.data)"
ORIGINAL_FILE="test/fixtures/configmap.yaml"
MODIFIED_FILE="test/fixtures/configmap-modified.yaml"
EXPECTED_OUTPUT_FILE="test/expected/configmap-data-diff.txt"

echo "Running test: $TEST_NAME"

# Run kdiff with scope filtering to .data
echo "Executing: ./kdiff --scope=.data --diff-cmd='diff -u' --compare $ORIGINAL_FILE $MODIFIED_FILE"
ACTUAL_OUTPUT=$(./kdiff --scope=.data --diff-cmd='diff -u' --compare "$ORIGINAL_FILE" "$MODIFIED_FILE" 2>&1 || true)

# Display actual output for verification
echo "=== ACTUAL OUTPUT ==="
echo "$ACTUAL_OUTPUT"
echo "===================="

# Expected behavior:
# - Should only show differences in the .data section
# - Should exclude metadata differences (version: v2 label)
# - Should exclude annotations differences
# - Should show nginx.conf, app.properties, and redis.conf changes

# Check if output contains expected elements
echo "Checking test results..."

# Should contain .data changes
if echo "$ACTUAL_OUTPUT" | grep -q "Hello from v2"; then
    echo "✓ Contains nginx.conf changes (Hello from v2)"
else
    echo "✗ Missing nginx.conf changes"
    exit 1
fi

if echo "$ACTUAL_OUTPUT" | grep -q "debug=true"; then
    echo "✓ Contains app.properties changes (debug=true)"  
else
    echo "✗ Missing app.properties changes"
    exit 1
fi

if echo "$ACTUAL_OUTPUT" | grep -q "bind 127.0.0.1"; then
    echo "✓ Contains redis.conf changes (bind 127.0.0.1)"
else
    echo "✗ Missing redis.conf changes"
    exit 1
fi

# Should NOT contain metadata changes
if echo "$ACTUAL_OUTPUT" | grep -q "version: v2"; then
    echo "✗ Unexpectedly contains metadata changes (version: v2)"
    exit 1
else
    echo "✓ Correctly excludes metadata changes"
fi

if echo "$ACTUAL_OUTPUT" | grep -q "kubectl.kubernetes.io/last-applied-configuration"; then
    echo "✗ Unexpectedly contains annotation changes"
    exit 1
else
    echo "✓ Correctly excludes annotation changes"
fi

echo "🎉 Test passed: $TEST_NAME"