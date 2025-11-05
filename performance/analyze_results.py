#!/usr/bin/env python3
"""
JMeter Results Analysis Script

This script analyzes JMeter performance test results from JTL files,
calculates key performance metrics, and validates against specified thresholds.
Supports success rate validation and response time percentile analysis.
"""

# Standard library imports
import csv  # For reading CSV/JTL files
import json  # For JSON output serialization
import argparse  # For command-line argument parsing
import statistics  # For statistical calculations
from datetime import datetime  # For timestamp handling

def parse_jtl_file(filepath):
    """Parse JMeter JTL (JUnit XML) results file and extract relevant transaction data."""
    results = []  # List to store parsed results

    with open(filepath, 'r', encoding='utf-8') as file:
        # Use CSV DictReader to parse the JTL file (CSV format)
        reader = csv.DictReader(file)  # Automatically handles header row

        for row in reader:
            # Only process rows for the main transaction label
            if row.get('label') == 'Process B2B Transaction':
                try:
                    # Extract and convert key metrics
                    elapsed = int(row.get('elapsed', 0))  # Response time in milliseconds
                    success = row.get('success', 'false').lower() == 'true'  # Convert to boolean
                    timestamp = int(row.get('timeStamp', 0))  # Unix timestamp

                    # Store parsed data for analysis
                    results.append({
                        'elapsed': elapsed,
                        'success': success,
                        'timestamp': timestamp,
                        'response_code': row.get('responseCode', ''),  # HTTP response code
                        'response_message': row.get('responseMessage', '')  # Response message
                    })
                except (ValueError, TypeError):
                    continue  # Skip malformed rows

    return results  # Return list of parsed transaction results

def calculate_percentiles(data):
    """Calculate key response time percentiles and statistics from a list of response times."""
    if not data:
        return {}  # Return empty dict if no data

    sorted_data = sorted(data)  # Sort data for percentile calculation
    length = len(sorted_data)

    # Calculate percentiles using indexing (simple percentile calculation)
    return {
        'p50': sorted_data[int(length * 0.50)] if length > 0 else 0,  # 50th percentile (median)
        'p90': sorted_data[int(length * 0.90)] if length > 0 else 0,  # 90th percentile
        'p95': sorted_data[int(length * 0.95)] if length > 0 else 0,  # 95th percentile
        'p99': sorted_data[int(length * 0.99)] if length > 0 else 0,  # 99th percentile
        'min': min(sorted_data),  # Minimum response time
        'max': max(sorted_data),  # Maximum response time
        'avg': statistics.mean(sorted_data)  # Average response time
    }

def analyze_results(results, threshold_ms):
    """Analyze performance test results and determine if they meet the specified thresholds."""

    if not results:
        return {
            'error': 'No valid results found',  # No data to analyze
            'passed': False
        }

    # Filter to only successful transactions for performance metrics
    successful_results = [r for r in results if r['success']]

    if not successful_results:
        return {
            'error': 'No successful transactions found',  # All transactions failed
            'passed': False,
            'total_requests': len(results),
            'success_rate': 0.0
        }

    # Extract response times from successful transactions only
    response_times = [r['elapsed'] for r in successful_results]

    # Calculate response time statistics
    percentiles = calculate_percentiles(response_times)

    # Calculate overall success rate
    success_rate = (len(successful_results) / len(results)) * 100

    # Determine if test passes: P90 within threshold AND success rate >= 95%
    p90_ms = percentiles.get('p90', 0)
    passed = p90_ms <= threshold_ms and success_rate >= 95.0

    # Calculate throughput (requests per second)
    if results:
        # Duration in seconds from first to last timestamp
        duration_sec = (max(r['timestamp'] for r in results) - min(r['timestamp'] for r in results)) / 1000
        throughput = len(successful_results) / duration_sec if duration_sec > 0 else 0
    else:
        throughput = 0

    # Analyze error patterns
    errors = [r for r in results if not r['success']]
    error_summary = {}
    for error in errors:
        code = error['response_code']
        if code in error_summary:
            error_summary[code] += 1  # Count occurrences of each error code
        else:
            error_summary[code] = 1

    # Return comprehensive analysis results
    return {
        'timestamp': datetime.now().isoformat(),  # Analysis timestamp
        'total_requests': len(results),  # Total number of requests
        'successful_requests': len(successful_results),  # Number of successful requests
        'failed_requests': len(errors),  # Number of failed requests
        'success_rate_percent': round(success_rate, 2),  # Success rate as percentage
        'response_times_ms': percentiles,  # Response time statistics
        'throughput_rps': round(throughput, 2),  # Throughput in requests per second
        'threshold_ms': threshold_ms,  # P90 threshold used
        'p90_within_threshold': p90_ms <= threshold_ms,  # P90 check result
        'success_rate_acceptable': success_rate >= 95.0,  # Success rate check result
        'passed': passed,  # Overall test result
        'error_summary': error_summary,  # Breakdown of error codes
        'test_verdict': 'PASSED' if passed else 'FAILED'  # Human-readable verdict
    }

def main():
    """Main entry point for the JMeter results analysis script."""
    # Set up command-line argument parser
    parser = argparse.ArgumentParser(description='Analyze JMeter performance test results')
    parser.add_argument('--results-file', required=True, help='Path to JTL results file')
    parser.add_argument('--threshold', type=int, required=True, help='P90 threshold in milliseconds')
    parser.add_argument('--output', required=True, help='Output JSON file path')

    args = parser.parse_args()  # Parse command-line arguments

    # Step 1: Parse the JTL results file
    print(f"Parsing results from: {args.results_file}")
    results = parse_jtl_file(args.results_file)

    # Step 2: Analyze the parsed results
    print(f"Analyzing {len(results)} results with P90 threshold: {args.threshold}ms")
    analysis = analyze_results(results, args.threshold)

    # Step 3: Save analysis results to JSON file
    with open(args.output, 'w', encoding='utf-8') as f:
        json.dump(analysis, f, indent=2)  # Pretty-print JSON with 2-space indentation

    # Step 4: Print human-readable summary to console
    print("\n=== PERFORMANCE TEST RESULTS ===")
    print(f"Total Requests: {analysis.get('total_requests', 0)}")
    print(f"Success Rate: {analysis.get('success_rate_percent', 0)}%")
    print(f"Throughput: {analysis.get('throughput_rps', 0)} RPS")

    # Print response time statistics if available
    if 'response_times_ms' in analysis:
        rt = analysis['response_times_ms']
        print("Response Times (ms):")
        print(f"  Min: {rt.get('min', 0)}")
        print(f"  Avg: {rt.get('avg', 0):.1f}")
        print(f"  P90: {rt.get('p90', 0)}")
        print(f"  P95: {rt.get('p95', 0)}")
        print(f"  P99: {rt.get('p99', 0)}")
        print(f"  Max: {rt.get('max', 0)}")

    print(f"P90 Threshold: {args.threshold}ms")
    print(f"Test Result: {analysis.get('test_verdict', 'UNKNOWN')}")

    # Print error summary if there were errors
    if analysis.get('error_summary'):
        print("Errors:")
        for code, count in analysis['error_summary'].items():
            print(f"  {code}: {count}")

    print("================================")

if __name__ == '__main__':
    main()