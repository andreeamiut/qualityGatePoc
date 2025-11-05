-- Generate 100,000+ dummy records for performance testing
-- Insert customers (50,000 records)
INSERT INTO customers (customer_id, customer_name, company_name, balance, created_date, last_transaction_date, status)
SELECT 
    'CUST_' || LPAD(LEVEL, 8, '0'),
    'Customer ' || LEVEL,
    CASE MOD(LEVEL, 6)
        WHEN 0 THEN 'Tech Solutions Inc'
        WHEN 1 THEN 'Global Industries LLC'
        WHEN 2 THEN 'Enterprise Systems Corp'
        WHEN 3 THEN 'Digital Dynamics Ltd'
        WHEN 4 THEN 'Innovation Labs Group'
        ELSE 'Strategic Partners International'
    END,
    ROUND(DBMS_RANDOM.VALUE(1000, 1000000), 2),
    SYSDATE - DBMS_RANDOM.VALUE(1, 365),
    SYSDATE - DBMS_RANDOM.VALUE(1, 30),
    CASE WHEN MOD(LEVEL, 100) = 0 THEN 'INACTIVE' ELSE 'ACTIVE' END
FROM dual
CONNECT BY LEVEL <= 50000;
COMMIT;
-- Insert transactions (80,000 records)
INSERT INTO transactions (txn_id, customer_id, amount, transaction_type, status, created_at, updated_at)
SELECT 
    'TXN_' || LPAD(LEVEL, 10, '0'),
    'CUST_' || LPAD(CEIL(DBMS_RANDOM.VALUE(1, 50000)), 8, '0'),
    ROUND(DBMS_RANDOM.VALUE(10, 10000), 2),
    CASE MOD(LEVEL, 6)
        WHEN 0 THEN 'PAYMENT'
        WHEN 1 THEN 'REFUND'
        WHEN 2 THEN 'TRANSFER'
        WHEN 3 THEN 'DEPOSIT'
        WHEN 4 THEN 'WITHDRAWAL'
        ELSE 'ADJUSTMENT'
    END,
    CASE WHEN MOD(LEVEL, 20) = 0 THEN 'FAILED' 
         WHEN MOD(LEVEL, 15) = 0 THEN 'PENDING' 
         ELSE 'COMPLETED' END,
    SYSDATE - DBMS_RANDOM.VALUE(1, 180),
    SYSDATE - DBMS_RANDOM.VALUE(0, 30)
FROM dual
CONNECT BY LEVEL <= 80000;

COMMIT;
-- Insert audit records for transactions (80,000 records)
INSERT INTO transaction_audit (audit_id, txn_id, customer_id, old_balance, new_balance, audit_timestamp)
SELECT 
    'AUDIT_' || SUBSTR(t.txn_id, 5),
    t.txn_id,
    t.customer_id,
    c.balance - t.amount,
    c.balance,
    t.created_at
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id;

COMMIT;