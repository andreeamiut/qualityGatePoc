#!/bin/bash

# BASH Agent - Log Analysis & Parsing
# Analyzes application logs for transaction patterns and potential issues

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
LOG_PATH="${LOG_PATH:-/opt/app/logs/portal.log}"

echo "=== BASH AGENT - LOG ANALYSIS ==="
echo "Log Path: $LOG_PATH"
echo "Results Directory: $RESULTS_DIR"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Initialize analysis results
ANALYSIS_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
WARNING_COUNT=0
ANALYSIS_RESULTS=()

# Analysis result tracking
log_analysis_result() {
    local analysis_name="$1"
    local status="$2"
    local details="$3"
    local metric_value="$4"
    
    ANALYSIS_COUNT=$((ANALYSIS_COUNT + 1))
    timestamp=$(date -Iseconds)
    
    case "$status" in
        "PASSED")
            PASSED_COUNT=$((PASSED_COUNT + 1))
            echo "✅ $analysis_name - PASSED: $details"
            ;;
        "WARNING")
            WARNING_COUNT=$((WARNING_COUNT + 1))
            echo "⚠️ $analysis_name - WARNING: $details"
            ;;
        "FAILED")
            FAILED_COUNT=$((FAILED_COUNT + 1))
            echo "❌ $analysis_name - FAILED: $details"
            ;;
    esac
    
    ANALYSIS_RESULTS+=("$analysis_name|$status|$details|$metric_value")
}

# Check if log file exists
if [ ! -f "$LOG_PATH" ]; then
    echo "❌ Log file not found: $LOG_PATH"
    log_analysis_result "Log File Availability" "FAILED" "Log file not found" "0"
    exit 1
fi

echo "✅ Log file found: $LOG_PATH"
log_analysis_result "Log File Availability" "PASSED" "Log file exists" "1"

# Get log file info
log_size=$(stat -f%z "$LOG_PATH" 2>/dev/null || stat -c%s "$LOG_PATH" 2>/dev/null || echo "0")
log_lines=$(wc -l < "$LOG_PATH")

echo "Log file size: $log_size bytes"
echo "Log file lines: $log_lines"

if [ "$log_size" -gt 0 ]; then
    log_analysis_result "Log File Content" "PASSED" "Log contains data ($log_lines lines, $log_size bytes)" "$log_lines"
else
    log_analysis_result "Log File Content" "FAILED" "Log file is empty" "0"
fi

# Analysis 1: Transaction Pattern Analysis
echo ""
echo "=== TRANSACTION PATTERN ANALYSIS ==="

# Count transaction initiations
txn_initiated=$(grep -c "B2B_TRANSACTION_INITIATED" "$LOG_PATH" 2>/dev/null || echo "0")
echo "Transactions Initiated: $txn_initiated"

# Count transaction completions
txn_completed=$(grep -c "B2B_TRANSACTION_COMPLETED" "$LOG_PATH" 2>/dev/null || echo "0")
echo "Transactions Completed: $txn_completed"

# Count transaction failures
txn_failed=$(grep -c "B2B_TRANSACTION_FAILED" "$LOG_PATH" 2>/dev/null || echo "0")
echo "Transactions Failed: $txn_failed"

# Calculate completion rate
if [ "$txn_initiated" -gt 0 ]; then
    completion_rate=$(echo "scale=2; $txn_completed * 100 / $txn_initiated" | bc)
    failure_rate=$(echo "scale=2; $txn_failed * 100 / $txn_initiated" | bc)
    
    if (( $(echo "$completion_rate >= 90" | bc -l) )); then
        log_analysis_result "Transaction Completion Rate" "PASSED" "Completion rate: ${completion_rate}%" "$completion_rate"
    elif (( $(echo "$completion_rate >= 70" | bc -l) )); then
        log_analysis_result "Transaction Completion Rate" "WARNING" "Completion rate: ${completion_rate}%" "$completion_rate"
    else
        log_analysis_result "Transaction Completion Rate" "FAILED" "Low completion rate: ${completion_rate}%" "$completion_rate"
    fi
    
    if (( $(echo "$failure_rate <= 5" | bc -l) )); then
        log_analysis_result "Transaction Failure Rate" "PASSED" "Failure rate: ${failure_rate}%" "$failure_rate"
    elif (( $(echo "$failure_rate <= 15" | bc -l) )); then
        log_analysis_result "Transaction Failure Rate" "WARNING" "Elevated failure rate: ${failure_rate}%" "$failure_rate"
    else
        log_analysis_result "Transaction Failure Rate" "FAILED" "High failure rate: ${failure_rate}%" "$failure_rate"
    fi
else
    log_analysis_result "Transaction Pattern" "WARNING" "No transactions found in logs" "0"
fi

# Analysis 2: TXN_ID Extraction and Validation
echo ""
echo "=== TRANSACTION ID ANALYSIS ==="

