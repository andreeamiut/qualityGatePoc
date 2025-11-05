# Standard library imports
from datetime import datetime  # For timestamp handling
import json  # For JSON serialization/deserialization
import logging  # For application logging
import os  # For environment variable access and file operations
import threading  # For thread-safe database connection pooling
import time  # For performance timing measurements
import uuid  # For generating unique transaction IDs
from contextlib import contextmanager  # For context manager decorator
from typing import Optional, Any, Dict  # Type hints for better code documentation

# Third-party imports
from flask import Flask, request, jsonify  # Flask web framework
from werkzeug.exceptions import HTTPException  # HTTP exception handling
import psycopg2  # PostgreSQL database driver
import psycopg2.pool  # Connection pooling for database
import redis  # Redis cache client

# Initialize Flask application
app = Flask(__name__)

# Application constants for configuration and maintainability
LOG_DIR = '/opt/app/logs'  # Directory for application logs
LOG_FILE = os.path.join(LOG_DIR, 'portal.log')  # Main log file path
DB_MIN_CONN = 5  # Minimum database connections in pool
DB_MAX_CONN = 20  # Maximum database connections in pool
REDIS_HOST = 'redis'  # Redis server hostname
REDIS_PORT = 6379  # Redis server port
REDIS_DB = 0  # Redis database number
PROCESSING_DELAY_MS = 0  # Removed simulated delay for performance (set to 0)
TRANSACTION_TYPES = ['debit', 'credit']  # Supported transaction types
STATS_CACHE_TTL = 300  # Cache TTL for statistics in seconds (5 minutes)
LOG_TRANSACTION_FAILED = "B2B_TRANSACTION_FAILED|TXN_ID:%s|ERROR:%s|PROCESSING_TIME:%.2fms"  # Log format for failed transactions

# Configure application logging
os.makedirs(LOG_DIR, exist_ok=True)  # Create log directory if it doesn't exist
logging.basicConfig(
    level=logging.INFO,  # Set logging level to INFO
    format='%(asctime)s - %(levelname)s - %(message)s',  # Log format with timestamp and level
    handlers=[
        logging.FileHandler(LOG_FILE),  # Log to file
        logging.StreamHandler()  # Also log to console
    ]
)
logger = logging.getLogger(__name__)  # Get logger for this module

# Database connection configuration from environment variables
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'oracle-db'),  # Database host (default: oracle-db)
    'port': int(os.getenv('DB_PORT', '5432')),  # Database port (default: 5432)
    'database': os.getenv('DB_NAME', 'b2b_db'),  # Database name (default: b2b_db)
    'user': os.getenv('DB_USER', 'b2b_user'),  # Database username (default: b2b_user)
    'password': os.getenv('DB_PASSWORD', 'b2b_password')  # Database password (default: b2b_password)
}

# Database connection manager with thread-safe pool management
class DatabaseConnectionManager:
    """Manages database connections using a thread-safe connection pool."""

    def __init__(self) -> None:
        self.pool: Optional[psycopg2.pool.ThreadedConnectionPool] = None  # Connection pool instance
        self.lock = threading.Lock()  # Thread lock for pool initialization

    def init_pool(self) -> None:
        """Initialize the database connection pool if not already created."""
        with self.lock:  # Ensure thread-safe pool creation
            if self.pool is None:
                try:
                    self.pool = psycopg2.pool.ThreadedConnectionPool(
                        minconn=DB_MIN_CONN,  # Minimum connections
                        maxconn=DB_MAX_CONN,  # Maximum connections
                        **DB_CONFIG  # Unpack database configuration
                    )
                    logger.info("Database connection pool initialized successfully")
                except psycopg2.Error as e:
                    logger.error("Failed to create connection pool: %s", e)
                    raise  # Re-raise to indicate initialization failure

    @contextmanager
    def get_connection(self):
        """Context manager that provides a database connection and ensures it's returned to the pool."""
        if self.pool is None:
            self.init_pool()  # Lazy initialization of pool
        conn = None
        try:
            conn = self.pool.getconn()  # Get connection from pool
            yield conn  # Provide connection to caller
        except psycopg2.Error as e:
            logger.error("Database connection failed: %s", e)
            raise  # Re-raise database errors
        finally:
            if conn:
                try:
                    self.pool.putconn(conn)  # Return connection to pool
                except psycopg2.Error as e:
                    logger.error("Failed to return connection to pool: %s", e)

# Global database connection manager instance
db_manager = DatabaseConnectionManager()

