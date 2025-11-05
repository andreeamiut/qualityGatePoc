#!/bin/bash

# Regression Test Suite - System Integration Testing (SIT)
# Tests B2B transaction API endpoints and validates responses

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
APP_URL="${APP_URL:-http://app:5000}"

echo "=== B2B REGRESSION TEST SUITE ==="
echo "Target URL: $APP_URL"
echo "Results Directory: $RESULTS_DIR"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Initialize test results
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
TEST_RESULTS=()

# Test result tracking
log_test_result() {
    local test_name="$1"
    local status="$2"
    local details="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [ "$status" = "PASSED" ]; then
        PASSED_COUNT=$((PASSED_COUNT + 1))
        echo "✅ $test_name - PASSED"
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo "❌ $test_name - FAILED: $details"
    fi
    
    TEST_RESULTS+=("$test_name|$status|$details")
}

# Test 1: Health Check
echo ""
echo "Test 1: Application Health Check"
if response=$(curl -s -w "%{http_code}" -o /tmp/health_response.json "$APP_URL/health"); then
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        log_test_result "Health Check" "PASSED" "HTTP 200 OK"
    else
        log_test_result "Health Check" "FAILED" "HTTP $http_code"
    fi
else
    log_test_result "Health Check" "FAILED" "Connection failed"
fi

# Test 2: Transaction Processing - Valid Request
echo ""
echo "Test 2: Transaction Processing - Valid Request"
transaction_payload='{
    "customer_id": "CUST_00012345",
    "amount": 1250.75,
    "transaction_type": "PAYMENT"
}'

if response=$(curl -s -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$transaction_payload" \
    -o /tmp/transaction_response.json \
    "$APP_URL/api/v1/transaction"); then
    
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        # Validate response structure
        if jq -e '.txn_id' /tmp/transaction_response.json > /dev/null && \
           jq -e '.status' /tmp/transaction_response.json | grep -q "SUCCESS"; then
            txn_id=$(jq -r '.txn_id' /tmp/transaction_response.json)
            log_test_result "Valid Transaction" "PASSED" "TXN_ID: $txn_id"
        else
            log_test_result "Valid Transaction" "FAILED" "Invalid response structure"
        fi
    else
        log_test_result "Valid Transaction" "FAILED" "HTTP $http_code"
    fi
else
    log_test_result "Valid Transaction" "FAILED" "Request failed"
fi

# Test 3: Transaction Processing - Invalid Request (Missing Fields)
echo ""
echo "Test 3: Transaction Processing - Invalid Request"
invalid_payload='{
    "customer_id": "CUST_00012345"
}'

if response=$(curl -s -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$invalid_payload" \
    -o /tmp/invalid_response.json \
    "$APP_URL/api/v1/transaction"); then
    
    http_code="${response: -3}"
    if [ "$http_code" = "400" ]; then
        log_test_result "Invalid Request Handling" "PASSED" "HTTP 400 Bad Request"
    else
        log_test_result "Invalid Request Handling" "FAILED" "Expected HTTP 400, got $http_code"
    fi
else
    log_test_result "Invalid Request Handling" "FAILED" "Request failed"
fi

# Test 4: Statistics Endpoint
echo ""
echo "Test 4: Statistics Endpoint"
if response=$(curl -s -w "%{http_code}" -o /tmp/stats_response.json "$APP_URL/api/v1/stats"); then
    http_code="${response: -3}"
    if [ "$http_code" = "200" ]; then
        # Validate stats structure
        if jq -e '.total_transactions' /tmp/stats_response.json > /dev/null; then
            log_test_result "Statistics Endpoint" "PASSED" "Valid stats returned"
        else
            log_test_result "Statistics Endpoint" "FAILED" "Invalid stats structure"
        fi
    else
        log_test_result "Statistics Endpoint" "FAILED" "HTTP $http_code"
    fi
else
    log_test_result "Statistics Endpoint" "FAILED" "Request failed"
fi

# Test 5: Load Test - Multiple Concurrent Requests
echo ""
echo "Test 5: Concurrent Request Handling (10 requests)"
concurrent_success=0
concurrent_total=10

for i in $(seq 1 $concurrent_total); do
    customer_id="CUST_$(printf "%08d" $((12345 + i)))"
    amount=$((100 + RANDOM % 1000))
    
    payload='{
        "customer_id": "'$customer_id'",
        "amount": '$amount',
        "transaction_type": "PAYMENT"
    }'
    
    if response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -o "/tmp/concurrent_$i.json" \
        "$APP_URL/api/v1/transaction"); then
        
        http_code="${response: -3}"
        if [ "$http_code" = "200" ]; then
            concurrent_success=$((concurrent_success + 1))
        fi
    fi &
