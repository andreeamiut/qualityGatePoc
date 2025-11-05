#!/bin/bash

# Final Report Generator with Agentic Self-Healing Analysis
# Consolidates all validation results and provides actionable recommendations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

echo "=== GENERATING FINAL VALIDATION REPORT ==="

# Create results directory if not exists
mkdir -p "$RESULTS_DIR"

# Initialize report data
TIMESTAMP=$(date -Iseconds)
OVERALL_STATUS="PASSED"
RECOMMENDATIONS=()

# Function to add recommendations
add_recommendation() {
    local category="$1"
    local priority="$2"
    local recommendation="$3"
    local action="$4"
    
    RECOMMENDATIONS+=("$category|$priority|$recommendation|$action")
}

# Load individual test results
REGRESSION_STATUS="UNKNOWN"
SQL_STATUS="UNKNOWN"
LOG_STATUS="UNKNOWN"
PERFORMANCE_STATUS="UNKNOWN"

# Parse regression test results
if [ -f "$RESULTS_DIR/regression_summary.json" ]; then
    REGRESSION_STATUS=$(jq -r '.status' "$RESULTS_DIR/regression_summary.json" 2>/dev/null || echo "UNKNOWN")
    if [ "$REGRESSION_STATUS" = "FAILED" ]; then
        OVERALL_STATUS="FAILED"
        add_recommendation "Application" "HIGH" "Regression tests failed - API endpoints not functioning correctly" "Review application logs and fix failing endpoints"
        
        # Analyze specific regression failures
        FAILED_TESTS=$(jq -r '.details.test_results[] | select(.status=="FAILED") | .test_name' "$RESULTS_DIR/regression_summary.json" 2>/dev/null || echo "")
        if echo "$FAILED_TESTS" | grep -q "Health Check"; then
            add_recommendation "Infrastructure" "CRITICAL" "Application health check failing" "Verify application deployment and container health"
        fi
        if echo "$FAILED_TESTS" | grep -q "Transaction"; then
            add_recommendation "Database" "HIGH" "Transaction processing failures detected" "Check database connectivity and query performance"
        fi
    fi
fi

# Parse SQL validation results
if [ -f "$RESULTS_DIR/sql_validation_summary.json" ]; then
    SQL_STATUS=$(jq -r '.validation_summary.status' "$RESULTS_DIR/sql_validation_summary.json" 2>/dev/null || echo "UNKNOWN")
    if [ "$SQL_STATUS" = "FAILED" ]; then
        OVERALL_STATUS="FAILED"
        add_recommendation "Database" "HIGH" "Data integrity issues detected" "Review SQL validation failures and fix data inconsistencies"
        
        # Analyze specific SQL failures
        FAILED_SQL=$(jq -r '.validation_results[] | select(.status=="FAILED") | .validation_name' "$RESULTS_DIR/sql_validation_summary.json" 2>/dev/null || echo "")
        if echo "$FAILED_SQL" | grep -q "Integrity"; then
            add_recommendation "Database" "CRITICAL" "Referential integrity violations found" "Fix foreign key constraints and data relationships"
        fi
        if echo "$FAILED_SQL" | grep -q "Balance"; then
            add_recommendation "Business Logic" "HIGH" "Business rule violations detected" "Review transaction processing logic and balance calculations"
        fi
    fi
fi

# Parse log analysis results
if [ -f "$RESULTS_DIR/log_analysis_summary.json" ]; then
    LOG_STATUS=$(jq -r '.analysis_summary.status' "$RESULTS_DIR/log_analysis_summary.json" 2>/dev/null || echo "UNKNOWN")
    ERROR_COUNT=$(jq -r '.error_analysis.total_errors' "$RESULTS_DIR/log_analysis_summary.json" 2>/dev/null || echo "0")
    
    if [ "$LOG_STATUS" = "FAILED" ]; then
        OVERALL_STATUS="FAILED"
        add_recommendation "Monitoring" "MEDIUM" "Log analysis detected critical issues" "Review application logs and fix error patterns"
    fi
    
    if [ "$ERROR_COUNT" -gt 10 ]; then
        add_recommendation "Application" "MEDIUM" "High error rate in logs ($ERROR_COUNT errors)" "Implement better error handling and monitoring"
    fi
fi