# Redis cache initialization with graceful fallback
REDIS_CLIENT: Optional[redis.Redis] = None  # Redis client instance
REDIS_ENABLED = os.getenv('REDIS_ENABLED', 'false').lower() == 'true'  # Check if Redis is enabled

if REDIS_ENABLED:
    try:
        REDIS_CLIENT = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB,
                                    decode_responses=True)  # Create Redis client
        REDIS_CLIENT.ping()  # Test connection
        logger.info("Redis cache connected successfully")
    except redis.ConnectionError:
        logger.warning("Redis configured but not available, running without cache")
        REDIS_CLIENT = None  # Disable cache if connection fails
else:
    logger.info("Redis cache disabled")

def validate_transaction_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """Validate and sanitize transaction request data."""
    required_fields = ['customer_id', 'amount', 'transaction_type']  # Required fields for transaction
    for field in required_fields:
        if field not in data:
            raise ValueError(f"Missing required field: {field}")  # Ensure all required fields are present

    customer_id = str(data['customer_id']).strip()  # Convert to string and remove whitespace
    if not customer_id:
        raise ValueError("Customer ID cannot be empty")  # Reject empty customer IDs

    try:
        amount = float(data['amount'])  # Convert amount to float
        if amount <= 0:
            raise ValueError("Amount must be positive")  # Ensure positive amount
    except (ValueError, TypeError) as exc:
        raise ValueError("Amount must be a valid positive number") from exc  # Handle invalid amount formats

    transaction_type = str(data['transaction_type']).strip().lower()  # Normalize transaction type
    if transaction_type not in TRANSACTION_TYPES:
        raise ValueError(f"Transaction type must be one of: {', '.join(TRANSACTION_TYPES)}")  # Validate transaction type

    return {  # Return validated and sanitized data
        'customer_id': customer_id,
        'amount': amount,
        'transaction_type': transaction_type
    }

