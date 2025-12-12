# Standard library imports
from datetime import datetime
import json
import logging
import os
import threading
import time
import uuid
from contextlib import contextmanager
from typing import Optional, Any, Dict

# Third-party imports
from flask import Flask, request, jsonify
from werkzeug.exceptions import HTTPException
import psycopg2
import psycopg2.pool
import redis

# Initialize Flask application
app = Flask(__name__)

# Application constants - OPTIMIZED for high concurrency
LOG_DIR = '/opt/app/logs'
LOG_FILE = os.path.join(LOG_DIR, 'portal.log')
DB_MIN_CONN = 10   # Increased from 5
DB_MAX_CONN = 50   # Increased from 20 for high concurrency
REDIS_HOST = 'redis'
REDIS_PORT = 6379
REDIS_DB = 0
PROCESSING_DELAY_MS = 0
TRANSACTION_TYPES = ['debit', 'credit']
STATS_CACHE_TTL = 300
LOG_TRANSACTION_FAILED = "B2B_TRANSACTION_FAILED|TXN_ID:%s|ERROR:%s|PROCESSING_TIME:%.2fms"

# Configure logging
os.makedirs(LOG_DIR, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres-db'),
    'port': int(os.getenv('DB_PORT', '5432')),
    'database': os.getenv('DB_NAME', 'b2b_db'),
    'user': os.getenv('DB_USER', 'b2b_user'),
    'password': os.getenv('DB_PASSWORD', 'b2b_password')
}

class DatabaseConnectionManager:
    """Manages database connections using a thread-safe connection pool."""

    def __init__(self) -> None:
        self.pool: Optional[psycopg2.pool.ThreadedConnectionPool] = None
        self.lock = threading.Lock()

    def init_pool(self) -> None:
        with self.lock:
            if self.pool is None:
                try:
                    self.pool = psycopg2.pool.ThreadedConnectionPool(
                        minconn=DB_MIN_CONN,
                        maxconn=DB_MAX_CONN,
                        **DB_CONFIG
                    )
                    logger.info("Database connection pool initialized (min=%d, max=%d)", 
                               DB_MIN_CONN, DB_MAX_CONN)
                except psycopg2.Error as e:
                    logger.error("Failed to create connection pool: %s", e)
                    raise

    @contextmanager
    def get_connection(self):
        if self.pool is None:
            self.init_pool()
        conn = None
        try:
            conn = self.pool.getconn()
            yield conn
        except psycopg2.Error as e:
            logger.error("Database connection failed: %s", e)
            raise
        finally:
            if conn:
                try:
                    self.pool.putconn(conn)
                except psycopg2.Error as e:
                    logger.error("Failed to return connection to pool: %s", e)

db_manager = DatabaseConnectionManager()

# Redis cache with connection pool for high concurrency
REDIS_CLIENT: Optional[redis.Redis] = None
REDIS_ENABLED = os.getenv('REDIS_ENABLED', 'false').lower() == 'true'

if REDIS_ENABLED:
    try:
        redis_pool = redis.ConnectionPool(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            max_connections=100,
            socket_timeout=0.1,
            socket_connect_timeout=0.1,
            retry_on_timeout=True,
            health_check_interval=30,
            decode_responses=True
        )
        REDIS_CLIENT = redis.Redis(connection_pool=redis_pool)
        REDIS_CLIENT.ping()
        logger.info("Redis cache connected with connection pool (max=100)")
    except redis.ConnectionError:
        logger.warning("Redis not available, running without cache")
        REDIS_CLIENT = None
else:
    logger.info("Redis cache disabled")


def get_cached(key: str) -> Optional[str]:
    """Get value from cache with fast timeout."""
    if not REDIS_CLIENT:
        return None
    try:
        return REDIS_CLIENT.get(key)
    except redis.RedisError:
        return None


def set_cached(key: str, value: str, ttl: int = STATS_CACHE_TTL) -> None:
    """Set cache value with error handling."""
    if not REDIS_CLIENT:
        return
    try:
        REDIS_CLIENT.setex(key, ttl, value)
    except redis.RedisError:
        pass


