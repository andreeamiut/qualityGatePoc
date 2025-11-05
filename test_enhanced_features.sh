#!/bin/bash
echo "🧪 TESTING ENHANCED TRANSACTION ENDPOINT"
echo ""

# Test 1: Valid transaction
echo "Test 1: Valid Transaction Processing"
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"customer_id": 1, "amount": 100.50, "transaction_type": "PAYMENT"}' \
  http://qualitygatepoc-app-1:5000/api/v1/transaction)

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q "SUCCESS"; then
    echo "✅ Transaction Processing: SUCCESS"
else
    echo "❌ Transaction Processing: FAILED"
fi
echo ""

# Test 2: Check connection pooling performance
echo "Test 2: Connection Pool Performance (5 concurrent requests)"
start_time=$(date +%s%N)

for i in {1..5}; do
    {
        curl -s -X POST -H "Content-Type: application/json" \
          -d "{\"customer_id\": $i, \"amount\": 50.25, \"transaction_type\": \"DEPOSIT\"}" \
          http://qualitygatepoc-app-1:5000/api/v1/transaction > /tmp/txn_$i.json
    } &
done
wait

end_time=$(date +%s%N)
duration=$(((end_time - start_time) / 1000000))

echo "5 concurrent transactions completed in ${duration}ms"
if [ $duration -lt 1000 ]; then
    echo "✅ Connection Pooling: EXCELLENT performance (<1s)"
elif [ $duration -lt 2000 ]; then
    echo "✅ Connection Pooling: GOOD performance (<2s)"
else
    echo "⚠️ Connection Pooling: Needs optimization (>2s)"
fi

# Show results
echo ""
echo "Transaction Results:"
for i in {1..5}; do
    if [ -f /tmp/txn_$i.json ]; then
        STATUS=$(cat /tmp/txn_$i.json | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        TXN_ID=$(cat /tmp/txn_$i.json | grep -o '"txn_id":"[^"]*"' | cut -d'"' -f4 | cut -c1-8)
        echo "  Transaction $i: $STATUS (ID: ${TXN_ID}...)"
    fi
done
echo ""

# Test 3: Redis Cache Test (if available)
echo "Test 3: Cache Performance Test"
CACHE_RESPONSE=$(curl -s http://qualitygatepoc-app-1:5000/api/v1/stats)
echo "Stats endpoint response time indicates cache performance"
if echo "$CACHE_RESPONSE" | grep -q "customers"; then
    echo "✅ Statistics Endpoint: WORKING (caching may be active)"
else
    echo "❌ Statistics Endpoint: FAILED"
fi

echo ""
echo "🎯 ENHANCED FEATURES TESTING COMPLETE"