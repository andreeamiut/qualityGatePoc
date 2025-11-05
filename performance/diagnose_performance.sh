#!/bin/bash

# Performance Diagnostic Script
# Automatically diagnoses performance issues and suggests fixes

set -e

echo "=== PERFORMANCE DIAGNOSTIC ANALYSIS ==="

# Check application container resources
echo "Checking application container resource utilization..."

# Get container stats
CONTAINER_NAME="qualitygatepoc-app-1"
if docker ps --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"; then
    echo "Container Status: RUNNING"
    
    # Get real-time stats
    STATS=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "$CONTAINER_NAME" | tail -1)
    CPU_PERCENT=$(echo "$STATS" | awk '{print $1}' | sed 's/%//')
    MEM_USAGE=$(echo "$STATS" | awk '{print $2}')
    MEM_PERCENT=$(echo "$STATS" | awk '{print $3}' | sed 's/%//')
    
    echo "Current Resource Usage:"
    echo "  CPU: ${CPU_PERCENT}%"
    echo "  Memory: ${MEM_USAGE} (${MEM_PERCENT}%)"
    
    # Analyze resource constraints
    if (( $(echo "$CPU_PERCENT > 80" | bc -l) )); then
        echo "⚠️  HIGH CPU USAGE DETECTED (${CPU_PERCENT}%)"
        echo "💡 RECOMMENDATION: Increase CPU limit from 2 to 4 cores"
        echo "   Update docker-compose.yml:"
        echo "   cpus: '4.0'"
    fi
    
    if (( $(echo "$MEM_PERCENT > 80" | bc -l) )); then
        echo "⚠️  HIGH MEMORY USAGE DETECTED (${MEM_PERCENT}%)"
        echo "💡 RECOMMENDATION: Increase memory limit from 4GB to 8GB"
        echo "   Update docker-compose.yml:"
        echo "   mem_limit: 8g"
    fi
    
    # Check database connection pool
    echo ""
    echo "Checking database connectivity..."
    
    # Test database responsiveness
    DB_CONTAINER="qualitygatepoc-oracle-db-1"
    if docker ps --format "table {{.Names}}" | grep -q "$DB_CONTAINER"; then
        echo "Database Status: RUNNING"
        
        # Check database performance
        DB_STATS=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemPerc}}" "$DB_CONTAINER" | tail -1)
        DB_CPU=$(echo "$DB_STATS" | awk '{print $1}' | sed 's/%//')
        DB_MEM=$(echo "$DB_STATS" | awk '{print $2}' | sed 's/%//')
        
        echo "Database Resource Usage:"
        echo "  CPU: ${DB_CPU}%"
        echo "  Memory: ${DB_MEM}%"
        
        if (( $(echo "$DB_CPU > 70" | bc -l) )); then
            echo "⚠️  DATABASE CPU BOTTLENECK (${DB_CPU}%)"
            echo "💡 RECOMMENDATIONS:"
            echo "   1. Add database connection pooling"
            echo "   2. Optimize SQL queries with EXPLAIN PLAN"
            echo "   3. Add database indexes on frequently queried columns"
            echo "   4. Increase database shared_pool_size"
        fi
        
    else
        echo "❌ Database container not found or not running"
        echo "💡 RECOMMENDATION: Ensure Oracle database is running and accessible"
    fi
    
else
    echo "❌ Application container not found or not running"
    echo "💡 RECOMMENDATION: Ensure application is deployed and healthy"
fi

echo ""
echo "Checking network latency..."

# Test network connectivity
APP_URL="${BASE_URL:-http://localhost:5000}"
HEALTH_CHECK_TIME=$(curl -o /dev/null -s -w "%{time_total}" "$APP_URL/health" 2>/dev/null || echo "999")

if (( $(echo "$HEALTH_CHECK_TIME > 0.1" | bc -l) )); then
    echo "⚠️  HIGH NETWORK LATENCY (${HEALTH_CHECK_TIME}s)"
    echo "💡 RECOMMENDATIONS:"
    echo "   1. Check network configuration between containers"
    echo "   2. Verify container network settings"
    echo "   3. Consider using host networking mode"
else
    echo "✅ Network latency acceptable (${HEALTH_CHECK_TIME}s)"
fi

echo ""
echo "Analyzing application logs for errors..."

# Check application logs for errors
if docker logs --since=1m "$CONTAINER_NAME" 2>&1 | grep -i "error\|exception\|timeout" | tail -5; then
    echo "⚠️  Recent errors found in application logs"
    echo "💡 RECOMMENDATION: Review application error handling and database queries"
else
    echo "✅ No recent errors in application logs"
fi

echo ""
echo "=== PERFORMANCE TUNING SUGGESTIONS ==="
echo ""
echo "1. APPLICATION LAYER:"
echo "   - Enable Flask response caching"
echo "   - Implement database connection pooling"
echo "   - Add asynchronous processing for non-critical operations"
echo "   - Optimize JSON serialization"
echo ""
echo "2. DATABASE LAYER:"
echo "   - Add composite indexes on (customer_id, created_at)"
echo "   - Implement database query result caching"
echo "   - Use prepared statements"
echo "   - Configure Oracle SGA parameters for better performance"
echo ""
echo "3. INFRASTRUCTURE LAYER:"
echo "   - Increase container CPU limits if CPU > 80%"
echo "   - Increase memory limits if memory > 80%"
echo "   - Use SSD storage for database files"
echo "   - Implement load balancing for horizontal scaling"
echo ""
echo "4. MONITORING:"
echo "   - Add APM (Application Performance Monitoring) tools"
echo "   - Implement database query profiling"
echo "   - Set up resource utilization alerts"
echo "   - Monitor garbage collection metrics"

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="