# Extract unique transaction IDs
grep "TXN_ID:" "$LOG_PATH" 2>/dev/null | \
    sed 's/.*TXN_ID:\([^|]*\).*/\1/' | \
    sort | uniq > /tmp/txn_ids.txt

unique_txn_count=$(wc -l < /tmp/txn_ids.txt)
echo "Unique Transaction IDs: $unique_txn_count"

if [ "$unique_txn_count" -gt 0 ]; then
    log_analysis_result "Transaction ID Uniqueness" "PASSED" "Found $unique_txn_count unique TXN_IDs" "$unique_txn_count"
    
    # Check TXN_ID format (UUID pattern)
    invalid_txn_ids=$(grep -v -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' /tmp/txn_ids.txt | wc -l)
    
    if [ "$invalid_txn_ids" -eq 0 ]; then
        log_analysis_result "Transaction ID Format" "PASSED" "All TXN_IDs follow UUID format" "$unique_txn_count"
    else
        log_analysis_result "Transaction ID Format" "WARNING" "$invalid_txn_ids invalid TXN_ID formats found" "$invalid_txn_ids"
    fi
else
    log_analysis_result "Transaction ID Analysis" "FAILED" "No transaction IDs found in logs" "0"
fi

# Analysis 3: Performance Metrics from Logs
echo ""
echo "=== PERFORMANCE METRICS ANALYSIS ==="

# Extract processing times
grep "PROCESSING_TIME:" "$LOG_PATH" 2>/dev/null | \
    sed 's/.*PROCESSING_TIME:\([0-9.]*\)ms.*/\1/' > /tmp/processing_times.txt

if [ -s /tmp/processing_times.txt ]; then
    processing_count=$(wc -l < /tmp/processing_times.txt)
    avg_processing_time=$(awk '{sum+=$1} END {print sum/NR}' /tmp/processing_times.txt)
    max_processing_time=$(sort -n /tmp/processing_times.txt | tail -1)
    min_processing_time=$(sort -n /tmp/processing_times.txt | head -1)
    
    echo "Processing Time Samples: $processing_count"
    echo "Average Processing Time: ${avg_processing_time}ms"
    echo "Min Processing Time: ${min_processing_time}ms"
    echo "Max Processing Time: ${max_processing_time}ms"
    
    # Performance thresholds
    if (( $(echo "$avg_processing_time <= 200" | bc -l) )); then
        log_analysis_result "Average Processing Time" "PASSED" "Avg: ${avg_processing_time}ms" "$avg_processing_time"
    elif (( $(echo "$avg_processing_time <= 500" | bc -l) )); then
        log_analysis_result "Average Processing Time" "WARNING" "Elevated avg: ${avg_processing_time}ms" "$avg_processing_time"
    else
        log_analysis_result "Average Processing Time" "FAILED" "High avg: ${avg_processing_time}ms" "$avg_processing_time"
    fi
    
    if (( $(echo "$max_processing_time <= 1000" | bc -l) )); then
        log_analysis_result "Maximum Processing Time" "PASSED" "Max: ${max_processing_time}ms" "$max_processing_time"
    else
        log_analysis_result "Maximum Processing Time" "WARNING" "High max: ${max_processing_time}ms" "$max_processing_time"
    fi
else
    log_analysis_result "Processing Time Analysis" "WARNING" "No processing times found in logs" "0"
fi

# Analysis 4: Error Pattern Analysis
echo ""
echo "=== ERROR PATTERN ANALYSIS ==="

# Common error patterns
database_errors=$(grep -i "database\|connection\|oracle" "$LOG_PATH" 2>/dev/null | grep -i "error\|failed\|exception" | wc -l)
timeout_errors=$(grep -i "timeout\|timed.out" "$LOG_PATH" 2>/dev/null | wc -l)
auth_errors=$(grep -i "authentication\|authorization\|access.denied" "$LOG_PATH" 2>/dev/null | wc -l)
validation_errors=$(grep -i "validation\|invalid\|bad.request" "$LOG_PATH" 2>/dev/null | wc -l)

echo "Database Errors: $database_errors"
echo "Timeout Errors: $timeout_errors"
echo "Authentication Errors: $auth_errors"
echo "Validation Errors: $validation_errors"

total_errors=$((database_errors + timeout_errors + auth_errors + validation_errors))

if [ "$total_errors" -eq 0 ]; then
    log_analysis_result "Error Pattern Analysis" "PASSED" "No critical errors found" "0"
elif [ "$total_errors" -le 5 ]; then
    log_analysis_result "Error Pattern Analysis" "WARNING" "Few errors found: $total_errors" "$total_errors"
else
    log_analysis_result "Error Pattern Analysis" "FAILED" "Many errors found: $total_errors" "$total_errors"
fi

# Analysis 5: Log Format Consistency
echo ""
echo "=== LOG FORMAT VALIDATION ==="

# Check for required log format elements
logs_with_timestamp=$(grep -c "^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" "$LOG_PATH" 2>/dev/null || echo "0")
logs_with_level=$(grep -c "\(INFO\|ERROR\|WARNING\|DEBUG\)" "$LOG_PATH" 2>/dev/null || echo "0")

total_log_lines=$log_lines

if [ "$total_log_lines" -gt 0 ]; then
    timestamp_ratio=$(echo "scale=2; $logs_with_timestamp * 100 / $total_log_lines" | bc)
    level_ratio=$(echo "scale=2; $logs_with_level * 100 / $total_log_lines" | bc)
    
    if (( $(echo "$timestamp_ratio >= 80" | bc -l) )); then
        log_analysis_result "Log Timestamp Format" "PASSED" "Timestamp coverage: ${timestamp_ratio}%" "$timestamp_ratio"
    else
        log_analysis_result "Log Timestamp Format" "WARNING" "Low timestamp coverage: ${timestamp_ratio}%" "$timestamp_ratio"
    fi
    
    if (( $(echo "$level_ratio >= 80" | bc -l) )); then
        log_analysis_result "Log Level Format" "PASSED" "Log level coverage: ${level_ratio}%" "$level_ratio"
    else
        log_analysis_result "Log Level Format" "WARNING" "Low log level coverage: ${level_ratio}%" "$level_ratio"
    fi
else
    log_analysis_result "Log Format Validation" "WARNING" "No log lines to validate" "0"
fi

# Generate detailed log analysis report
echo ""
echo "Generating log analysis report..."

# Extract recent transactions for detailed analysis
echo "=== Recent Transactions (Last 10) ===" > "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
grep "B2B_TRANSACTION" "$LOG_PATH" | tail -10 >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"

echo "" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
echo "=== Error Summary ===" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
echo "Database Errors: $database_errors" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
echo "Timeout Errors: $timeout_errors" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
echo "Authentication Errors: $auth_errors" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
echo "Validation Errors: $validation_errors" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"

if [ "$total_errors" -gt 0 ]; then
    echo "" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
    echo "=== Recent Error Samples ===" >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
    grep -i "error\|exception\|failed" "$LOG_PATH" | tail -5 >> "$RESULTS_DIR/log_analysis_$(date +%Y%m%d_%H%M%S).txt"
fi

# Generate summary JSON
cat > "$RESULTS_DIR/log_analysis_summary.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "log_file": "$LOG_PATH",
    "log_statistics": {
        "file_size_bytes": $log_size,
        "total_lines": $log_lines,
        "transactions_initiated": $txn_initiated,
        "transactions_completed": $txn_completed,
        "transactions_failed": $txn_failed,
        "unique_transaction_ids": $unique_txn_count
    },
    "performance_metrics": {
        "avg_processing_time_ms": ${avg_processing_time:-0},
        "min_processing_time_ms": ${min_processing_time:-0},
        "max_processing_time_ms": ${max_processing_time:-0}
    },
    "error_analysis": {
        "database_errors": $database_errors,
        "timeout_errors": $timeout_errors,
        "authentication_errors": $auth_errors,
        "validation_errors": $validation_errors,
        "total_errors": $total_errors
    },
    "analysis_summary": {
        "total_analyses": $ANALYSIS_COUNT,
        "passed_analyses": $PASSED_COUNT,
        "warning_analyses": $WARNING_COUNT,
        "failed_analyses": $FAILED_COUNT,
        "status": "$([ $FAILED_COUNT -eq 0 ] && echo "PASSED" || echo "FAILED")"
    },
    "analysis_results": [
EOF

first=true
for result in "${ANALYSIS_RESULTS[@]}"; do
    IFS='|' read -r analysis_name status details metric_value <<< "$result"
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$RESULTS_DIR/log_analysis_summary.json"
    fi
    
    cat >> "$RESULTS_DIR/log_analysis_summary.json" << EOF
        {
            "analysis_name": "$analysis_name",
            "status": "$status",
            "details": "$details",
            "metric_value": "$metric_value"
        }
EOF
done

cat >> "$RESULTS_DIR/log_analysis_summary.json" << EOF
    ]
}
EOF

# Clean up temporary files
rm -f /tmp/txn_ids.txt /tmp/processing_times.txt

# Print final summary
echo ""
echo "=== LOG ANALYSIS SUMMARY ==="
echo "Total Analyses: $ANALYSIS_COUNT"
echo "Passed: $PASSED_COUNT"
echo "Warnings: $WARNING_COUNT"
echo "Failed: $FAILED_COUNT"

if [ $FAILED_COUNT -eq 0 ]; then
    echo "✅ Log analysis completed successfully"
    exit 0
else
    echo "❌ $FAILED_COUNT log analysis checks FAILED"
    exit 1
fi