def validate_transaction_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """Validate and sanitize transaction request data."""
    required_fields = ['customer_id', 'amount', 'transaction_type']
    for field in required_fields:
        if field not in data:
            raise ValueError(f"Missing required field: {field}")

    customer_id = str(data['customer_id']).strip()
    if not customer_id:
        raise ValueError("Customer ID cannot be empty")

    try:
        amount = float(data['amount'])
        if amount <= 0:
            raise ValueError("Amount must be positive")
    except (ValueError, TypeError) as exc:
        raise ValueError("Amount must be a valid positive number") from exc

    transaction_type = str(data['transaction_type']).strip().lower()
    if transaction_type not in TRANSACTION_TYPES:
        raise ValueError(f"Transaction type must be one of: {', '.join(TRANSACTION_TYPES)}")

    return {
        'customer_id': customer_id,
        'amount': amount,
        'transaction_type': transaction_type
    }


def execute_database_transaction(cursor: Any, txn_id: str, customer_id: str,
                                amount: float, transaction_type: str) -> None:
    """Execute all database operations for a transaction."""
    cursor.execute("""
        INSERT INTO transactions (txn_id, customer_id, amount,
                                   transaction_type, status, created_at)
        VALUES (%s, %s, %s, %s, 'PROCESSING', NOW())
    """, (txn_id, customer_id, amount, transaction_type))

    cursor.execute("SELECT balance FROM customers WHERE customer_id = %s", (customer_id,))
    result = cursor.fetchone()
    if result is None:
        raise ValueError(f"Customer {customer_id} does not exist")
    old_balance = float(result[0])

    if transaction_type == 'debit':
        if old_balance < amount:
            raise ValueError(f"Insufficient balance. Current: {old_balance}, Debit: {amount}")
        balance_change = -amount
    elif transaction_type == 'credit':
        balance_change = amount
    else:
        raise ValueError(f"Invalid transaction type: {transaction_type}")

    cursor.execute("""
        UPDATE customers
        SET balance = balance + %s, last_transaction_date = NOW()
        WHERE customer_id = %s
    """, (balance_change, customer_id))

    audit_id = str(uuid.uuid4())
    new_balance = old_balance + balance_change
    cursor.execute("""
        INSERT INTO transaction_audit (audit_id, txn_id, customer_id,
                                        old_balance, new_balance, audit_timestamp)
        VALUES (%s, %s, %s, %s, %s, NOW())
    """, (audit_id, txn_id, customer_id, old_balance, new_balance))

    cursor.execute("UPDATE transactions SET status = 'COMPLETED' WHERE txn_id = %s", (txn_id,))


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()})


@app.route('/api/v1/transaction', methods=['POST'])
def process_transaction():
    """Main B2B transaction processing endpoint."""
    start_time = time.time()
    txn_id = str(uuid.uuid4())

    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400

        validated_data = validate_transaction_data(data)
        customer_id = validated_data['customer_id']
        amount = validated_data['amount']
        transaction_type = validated_data['transaction_type']

        logger.info("B2B_TRANSACTION_INITIATED|TXN_ID:%s|CUSTOMER_ID:%s|AMOUNT:%.2f|TYPE:%s",
                    txn_id, customer_id, amount, transaction_type)

        with db_manager.get_connection() as connection:
            with connection.cursor() as cursor:
                execute_database_transaction(cursor, txn_id, customer_id, amount, transaction_type)
                connection.commit()

        processing_time = (time.time() - start_time) * 1000

        logger.info("B2B_TRANSACTION_COMPLETED|TXN_ID:%s|PROCESSING_TIME:%.2fms|STATUS:SUCCESS",
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
        }), 400

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
    """Get transaction statistics with cache-first pattern."""
    cache_key = "stats_24h"
    
    # Fast cache lookup
    cached = get_cached(cache_key)
    if cached:
        stats = json.loads(cached)
        stats['from_cache'] = True
        return jsonify(stats), 200

    # Fallback to database with optimized query
    try:
        with db_manager.get_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_transactions,
                        COALESCE(SUM(amount), 0) as total_amount,
                        COALESCE(AVG(amount), 0) as avg_amount
                    FROM transactions 
                    WHERE created_at >= NOW() - INTERVAL '1 day'
                """)
                result = cursor.fetchone()

                stats = {
                    "total_transactions": result[0],
                    "total_amount": float(result[1]),
                    "avg_amount": float(result[2]),
                    "timestamp": datetime.now().isoformat(),
                    "from_cache": False
                }

        set_cached(cache_key, json.dumps(stats))
        return jsonify(stats), 200

    except psycopg2.Error as e:
        logger.error("Stats query failed: %s", e)
        return jsonify({"error": "Database query failed"}), 500


@app.errorhandler(Exception)
def handle_unexpected_error(e):
    """Handle unexpected exceptions globally."""
    if isinstance(e, HTTPException):
        return e
    logger.error("Unexpected error: %s", str(e))
    return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