def execute_database_transaction(cursor: Any, txn_id: str, customer_id: str,
                                amount: float, transaction_type: str) -> None:
    """Execute all database operations for a transaction with proper error handling."""
    # 1. Insert transaction record with PROCESSING status
    insert_txn_sql = """
    INSERT INTO transactions (txn_id, customer_id, amount,
                               transaction_type, status, created_at)
    VALUES (%s, %s, %s, %s, 'PROCESSING', NOW())
    """
    cursor.execute(insert_txn_sql, (txn_id, customer_id, amount, transaction_type))

    # 2. Retrieve current customer balance
    cursor.execute("SELECT balance FROM customers WHERE customer_id = %s", (customer_id,))
    result = cursor.fetchone()
    if result is None:
        raise ValueError(f"Customer {customer_id} does not exist")  # Customer not found
    old_balance = float(result[0])  # Convert balance to float

    # 3. Calculate balance change based on transaction type
    if transaction_type == 'debit':
        if old_balance < amount:  # Check if account has sufficient funds for debit
            raise ValueError(f"Insufficient balance for debit transaction. "
                             f"Current balance: {old_balance}, Debit amount: {amount}")  # Raise error with details
        balance_change = -amount  # Set balance change to negative amount for debit
    elif transaction_type == 'credit':
        balance_change = amount  # Positive change for credit
    else:
        raise ValueError(f"Invalid transaction type: {transaction_type}")  # Should not reach here due to validation

    # Update customer balance and last transaction date
    update_balance_sql = """
    UPDATE customers
    SET balance = balance + %s, last_transaction_date = NOW()
    WHERE customer_id = %s
    """
    cursor.execute(update_balance_sql, (balance_change, customer_id))

    # 4. Insert audit record for transaction tracking
    audit_sql = """
    INSERT INTO transaction_audit (audit_id, txn_id, customer_id,
                                    old_balance, new_balance,
                                    audit_timestamp)
    VALUES (%s, %s, %s, %s, %s, NOW())
    """
    audit_id = str(uuid.uuid4())  # Generate unique audit ID
    new_balance = old_balance + balance_change  # Calculate new balance
    cursor.execute(audit_sql, (audit_id, txn_id, customer_id, old_balance, new_balance))

    # 5. Mark transaction as completed
    cursor.execute("UPDATE transactions SET status = 'COMPLETED' "
                    "WHERE txn_id = %s", (txn_id,))

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint returning current status and timestamp."""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})

@app.route('/api/v1/transaction', methods=['POST'])
def process_transaction():
    """
    Main B2B transaction processing endpoint.

    Processes a transaction with database updates, including balance changes
    and audit logging. Supports debit and credit operations.
    """
    start_time = time.time()
    txn_id = str(uuid.uuid4())

    try:
        # Extract and validate request data
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        validated_data = validate_transaction_data(data)
        customer_id = validated_data['customer_id']
        amount = validated_data['amount']
        transaction_type = validated_data['transaction_type']

        # Log transaction initiation
        logger.info("B2B_TRANSACTION_INITIATED|TXN_ID:%s|CUSTOMER_ID:%s|"
                    "AMOUNT:%.2f|TYPE:%s", txn_id, customer_id, amount,
                    transaction_type)

        # Database operations with context manager
        with db_manager.get_connection() as connection:
            with connection.cursor() as cursor:
                # Execute database transaction
                execute_database_transaction(cursor, txn_id, customer_id, amount, transaction_type)
                # Commit transaction
                connection.commit()

        processing_time = (time.time() - start_time) * 1000  # ms

        # Log successful completion
        logger.info("B2B_TRANSACTION_COMPLETED|TXN_ID:%s|"
                    "PROCESSING_TIME:%.2fms|STATUS:SUCCESS",
                    txn_id, processing_time)

        return jsonify({
            "txn_id": txn_id,
            "status": "SUCCESS",
            "customer_id": customer_id,
            "amount": amount,
            "transaction_type": transaction_type,
            "processing_time_ms": processing_time,
            "timestamp": datetime.now().isoformat()
        }), 200

    except ValueError as e:
        processing_time = (time.time() - start_time) * 1000
        logger.error(LOG_TRANSACTION_FAILED, txn_id, str(e), processing_time)
        return jsonify({
            "txn_id": txn_id,
            "status": "ERROR",
            "error": str(e),
            "processing_time_ms": processing_time,
            "timestamp": datetime.now().isoformat()
        }), 400  # Bad request for validation errors

    except psycopg2.Error as e:
        processing_time = (time.time() - start_time) * 1000
        logger.error(LOG_TRANSACTION_FAILED, txn_id, str(e), processing_time)
        return jsonify({
            "txn_id": txn_id,
            "status": "ERROR",
            "error": "Database operation failed",
            "processing_time_ms": processing_time,
            "timestamp": datetime.now().isoformat()
        }), 500


@app.route('/api/v1/stats', methods=['GET'])
def get_stats():
    """
    Get transaction statistics for the last 24 hours.

    Returns aggregated statistics with optional Redis caching.
    """
    # Check cache first
    cache_key = "stats_24h"
    if REDIS_CLIENT:
        cached_stats = REDIS_CLIENT.get(cache_key)
        if cached_stats:
            return jsonify(json.loads(cached_stats)), 200

    connection = None
    cursor = None
    try:
        with db_manager.get_connection() as connection:
            with connection.cursor() as cursor:
                # Optimized query with proper aggregation
                stats_query = """
                SELECT
                    COUNT(t.txn_id) as total_transactions,
                    COALESCE(SUM(t.amount), 0) as total_amount,
                    COALESCE(AVG(t.amount), 0) as avg_amount,
                    COUNT(DISTINCT c.customer_id) as unique_customers,
                    COUNT(ta.audit_id) as audit_records
                FROM transactions t
                JOIN customers c ON t.customer_id = c.customer_id
                LEFT JOIN transaction_audit ta ON t.txn_id = ta.txn_id
                WHERE t.created_at >= NOW() - INTERVAL '1 day'
                """

                cursor.execute(stats_query)
                result = cursor.fetchone()

                stats = {
                    "total_transactions": result[0],
                    "total_amount": float(result[1]),
                    "avg_amount": float(result[2]),
                    "unique_customers": result[3],
                    "audit_records": result[4],
                    "timestamp": datetime.now().isoformat()
                }

        # Cache the result
        if REDIS_CLIENT:
            REDIS_CLIENT.setex(cache_key, STATS_CACHE_TTL, json.dumps(stats))

        return jsonify(stats), 200

    except psycopg2.Error as e:
        logger.error("Stats query failed: %s", e)
        return jsonify({"error": "Database query failed", "details": str(e)}), 500

@app.errorhandler(Exception)
def handle_unexpected_error(e):
    """Handle unexpected exceptions globally, returning JSON error response."""
    if isinstance(e, HTTPException):
        # Let Flask handle HTTP exceptions normally
        return e
    logger.error("Unexpected error: %s", str(e))
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
