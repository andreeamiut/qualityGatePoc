#!/bin/bash
echo "=== PERFORMANCE LOAD TESTING ==="
echo "Simulating 50 concurrent API requests to validate P90 < 250ms requirement"
echo ""

APP_HOST="qualitygatepoc-app-1:5000"
CONCURRENT_REQUESTS=50
TOTAL_REQUESTS=500

echo "Target: $APP_HOST"
echo "Concurrent Users: $CONCURRENT_REQUESTS"
echo "Total Requests: $TOTAL_REQUESTS"
echo "P90 Threshold: < 250ms"
echo ""

# Create results directory
mkdir -p /opt/results

# Test /health endpoint performance
echo "🔄 Testing /health endpoint performance..."
start_time=$(date +%s)

for i in $(seq 1 $TOTAL_REQUESTS); do
    {
        response_time=$(curl -w "%{time_total}" -s -o /dev/null http://$APP_HOST/health)
        echo "$response_time" >> /opt/results/health_times.txt
    } &
    
    # Limit concurrent requests
    if (( i % CONCURRENT_REQUESTS == 0 )); then
        wait
    fi
done
wait

end_time=$(date +%s)
duration=$((end_time - start_time))

# Calculate statistics
if [ -f /opt/results/health_times.txt ]; then
    # Convert to milliseconds and sort
    awk '{print $1 * 1000}' /opt/results/health_times.txt | sort -n > /opt/results/health_times_ms.txt
    
    total_requests=$(wc -l < /opt/results/health_times_ms.txt)
    avg_time=$(awk '{sum+=$1} END {print sum/NR}' /opt/results/health_times_ms.txt)
    p90_index=$(echo "($total_requests * 0.9 + 0.5)" | bc | cut -d. -f1)
    p90_time=$(sed -n "${p90_index}p" /opt/results/health_times_ms.txt)
    min_time=$(head -1 /opt/results/health_times_ms.txt)
    max_time=$(tail -1 /opt/results/health_times_ms.txt)
    
    echo ""
    echo "=== PERFORMANCE RESULTS ==="
    echo "Total Duration: ${duration}s"
    echo "Total Requests: $total_requests"
    echo "Requests/Second: $(echo "scale=2; $total_requests / $duration" | bc)"
    echo "Average Response Time: $(echo "scale=2; $avg_time" | bc)ms"
    echo "Min Response Time: ${min_time}ms"
    echo "Max Response Time: ${max_time}ms"
    echo "P90 Response Time: ${p90_time}ms"
    
    # Validate P90 requirement
    if (( $(echo "$p90_time < 250" | bc -l) )); then
        echo "✅ P90 Performance: SUCCESS (${p90_time}ms < 250ms)"
        echo "✅ Load Test: PASSED"
    else
        echo "❌ P90 Performance: FAILED (${p90_time}ms >= 250ms)"
        echo "❌ Load Test: FAILED"
    fi
    
    echo ""
    echo "🎯 PERFORMANCE TESTING COMPLETE"
else
    echo "❌ No performance data collected"
fi