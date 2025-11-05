-- Generate 100,000+ dummy records for performance testing
-- Insert customers (50,000 records)
INSERT INTO customers (customer_id, customer_name, company_name, balance, created_date, last_transaction_date, status)
SELECT 
    'CUST_' || LPAD(generate_series::text, 8, '0'),
    'Customer ' || generate_series,
    CASE (generate_series % 6)
        WHEN 0 THEN 'Tech Solutions Inc'
        WHEN 1 THEN 'Global Industries LLC'
        WHEN 2 THEN 'Enterprise Systems Corp'
        WHEN 3 THEN 'Digital Dynamics Ltd'
        WHEN 4 THEN 'Innovation Labs Group'
        ELSE 'Strategic Partners International'
    END,
    ROUND((RANDOM() * 999000 + 1000)::numeric, 2),
    NOW() - (RANDOM() * INTERVAL '365 days'),
    NOW() - (RANDOM() * INTERVAL '30 days'),
    CASE WHEN (generate_series % 100) = 0 THEN 'INACTIVE' ELSE 'ACTIVE' END
FROM generate_series(1, 50000);

-- Insert transactions (80,000 records)
INSERT INTO transactions (txn_id, customer_id, amount, transaction_type, status, created_at, updated_at)
SELECT 
    'TXN_' || LPAD(generate_series::text, 10, '0'),
    'CUST_' || LPAD((FLOOR(RANDOM() * 50000) + 1)::text, 8, '0'),
    ROUND((RANDOM() * 9990 + 10)::numeric, 2),
    CASE (generate_series % 6)
        WHEN 0 THEN 'PAYMENT'
        WHEN 1 THEN 'REFUND'
        WHEN 2 THEN 'TRANSFER'
        WHEN 3 THEN 'DEPOSIT'
        WHEN 4 THEN 'WITHDRAWAL'
        ELSE 'ADJUSTMENT'
    END,
    CASE 
        WHEN (generate_series % 20) = 0 THEN 'FAILED' 
        WHEN (generate_series % 15) = 0 THEN 'PENDING' 
        ELSE 'COMPLETED' 
    END,
    NOW() - (RANDOM() * INTERVAL '180 days'),
    NOW() - (RANDOM() * INTERVAL '30 days')
FROM generate_series(1, 80000);

-- Insert audit records for transactions (80,000 records)
INSERT INTO transaction_audit (audit_id, txn_id, customer_id, old_balance, new_balance, audit_timestamp)
SELECT 
    'AUDIT_' || SUBSTRING(t.txn_id FROM 5),
    t.txn_id,
    t.customer_id,
    c.balance - t.amount,
    c.balance,
    t.created_at
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id;