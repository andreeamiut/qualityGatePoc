#!/bin/bash

# SQL Agent - Data Integrity Validation
# Executes complex queries to validate data consistency across joined tables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

# Database configuration
DB_HOST="${DB_HOST:-oracle-db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-b2b_db}"
DB_USER="${DB_USER:-b2b_user}"
DB_PASSWORD="${DB_PASSWORD:-b2b_password}"
DB_CONNECTION="postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"

echo "=== SQL AGENT - DATA INTEGRITY VALIDATION ==="
echo "Database: $DB_HOST:$DB_PORT/$DB_NAME"
echo "User: $DB_USER"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Initialize validation results
VALIDATION_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
VALIDATION_RESULTS=()

# Validation result tracking
log_validation_result() {
    local validation_name="$1"
    local status="$2"
    local details="$3"
    local query="$4"
    
    VALIDATION_COUNT=$((VALIDATION_COUNT + 1))
    timestamp=$(date -Iseconds)
    
    if [ "$status" = "PASSED" ]; then
        PASSED_COUNT=$((PASSED_COUNT + 1))
        echo "✅ $validation_name - PASSED: $details"
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
        echo "❌ $validation_name - FAILED: $details"
    fi
    
    # Log detailed result
    cat >> "$RESULTS_DIR/sql_validation_$(date +%Y%m%d_%H%M%S).log" << EOF

=== $validation_name ===
Timestamp: $timestamp
Status: $status
Details: $details
Query:
$query

EOF
    
    VALIDATION_RESULTS+=("$validation_name|$status|$details")
}

# Execute SQL and capture result
execute_sql_validation() {
    local validation_name="$1"
    local sql_query="$2"
    local expected_condition="$3"
    
    echo ""
    echo "Executing: $validation_name"
    
    # Execute SQL using psql
    if result=$(psql "$DB_CONNECTION" -t -c "$sql_query" 2>&1); then
        # Clean up result (remove whitespace)
        result=$(echo "$result" | tr -d ' \t\n\r')
        
        # Validate result based on condition
        case "$expected_condition" in
            "COUNT_GT_0")
                if [[ "$result" =~ ^[0-9]+$ ]] && [ "$result" -gt 0 ]; then
                    log_validation_result "$validation_name" "PASSED" "Count: $result" "$sql_query"
                else
                    log_validation_result "$validation_name" "FAILED" "Invalid count: $result" "$sql_query"
                fi
                ;;
            "COUNT_MATCH")
                # For referential integrity checks
                if [[ "$result" =~ ^[0-9]+$ ]] && [ "$result" -eq 0 ]; then
                    log_validation_result "$validation_name" "PASSED" "No integrity violations found" "$sql_query"
                else
                    log_validation_result "$validation_name" "FAILED" "Integrity violations: $result" "$sql_query"
                fi
                ;;
            "BALANCE_POSITIVE")
                if [[ "$result" =~ ^[0-9]+$ ]] && [ "$result" -eq 0 ]; then
                    log_validation_result "$validation_name" "PASSED" "No negative balances found" "$sql_query"
                else
                    log_validation_result "$validation_name" "FAILED" "Negative balances found: $result" "$sql_query"
                fi
                ;;
            *)
                log_validation_result "$validation_name" "UNKNOWN" "Unknown condition: $expected_condition" "$sql_query"
                ;;
        esac
    else
        log_validation_result "$validation_name" "FAILED" "SQL execution error: $result" "$sql_query"
    fi
}

# Validation 1: Data Volume Verification
echo ""
echo "=== DATA VOLUME VERIFICATION ==="

execute_sql_validation "Customer Data Volume" \
    "SELECT COUNT(*) FROM customers;" \
    "COUNT_GT_0"

execute_sql_validation "Transaction Data Volume" \
    "SELECT COUNT(*) FROM transactions;" \
    "COUNT_GT_0"

execute_sql_validation "Audit Data Volume" \
    "SELECT COUNT(*) FROM transaction_audit;" \
    "COUNT_GT_0"

# Validation 2: Referential Integrity Checks
echo ""
echo "=== REFERENTIAL INTEGRITY VALIDATION ==="

execute_sql_validation "Transaction-Customer Integrity" \
    "SELECT COUNT(*) FROM transactions t WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = t.customer_id);" \
    "COUNT_MATCH"

execute_sql_validation "Audit-Transaction Integrity" \
    "SELECT COUNT(*) FROM transaction_audit ta WHERE NOT EXISTS (SELECT 1 FROM transactions t WHERE t.txn_id = ta.txn_id);" \
    "COUNT_MATCH"

execute_sql_validation "Audit-Customer Integrity" \
    "SELECT COUNT(*) FROM transaction_audit ta WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = ta.customer_id);" \
    "COUNT_MATCH"