done

# Wait for all background requests to complete
wait

if [ $concurrent_success -eq $concurrent_total ]; then
    log_test_result "Concurrent Requests" "PASSED" "$concurrent_success/$concurrent_total successful"
elif [ $concurrent_success -gt $((concurrent_total * 8 / 10)) ]; then
    log_test_result "Concurrent Requests" "PASSED" "$concurrent_success/$concurrent_total successful (>80%)"
else
    log_test_result "Concurrent Requests" "FAILED" "Only $concurrent_success/$concurrent_total successful"
fi

# Generate XML test results for Jenkins
echo ""
echo "Generating test results..."

cat > "$RESULTS_DIR/regression_results.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="B2B Regression Tests" tests="$TEST_COUNT" failures="$FAILED_COUNT" time="$(date +%s)">
EOF

for result in "${TEST_RESULTS[@]}"; do
    IFS='|' read -r test_name status details <<< "$result"
    
    if [ "$status" = "PASSED" ]; then
        cat >> "$RESULTS_DIR/regression_results.xml" << EOF
    <testcase classname="RegressionTest" name="$test_name" time="1.0"/>
EOF
    else
        cat >> "$RESULTS_DIR/regression_results.xml" << EOF
    <testcase classname="RegressionTest" name="$test_name" time="1.0">
        <failure message="Test Failed" type="AssertionError">$details</failure>
    </testcase>
EOF
    fi
done

cat >> "$RESULTS_DIR/regression_results.xml" << EOF
</testsuite>
EOF

# Generate summary report
cat > "$RESULTS_DIR/regression_summary.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "total_tests": $TEST_COUNT,
    "passed_tests": $PASSED_COUNT,
    "failed_tests": $FAILED_COUNT,
    "success_rate": $(echo "scale=2; $PASSED_COUNT * 100 / $TEST_COUNT" | bc),
    "status": "$([ $FAILED_COUNT -eq 0 ] && echo "PASSED" || echo "FAILED")",
    "details": {
        "app_url": "$APP_URL",
        "test_results": [
EOF

first=true
for result in "${TEST_RESULTS[@]}"; do
    IFS='|' read -r test_name status details <<< "$result"
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$RESULTS_DIR/regression_summary.json"
    fi
    
    cat >> "$RESULTS_DIR/regression_summary.json" << EOF
            {
                "test_name": "$test_name",
                "status": "$status",
                "details": "$details"
            }
EOF
done

cat >> "$RESULTS_DIR/regression_summary.json" << EOF
        ]
    }
}
EOF

# Print final summary
echo ""
echo "=== REGRESSION TEST SUMMARY ==="
echo "Total Tests: $TEST_COUNT"
echo "Passed: $PASSED_COUNT"
echo "Failed: $FAILED_COUNT"
echo "Success Rate: $(echo "scale=1; $PASSED_COUNT * 100 / $TEST_COUNT" | bc)%"

if [ $FAILED_COUNT -eq 0 ]; then
    echo "✅ All regression tests PASSED"
    exit 0
else
    echo "❌ $FAILED_COUNT regression test(s) FAILED"
    exit 1
fi