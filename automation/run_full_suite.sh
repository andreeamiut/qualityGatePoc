#!/bin/bash

# Full Automation Suite Runner
# Orchestrates all automation agents and generates comprehensive reports

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

echo "=== FULL QA AUTOMATION SUITE ==="
echo "Starting comprehensive validation pipeline..."

# Create results directory
mkdir -p "$RESULTS_DIR"

# Initialize suite results
TOTAL_STAGES=4
COMPLETED_STAGES=0
FAILED_STAGES=0
STAGE_RESULTS=()

# Stage result tracking
log_stage_result() {
    local stage_name="$1"
    local status="$2"
    local details="$3"
    
    COMPLETED_STAGES=$((COMPLETED_STAGES + 1))
    
    if [ "$status" = "PASSED" ]; then
        echo "✅ $stage_name - PASSED"
    else
        FAILED_STAGES=$((FAILED_STAGES + 1))
        echo "❌ $stage_name - FAILED: $details"
    fi
    
    STAGE_RESULTS+=("$stage_name|$status|$details")
}

# Wait for application to be ready
echo "Waiting for application to be ready..."
MAX_WAIT=60
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    if curl -f http://app:5000/health > /dev/null 2>&1; then
        echo "✅ Application is ready"
        break
    fi
    echo "⏳ Waiting for application... ($WAIT_COUNT/$MAX_WAIT)"
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
    echo "❌ Application not ready after ${MAX_WAIT} attempts"
    log_stage_result "Application Readiness" "FAILED" "Application not responding"
else
    log_stage_result "Application Readiness" "PASSED" "Application is healthy"
fi

# Stage 1: Regression Testing
echo ""
echo "=== STAGE 1: REGRESSION TESTING ==="
if "$SCRIPT_DIR/run_regression_tests.sh"; then
    log_stage_result "Regression Tests" "PASSED" "All regression tests passed"
else
    log_stage_result "Regression Tests" "FAILED" "One or more regression tests failed"
fi

# Stage 2: SQL Validation
echo ""
echo "=== STAGE 2: SQL DATA VALIDATION ==="
if "$SCRIPT_DIR/run_sql_validation.sh"; then
    log_stage_result "SQL Validation" "PASSED" "All SQL validations passed"
else
    log_stage_result "SQL Validation" "FAILED" "One or more SQL validations failed"
fi

# Stage 3: Log Analysis
echo ""
echo "=== STAGE 3: LOG ANALYSIS ==="
if "$SCRIPT_DIR/run_log_analysis.sh"; then
    log_stage_result "Log Analysis" "PASSED" "Log analysis completed successfully"
else
    log_stage_result "Log Analysis" "FAILED" "Log analysis found critical issues"
fi

# Stage 4: Performance Testing (Optional)
echo ""
echo "=== STAGE 4: PERFORMANCE TESTING ==="
if [ "${SKIP_PERFORMANCE_TESTS:-false}" = "true" ]; then
    log_stage_result "Performance Tests" "SKIPPED" "Performance tests disabled"
else
    if [ -f "/opt/performance/run_performance_test.sh" ]; then
        if /opt/performance/run_performance_test.sh; then
            log_stage_result "Performance Tests" "PASSED" "Performance criteria met"
        else
            log_stage_result "Performance Tests" "FAILED" "Performance criteria not met"
        fi
    else
        log_stage_result "Performance Tests" "WARNING" "Performance test script not found"
    fi
fi

# Generate final comprehensive report
echo ""
echo "Generating final report..."
"$SCRIPT_DIR/generate_final_report.sh"

# Print final summary
echo ""
echo "=== FULL SUITE SUMMARY ==="
echo "Total Stages: $TOTAL_STAGES"
echo "Completed Stages: $COMPLETED_STAGES"
echo "Failed Stages: $FAILED_STAGES"

if [ $FAILED_STAGES -eq 0 ]; then
    echo "✅ ALL AUTOMATION STAGES PASSED"
    exit 0
else
    echo "❌ $FAILED_STAGES AUTOMATION STAGE(S) FAILED"
    exit 1
fi