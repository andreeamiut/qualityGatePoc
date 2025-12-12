# Project Structure Overview

```
qualityGatePOC/
├── app/                          # B2B Transaction Application
│   ├── app.py                    # Flask API with B2B transaction endpoints
│   ├── requirements.txt          # Python dependencies
│   └── Dockerfile               # Application container configuration
│
├── database/                     # Oracle Database Setup
│   └── init/                    # Database initialization scripts
│       ├── 00_user.sql          # User creation script
│       ├── 01_schema.sql        # Table schema (customers, transactions, audit)
│       └── 02_data.sql          # 210,000+ test records generation
│
├── performance/                  # JMeter Performance Testing
│   ├── txn_load_test.jmx        # JMeter test plan (50 users, 60s, P90<250ms)
│   ├── run_performance_test.sh   # Performance test executor
│   ├── analyze_results.py        # Performance results analyzer
│   └── diagnose_performance.sh   # Agentic diagnostic script
│
├── cicd/                        # CI/CD Pipeline Configuration
│   └── Jenkinsfile              # Complete pipeline with 4 validation stages
│
├── automation/                  # Autonomous Validation Agents
│   ├── run_regression_tests.sh  # SIT - API endpoint validation
│   ├── run_sql_validation.sh    # SQL Agent - Data integrity validation
│   ├── run_log_analysis.sh      # BASH Agent - Log parsing & analysis
│   ├── run_full_suite.sh        # Orchestrates all validation agents
│   └── generate_final_report.sh # Comprehensive reporting with recommendations
│
├── config/                      # Configuration Files
│   ├── prometheus.yml           # Monitoring configuration
│   └── grafana/                 # Grafana dashboards (if needed)
│
├── logs/                        # Application Log Directory
│   └── (portal.log generated here with TXN_ID tracking)
│
├── docker-compose.yml           # Complete service orchestration
├── Makefile                     # Convenience commands
├── README.md                    # Comprehensive documentation
├── quick-start.ps1              # Windows PowerShell quick start
└── PROJECT_STRUCTURE.md         # This file
```

## Key Features by Component

### Application Layer (`/app`)
- **Flask API**: B2B transaction processing with UUID-based TXN_IDs
- **Database Integration**: Oracle 19c with connection pooling
- **Structured Logging**: Transaction tracking to `/opt/app/logs/portal.log`
- **Resource Constraints**: 2 CPU, 4GB RAM limits for performance testing

### Database Layer (`/database`)
- **Schema**: 3 joined tables (customers, transactions, transaction_audit)
- **Data Volume**: 210,000+ records for realistic B2B testing
- **Referential Integrity**: Foreign key constraints across all tables
- **Performance Indexes**: Optimized for complex join queries

### Performance Testing (`/performance`)
- **JMeter Configuration**: 50 concurrent users, 60-second duration
- **Pass/Fail Criteria**: P90 response time < 250ms
- **Automated Analysis**: Python-based results parsing
- **Agentic Diagnostics**: Resource utilization analysis and scaling recommendations

### CI/CD Pipeline (`/cicd`)
- **Regression Stage**: API endpoint validation and functional testing
- **Performance Stage**: Load testing with automated pass/fail determination
- **SQL Agent Stage**: Data integrity validation across joined tables
- **BASH Agent Stage**: Log analysis and transaction pattern validation
- **Reporting Stage**: Comprehensive results with self-healing recommendations

### Autonomous Agents (`/automation`)
- **SQL Agent**: Validates referential integrity, business rules, query performance
- **BASH Agent**: Analyzes transaction logs, extracts TXN_IDs, calculates metrics
- **Performance Agent**: Orchestrates JMeter testing with auto-diagnosis
- **Reporting Agent**: Generates HTML/JSON reports with actionable recommendations

### Infrastructure (`docker-compose.yml`)
- **Service Orchestration**: App, Database, JMeter, Jenkins, Monitoring
- **Resource Management**: CPU and memory limits per container
- **Network Configuration**: Isolated container networking
- **Volume Management**: Persistent storage for logs and data
- **Health Checks**: Automated service health validation

## Agentic Capabilities

### Auto-Diagnosis Features
1. **Performance Bottleneck Detection**: CPU/Memory utilization analysis
2. **Database Performance Analysis**: Query execution time monitoring
3. **Error Pattern Recognition**: Log-based issue identification
4. **Resource Scaling Recommendations**: Automated infrastructure suggestions

### Self-Healing Recommendations
- **High CPU Usage**: "Increase CPU from 2 to 4 cores"
- **Memory Pressure**: "Increase memory limit from 4GB to 8GB"
- **Database Bottlenecks**: "Optimize queries and add connection pooling"
- **Network Issues**: "Check container network configuration"

### Validation Coverage
- **Functional**: API endpoints, transaction processing, error handling
- **Performance**: Response times, throughput, resource utilization
- **Data Integrity**: Referential consistency, business rule compliance
- **Operational**: Log quality, transaction tracking, error patterns

## Usage Profiles

### Development Profile
```bash
# Core services only
docker-compose up -d app oracle-db
```

### Testing Profile
```bash
# Add performance testing
docker-compose --profile performance up -d
```

### CI/CD Profile
```bash
# Full pipeline environment
docker-compose --profile cicd --profile automation up -d
```

### Monitoring Profile
```bash
# Add observability stack
docker-compose --profile monitoring up -d
```

This structure provides a complete, production-ready QA environment with autonomous validation capabilities and comprehensive reporting.