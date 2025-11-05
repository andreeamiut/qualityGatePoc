#!/bin/bash

# Performance Test Execution Script
# This script runs JMeter tests and validates P90 performance criteria

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="/opt/performance/results"
JMETER_HOME="/opt/apache-jmeter-5.4.1"
JMX_FILE="$SCRIPT_DIR/txn_load_test.jmx"

# Configuration
BASE_URL="${BASE_URL:-http://app:5000}"
THREADS="${THREADS:-50}"
DURATION="${DURATION:-60}"
P90_THRESHOLD="${P90_THRESHOLD:-250}"

echo "=== B2B Transaction Performance Test ==="
echo "Base URL: $BASE_URL"
echo "Threads: $THREADS"
echo "Duration: ${DURATION}s"
echo "P90 Threshold: ${P90_THRESHOLD}ms"
echo "========================================="

# Create results directory
mkdir -p "$RESULTS_DIR"

# Clean previous results
rm -f "$RESULTS_DIR"/*.jtl
rm -f "$RESULTS_DIR"/*.log

# Run JMeter test
echo "Starting JMeter performance test..."
$JMETER_HOME/bin/jmeter -n -t "$JMX_FILE" \
    -JBASE_URL="$BASE_URL" \
    -JTHREADS="$THREADS" \
    -JDURATION="$DURATION" \
    -JP90_THRESHOLD="$P90_THRESHOLD" \
    -l "$RESULTS_DIR/results.jtl" \
    -j "$RESULTS_DIR/jmeter.log" \
    -e -o "$RESULTS_DIR/html_report"

echo "Performance test completed!"

# Analyze results
echo "Analyzing performance results..."
python3 "$SCRIPT_DIR/analyze_results.py" \
    --results-file "$RESULTS_DIR/results.jtl" \
    --threshold "$P90_THRESHOLD" \
    --output "$RESULTS_DIR/performance_summary.json"

# Check if test passed
if [ -f "$RESULTS_DIR/performance_summary.json" ]; then
    PASSED=$(python3 -c "import json; print(json.load(open('$RESULTS_DIR/performance_summary.json'))['passed'])")
    if [ "$PASSED" = "True" ]; then
        echo "✅ Performance test PASSED - P90 response time within threshold"
        exit 0
    else
        echo "❌ Performance test FAILED - P90 response time exceeds threshold"
        
        # Trigger diagnostic analysis
        echo "Running diagnostic analysis..."
        "$SCRIPT_DIR/diagnose_performance.sh"
        exit 1
    fi
else
    echo "❌ Failed to generate performance summary"
    exit 1
fi