# Validation 3: Business Logic Validation
echo ""
echo "=== BUSINESS LOGIC VALIDATION ==="

execute_sql_validation "No Negative Customer Balances" \
    "SELECT COUNT(*) FROM customers WHERE balance < 0;" \
    "BALANCE_POSITIVE"

execute_sql_validation "Transaction Amount Validation" \
    "SELECT COUNT(*) FROM transactions WHERE amount <= 0;" \
    "COUNT_MATCH"

execute_sql_validation "Audit Balance Consistency" \
    "SELECT COUNT(*) FROM transaction_audit ta JOIN customers c ON ta.customer_id = c.customer_id WHERE ABS(ta.new_balance - c.balance) > 0.01;" \
    "COUNT_MATCH"

# Validation 4: Complex Join Query Performance
echo ""
echo "=== COMPLEX JOIN QUERY VALIDATION ==="

complex_query="SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(t.txn_id) as transaction_count,
    SUM(t.amount) as total_amount,
    MAX(t.created_at) as last_transaction,
    COUNT(ta.audit_id) as audit_count
FROM customers c
LEFT JOIN transactions t ON c.customer_id = t.customer_id
LEFT JOIN transaction_audit ta ON t.txn_id = ta.txn_id
WHERE c.status = 'ACTIVE'
  AND t.status = 'COMPLETED'
  AND t.created_at >= NOW() - INTERVAL '30 days'
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(t.txn_id) > 0
ORDER BY total_amount DESC"

# Test complex query execution time
start_time=$(date +%s)

if complex_result=$(psql "$DB_CONNECTION" -t -c "$complex_query" 2>&1); then
    end_time=$(date +%s)
    execution_time=$((end_time - start_time))

    if [ "$execution_time" -le 10 ]; then
        log_validation_result "Complex Join Performance" "PASSED" "Execution time: ${execution_time}s" "$complex_query"
    else
        log_validation_result "Complex Join Performance" "FAILED" "Execution time too high: ${execution_time}s" "$complex_query"
    fi
else
    log_validation_result "Complex Join Performance" "FAILED" "Query execution failed" "$complex_query"
fi

# Validation 5: Data Consistency After Recent Transactions
echo ""
echo "=== RECENT TRANSACTION VALIDATION ==="

execute_sql_validation "Recent Transaction Audit Completeness" \
    "SELECT COUNT(*) FROM transactions t WHERE t.created_at >= NOW() - INTERVAL '1 day' AND NOT EXISTS (SELECT 1 FROM transaction_audit ta WHERE ta.txn_id = t.txn_id);" \
    "COUNT_MATCH"

execute_sql_validation "Transaction Status Consistency" \
    "SELECT COUNT(*) FROM transactions WHERE status NOT IN ('PENDING', 'COMPLETED', 'FAILED');" \
    "COUNT_MATCH"

# Generate validation summary
echo ""
echo "Generating SQL validation summary..."

cat > "$RESULTS_DIR/sql_validation_summary.json" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "database": {
        "host": "$DB_HOST",
        "database": "$DB_NAME",
        "user": "$DB_USER"
    },
    "validation_summary": {
        "total_validations": $VALIDATION_COUNT,
        "passed_validations": $PASSED_COUNT,
        "failed_validations": $FAILED_COUNT,
        "success_rate": $(echo "scale=2; $PASSED_COUNT * 100 / $VALIDATION_COUNT" | bc),
        "status": "$([ $FAILED_COUNT -eq 0 ] && echo "PASSED" || echo "FAILED")"
    },
    "validation_results": [
EOF

first=true
for result in "${VALIDATION_RESULTS[@]}"; do
    IFS='|' read -r validation_name status details <<< "$result"
    
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$RESULTS_DIR/sql_validation_summary.json"
    fi
    
    cat >> "$RESULTS_DIR/sql_validation_summary.json" << EOF
        {
            "validation_name": "$validation_name",
            "status": "$status",
            "details": "$details"
        }
EOF
done

cat >> "$RESULTS_DIR/sql_validation_summary.json" << EOF
    ]
}
EOF

# Print final summary
echo ""
echo "=== SQL VALIDATION SUMMARY ==="
echo "Total Validations: $VALIDATION_COUNT"
echo "Passed: $PASSED_COUNT"
echo "Failed: $FAILED_COUNT"
echo "Success Rate: $(echo "scale=1; $PASSED_COUNT * 100 / $VALIDATION_COUNT" | bc)%"

if [ $FAILED_COUNT -eq 0 ]; then
    echo "✅ All SQL validations PASSED"
    exit 0
else
    echo "❌ $FAILED_COUNT SQL validation(s) FAILED"
    exit 1
fi