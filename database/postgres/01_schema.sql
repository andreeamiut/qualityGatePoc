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