# Parse performance test results
if [ -f "/opt/performance/results/performance_summary.json" ]; then
    PERFORMANCE_STATUS=$(jq -r '.test_verdict' "/opt/performance/results/performance_summary.json" 2>/dev/null || echo "UNKNOWN")
    P90_TIME=$(jq -r '.response_times_ms.p90' "/opt/performance/results/performance_summary.json" 2>/dev/null || echo "0")
    SUCCESS_RATE=$(jq -r '.success_rate_percent' "/opt/performance/results/performance_summary.json" 2>/dev/null || echo "0")
    
    if [ "$PERFORMANCE_STATUS" = "FAILED" ]; then
        OVERALL_STATUS="FAILED"
        add_recommendation "Performance" "HIGH" "Performance criteria not met (P90: ${P90_TIME}ms)" "Optimize application and database performance"
        
        # Agentic Self-Healing Analysis
        if (( $(echo "$P90_TIME > 250" | bc -l) )); then
            add_recommendation "Infrastructure" "HIGH" "P90 response time exceeds 250ms threshold" "Increase CPU from 2 to 4 cores, consider database optimization"
        fi
        
        if (( $(echo "$SUCCESS_RATE < 95" | bc -l) )); then
            add_recommendation "Reliability" "HIGH" "Success rate below 95% (${SUCCESS_RATE}%)" "Investigate connection pooling and error handling"
        fi
        
        # Check for resource utilization issues
        if docker stats --no-stream qualitygatepoc-app-1 2>/dev/null | tail -1 | awk '{print $3}' | sed 's/%//' | awk '{if($1>80) exit 0; else exit 1}'; then
            add_recommendation "Infrastructure" "CRITICAL" "High CPU utilization detected (>80%)" "Increase CPU limit from 2 to 4 cores in docker-compose.yml"
        fi
        
        if docker stats --no-stream qualitygatepoc-app-1 2>/dev/null | tail -1 | awk '{print $7}' | sed 's/%//' | awk '{if($1>80) exit 0; else exit 1}'; then
            add_recommendation "Infrastructure" "CRITICAL" "High memory utilization detected (>80%)" "Increase memory limit from 4GB to 8GB in docker-compose.yml"
        fi
    fi
elif [ -f "$RESULTS_DIR/performance_summary.json" ]; then
    PERFORMANCE_STATUS=$(jq -r '.test_verdict' "$RESULTS_DIR/performance_summary.json" 2>/dev/null || echo "UNKNOWN")
fi

