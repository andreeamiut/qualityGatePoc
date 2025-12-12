#!/bin/bash
echo "Testing single transaction..."

curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"customer_id": "CUST_00000002", "amount": 100.50, "transaction_type": "debit"}' \
  http://qualitygatepoc-app-1:5000/api/v1/transaction

echo ""
echo "Checking logs..."