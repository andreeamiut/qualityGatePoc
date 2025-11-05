-- B2B Transaction Database Schema
-- Oracle 19c Compatible

-- Create tables for B2B transaction processing
CREATE TABLE customers (
    customer_id VARCHAR2(50) PRIMARY KEY,
    customer_name VARCHAR2(200) NOT NULL,
    company_name VARCHAR2(300),
    balance NUMBER(15,2) DEFAULT 0,
    created_date DATE DEFAULT SYSDATE,
    last_transaction_date DATE,
    status VARCHAR2(20) DEFAULT 'ACTIVE'
);

CREATE TABLE transactions (
    txn_id VARCHAR2(50) PRIMARY KEY,
    customer_id VARCHAR2(50) NOT NULL,
    amount NUMBER(15,2) NOT NULL,
    transaction_type VARCHAR2(50) NOT NULL,
    status VARCHAR2(20) DEFAULT 'PENDING',
    created_at DATE DEFAULT SYSDATE,
    updated_at DATE DEFAULT SYSDATE,
    CONSTRAINT fk_txn_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE transaction_audit (
    audit_id VARCHAR2(50) PRIMARY KEY,
    txn_id VARCHAR2(50) NOT NULL,
    customer_id VARCHAR2(50) NOT NULL,
    old_balance NUMBER(15,2),
    new_balance NUMBER(15,2),
    audit_timestamp DATE DEFAULT SYSDATE,
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

-- Create sequences for generating IDs
CREATE SEQUENCE customer_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE transaction_seq START WITH 1 INCREMENT BY 1;

COMMIT;