# Generate HTML report
cat > "$RESULTS_DIR/final_report.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>QA Validation Report - B2B Transaction System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #333; border-bottom: 3px solid #007acc; padding-bottom: 20px; margin-bottom: 30px; }
        .status-passed { color: #28a745; font-weight: bold; }
        .status-failed { color: #dc3545; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-unknown { color: #6c757d; font-weight: bold; }
        .section { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
        .section h3 { margin-top: 0; color: #007acc; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .summary-card { background: #f8f9fa; padding: 20px; border-radius: 5px; border-left: 4px solid #007acc; }
        .recommendation { background: #fff3cd; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #ffc107; }
        .recommendation.critical { background: #f8d7da; border-left-color: #dc3545; }
        .recommendation.high { background: #f1c0c7; border-left-color: #e74c3c; }
        .recommendation.medium { background: #fff3cd; border-left-color: #f39c12; }
        .recommendation.low { background: #d1ecf1; border-left-color: #17a2b8; }
        .timestamp { color: #666; font-size: 0.9em; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #007acc; color: white; }
        .metric { font-size: 1.2em; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 QA Validation Report</h1>
            <h2>B2B Transaction System</h2>
            <p class="timestamp">Generated: $TIMESTAMP</p>
            <p class="metric status-$(echo "$OVERALL_STATUS" | tr '[:upper:]' '[:lower:]')">Overall Status: $OVERALL_STATUS</p>
        </div>
        
        <div class="section">
            <h3>📊 Executive Summary</h3>
            <div class="summary-grid">
                <div class="summary-card">
                    <h4>🧪 Regression Testing</h4>
                    <p class="metric status-$(echo "$REGRESSION_STATUS" | tr '[:upper:]' '[:lower:]')">$REGRESSION_STATUS</p>
                    <p>API endpoint validation and functional testing</p>
                </div>
                <div class="summary-card">
                    <h4>🗄️ SQL Validation</h4>
                    <p class="metric status-$(echo "$SQL_STATUS" | tr '[:upper:]' '[:lower:]')">$SQL_STATUS</p>
                    <p>Data integrity and consistency checks</p>
                </div>
                <div class="summary-card">
                    <h4>📋 Log Analysis</h4>
                    <p class="metric status-$(echo "$LOG_STATUS" | tr '[:upper:]' '[:lower:]')">$LOG_STATUS</p>
                    <p>Transaction patterns and error analysis</p>
                </div>
                <div class="summary-card">
                    <h4>⚡ Performance Testing</h4>
                    <p class="metric status-$(echo "$PERFORMANCE_STATUS" | tr '[:upper:]' '[:lower:]')">$PERFORMANCE_STATUS</p>
                    <p>Load testing with 50 concurrent users</p>
                </div>
            </div>
        </div>
EOF

# Add performance metrics if available
if [ -f "/opt/performance/results/performance_summary.json" ]; then
    P90_TIME=$(jq -r '.response_times_ms.p90 // "N/A"' "/opt/performance/results/performance_summary.json")
    THROUGHPUT=$(jq -r '.throughput_rps // "N/A"' "/opt/performance/results/performance_summary.json")
    SUCCESS_RATE=$(jq -r '.success_rate_percent // "N/A"' "/opt/performance/results/performance_summary.json")
    
    cat >> "$RESULTS_DIR/final_report.html" << EOF
        <div class="section">
            <h3>⚡ Performance Metrics</h3>
            <table>
                <tr><th>Metric</th><th>Value</th><th>Threshold</th><th>Status</th></tr>
                <tr><td>90th Percentile Response Time</td><td>${P90_TIME}ms</td><td>250ms</td><td class="status-$([ $(echo "$P90_TIME <= 250" | bc -l 2>/dev/null) = 1 ] 2>/dev/null && echo "passed" || echo "failed")">$([ $(echo "$P90_TIME <= 250" | bc -l 2>/dev/null) = 1 ] 2>/dev/null && echo "PASSED" || echo "FAILED")</td></tr>
                <tr><td>Throughput</td><td>${THROUGHPUT} RPS</td><td>-</td><td>-</td></tr>
                <tr><td>Success Rate</td><td>${SUCCESS_RATE}%</td><td>95%</td><td class="status-$([ $(echo "$SUCCESS_RATE >= 95" | bc -l 2>/dev/null) = 1 ] 2>/dev/null && echo "passed" || echo "failed")">$([ $(echo "$SUCCESS_RATE >= 95" | bc -l 2>/dev/null) = 1 ] 2>/dev/null && echo "PASSED" || echo "FAILED")</td></tr>
            </table>
        </div>
EOF
fi

# Add recommendations section
cat >> "$RESULTS_DIR/final_report.html" << EOF
        <div class="section">
            <h3>🚨 Agentic Recommendations & Self-Healing Actions</h3>
EOF

if [ ${#RECOMMENDATIONS[@]} -eq 0 ]; then
    cat >> "$RESULTS_DIR/final_report.html" << EOF
            <p class="status-passed">✅ No critical issues detected. System is performing within acceptable parameters.</p>
EOF
else
    for rec in "${RECOMMENDATIONS[@]}"; do
        IFS='|' read -r category priority recommendation action <<< "$rec"
        
        cat >> "$RESULTS_DIR/final_report.html" << EOF
            <div class="recommendation $(echo "$priority" | tr '[:upper:]' '[:lower:]')">
                <h4>$category - $priority Priority</h4>
                <p><strong>Issue:</strong> $recommendation</p>
                <p><strong>Action:</strong> $action</p>
            </div>
EOF
    done
fi

cat >> "$RESULTS_DIR/final_report.html" << EOF
        </div>
        
        <div class="section">
            <h3>📈 Next Steps</h3>
            <ol>
                <li><strong>Address Critical Issues:</strong> Fix any CRITICAL priority recommendations immediately</li>
                <li><strong>Performance Optimization:</strong> If P90 > 250ms, implement resource scaling recommendations</li>
                <li><strong>Monitoring Enhancement:</strong> Set up continuous monitoring for key metrics</li>
                <li><strong>Automated Remediation:</strong> Implement auto-scaling based on performance thresholds</li>
            </ol>
        </div>
        
        <div class="section">
            <h3>📁 Supporting Files</h3>
            <ul>
                <li>Regression Test Results: <code>regression_summary.json</code></li>
                <li>SQL Validation Report: <code>sql_validation_summary.json</code></li>
                <li>Log Analysis Report: <code>log_analysis_summary.json</code></li>
                <li>Performance Test Report: <code>performance_summary.json</code></li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

# Generate JSON summary
cat > "$RESULTS_DIR/final_report.json" << EOF
{
    "timestamp": "$TIMESTAMP",
    "overall_status": "$OVERALL_STATUS",
    "regression_tests": {
        "status": "$REGRESSION_STATUS"
    },
    "sql_validation": {
        "status": "$SQL_STATUS"
    },
    "log_analysis": {
        "status": "$LOG_STATUS"
    },
    "performance_tests": {
        "status": "$PERFORMANCE_STATUS"
    },
    "recommendations": [
EOF

first=true
for rec in "${RECOMMENDATIONS[@]}"; do
    IFS='|' read -r category priority recommendation action <<< "$rec"
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$RESULTS_DIR/final_report.json"
    fi
    
    cat >> "$RESULTS_DIR/final_report.json" << EOF
        {
            "category": "$category",
            "priority": "$priority",
            "recommendation": "$recommendation",
            "action": "$action"
        }
EOF
done

cat >> "$RESULTS_DIR/final_report.json" << EOF
    ]
}
EOF

echo "✅ Final validation report generated:"
echo "   - HTML Report: $RESULTS_DIR/final_report.html"
echo "   - JSON Summary: $RESULTS_DIR/final_report.json"

# Print agentic analysis summary
if [ ${#RECOMMENDATIONS[@]} -gt 0 ]; then
    echo ""
    echo "🚨 AGENTIC SELF-HEALING ANALYSIS:"
    for rec in "${RECOMMENDATIONS[@]}"; do
        IFS='|' read -r category priority recommendation action <<< "$rec"
        echo "   $priority: $recommendation -> $action"
    done
fi

echo ""
echo "=== FINAL VALIDATION COMPLETE ==="