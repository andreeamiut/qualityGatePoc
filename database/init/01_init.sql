-- B2B Transaction Database Schema
-- PostgreSQL Compatible

-- Create tables for B2B transaction processing
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_name VARCHAR(200) NOT NULL,
    company_name VARCHAR(300),
    balance DECIMAL(15,2) DEFAULT 0,
    created_date TIMESTAMP DEFAULT NOW(),
    last_transaction_date TIMESTAMP,
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

CREATE TABLE transactions (
    txn_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_txn_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE transaction_audit (
    audit_id VARCHAR(50) PRIMARY KEY,
    txn_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    old_balance DECIMAL(15,2),
    new_balance DECIMAL(15,2),
    audit_timestamp TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_audit_txn FOREIGN KEY (txn_id) REFERENCES transactions(txn_id),
    CONSTRAINT fk_audit_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Create indexes for performance
CREATE INDEX idx_customers_status ON customers(status);
CREATE INDEX idx_customers_last_txn ON customers(last_transaction_date);
CREATE INDEX idx_transactions_customer ON transactions(customer_id);
CREATE INDEX idx_transactions_created ON transactions(created_at);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_audit_txn ON transaction_audit(txn_id);
CREATE INDEX idx_audit_customer ON transaction_audit(customer_id);
CREATE INDEX idx_audit_timestamp ON transaction_audit(audit_timestamp);

-- Insert sample customers (simplified for demo)
INSERT INTO customers (customer_id, customer_name, company_name, balance, status) VALUES
('CUST_00000001', 'Customer 1', 'Tech Solutions Inc', 10000.00, 'ACTIVE'),
('CUST_00000002', 'Customer 2', 'Global Industries LLC', 15000.00, 'ACTIVE'),
('CUST_00000003', 'Customer 3', 'Enterprise Systems Corp', 25000.00, 'ACTIVE'),
('CUST_00000004', 'Customer 4', 'Digital Dynamics Ltd', 5000.00, 'ACTIVE'),
('CUST_00000005', 'Customer 5', 'Innovation Labs Group', 30000.00, 'ACTIVE');

-- Generate more customers for load testing
INSERT INTO customers (customer_id, customer_name, company_name, balance, status)
SELECT 
    'CUST_' || LPAD(generate_series::TEXT, 8, '0'),
    'Customer ' || generate_series,
    CASE (generate_series % 6)
        WHEN 0 THEN 'Tech Solutions Inc'
        WHEN 1 THEN 'Global Industries LLC'
        WHEN 2 THEN 'Enterprise Systems Corp'
        WHEN 3 THEN 'Digital Dynamics Ltd'
        WHEN 4 THEN 'Innovation Labs Group'
        ELSE 'Strategic Partners International'
    END,
    (1000 + (generate_series % 10000))::DECIMAL(15,2),
    CASE WHEN generate_series % 100 = 0 THEN 'INACTIVE' ELSE 'ACTIVE' END
FROM generate_series(6, 1000);

COMMIT;