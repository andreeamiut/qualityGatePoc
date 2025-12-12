#!/bin/bash
echo "=== PostgreSQL DATABASE VALIDATION ==="
echo "Testing database connection and data integrity..."

# Test database connection
if psql -h postgres -U postgres -d b2b_db -c "SELECT version();" 2>/dev/null; then
    echo "✅ Database Connection: SUCCESS"
else
    echo "❌ Database Connection: FAILED"
fi

# Test data volume
CUSTOMER_COUNT=$(psql -h postgres -U postgres -d b2b_db -t -c "SELECT COUNT(*) FROM customers;" 2>/dev/null | xargs)
echo "Customer Records: $CUSTOMER_COUNT"
if [ "$CUSTOMER_COUNT" -gt 40000 ]; then
    echo "✅ Customer Data Volume: SUCCESS (>40k records)"
else
    echo "❌ Customer Data Volume: FAILED"
fi

TRANSACTION_COUNT=$(psql -h postgres -U postgres -d b2b_db -t -c "SELECT COUNT(*) FROM transactions;" 2>/dev/null | xargs)
echo "Transaction Records: $TRANSACTION_COUNT"
if [ "$TRANSACTION_COUNT" -gt 50000 ]; then
    echo "✅ Transaction Data Volume: SUCCESS (>50k records)"
else
    echo "❌ Transaction Data Volume: FAILED"
fi

AUDIT_COUNT=$(psql -h postgres -U postgres -d b2b_db -t -c "SELECT COUNT(*) FROM transaction_audit;" 2>/dev/null | xargs)
echo "Audit Records: $AUDIT_COUNT"
if [ "$AUDIT_COUNT" -gt 50000 ]; then
    echo "✅ Audit Data Volume: SUCCESS (>50k records)"
else
    echo "❌ Audit Data Volume: FAILED"
fi

# Test referential integrity
ORPHAN_TXN=$(psql -h postgres -U postgres -d b2b_db -t -c "SELECT COUNT(*) FROM transactions t LEFT JOIN customers c ON t.customer_id = c.customer_id WHERE c.customer_id IS NULL;" 2>/dev/null | xargs)
echo "Orphaned Transactions: $ORPHAN_TXN"
if [ "$ORPHAN_TXN" -eq 0 ]; then
    echo "✅ Transaction-Customer Integrity: SUCCESS"
else
    echo "❌ Transaction-Customer Integrity: FAILED"
fi

# Test performance query
echo "Testing complex join performance..."
START_TIME=$(date +%s%N)
RESULT=$(psql -h postgres -U postgres -d b2b_db -t -c "SELECT COUNT(*) FROM customers c JOIN transactions t ON c.customer_id = t.customer_id JOIN transaction_audit ta ON t.transaction_id = ta.transaction_id;" 2>/dev/null | xargs)
END_TIME=$(date +%s%N)
DURATION=$(((END_TIME - START_TIME) / 1000000))
echo "Complex Join Result: $RESULT records in ${DURATION}ms"
if [ $DURATION -lt 5000 ]; then
    echo "✅ Complex Join Performance: SUCCESS (<5s)"
else
    echo "❌ Complex Join Performance: SLOW (>5s)"
fi

echo ""
echo "=== DATABASE VALIDATION COMPLETE ==="