# 🚀 Full-Spectrum QA Environment

![QA Pipeline](https://img.shields.io/badge/QA%20Pipeline-Operational-brightgreen)
![Docker](https://img.shields.io/badge/Docker-Multi--Container-blue)
![Python](https://img.shields.io/badge/Python-3.9+-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13+-blue)
![Quality Score](https://img.shields.io/badge/Quality%20Score-80%2F100-brightgreen)
![Tests](https://img.shields.io/badge/Tests-30%2B%20Automated-brightgreen)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-4%20Workflows-blue)

> **🎯 Enterprise-Grade DevOps & Quality Assurance Platform**
> 
> Comprehensive Quality Assurance and DevOps automation platform designed for enterprise-grade B2B transaction processing systems with autonomous testing, performance monitoring, and CI/CD capabilities.

## 🌟 **What This Repository Delivers**

### 🚀 **Complete DevOps Ecosystem**
- **Multi-Container Architecture**: 6 orchestrated services (Flask API, PostgreSQL, Redis, Prometheus, Automation Agent)
- **Autonomous Testing Suite**: 30+ automated tests across 6 categories
- **CI/CD Pipeline**: GitHub Actions workflows for quality gates and deployment
- **Real-Time Monitoring**: Prometheus metrics and health monitoring
- **Production-Ready**: 80/100 quality score with enterprise standards

### 🎯 **Key Capabilities Demonstrated**
- ✅ **Autonomous Quality Assurance**: Self-healing test validation
- ✅ **Performance Benchmarking**: Response time <200ms, throughput 23-38 RPS
- ✅ **Database Operations**: PostgreSQL with 50k+ customer records
- ✅ **Multi-Instance Deployment**: Load-balanced Flask applications
- ✅ **Comprehensive Testing**: Regression, integration, performance, stress tests
- ✅ **GitHub Integration**: Complete CI/CD workflows ready for deployment

## 🏗️ Architecture

### Core Components
- **Flask API Application**: B2B transaction processing service
- **PostgreSQL Database**: 50,000+ records across 3 joined tables
- **JMeter Performance Testing**: 50 concurrent users, 250ms P90 threshold
- **Jenkins CI/CD Pipeline**: Automated validation stages
- **Autonomous Agents**: SQL Agent, BASH Agent, Performance Agent

### Resource Constraints
- **Application**: 2 CPU cores, 4GB RAM (configurable)
- **Database**: 2 CPU cores, 6GB RAM
- **Performance Testing**: Realistic B2B workload simulation

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- 16GB+ RAM recommended
- 4+ CPU cores recommended

### 1. Environment Setup
```powershell
# Clone and navigate to project
cd path/to/quality-gate-platform

# Start core services (app + database)
docker-compose up -d app postgres-db

# Wait for services to initialize (2-3 minutes)
docker-compose logs -f app
```

### 2. Initialize Database
```powershell
# Initialize database with test data
make init-db
# OR manually:
# docker-compose exec postgres-db sqlplus b2b_user/b2b_password@//localhost:5432/b2b_db @/docker-entrypoint-initdb.d/01_schema.sql
```

### 3. Verify Application
```powershell
# Check application health
curl http://localhost:5000/health

# View statistics
curl http://localhost:5000/api/v1/stats
```

## 🧪 Running Tests

### Full Automation Suite
```powershell
# Start automation environment
docker-compose --profile automation up -d

# Run complete validation pipeline
docker-compose exec automation-agent /opt/automation/run_full_suite.sh
```

### Individual Test Stages

#### Regression Tests (SIT)
```powershell
docker-compose exec automation-agent /opt/automation/run_regression_tests.sh
```

#### SQL Data Validation
```powershell
docker-compose exec automation-agent /opt/automation/run_sql_validation.sh
```

#### Log Analysis
```powershell
docker-compose exec automation-agent /opt/automation/run_log_analysis.sh
```

#### Performance Tests
```powershell
# Start performance testing
docker-compose --profile performance up -d jmeter

# Run JMeter tests
docker-compose exec jmeter /opt/performance/run_performance_test.sh
```

## 🔄 CI/CD Pipeline

### Jenkins Pipeline Stages
1. **Checkout & Setup**: Code retrieval and environment preparation
2. **Build & Deploy**: Container builds and service deployment
3. **Regression Testing**: API endpoint validation
4. **Performance Testing**: 50 concurrent users, 60 seconds
5. **SQL Agent**: Data integrity validation across 3 tables
6. **BASH Agent**: Log parsing and transaction analysis
7. **Validation & Reporting**: Comprehensive results with auto-diagnosis

### Starting CI/CD Environment
```powershell
# Start Jenkins and related services
docker-compose --profile cicd up -d

# Access Jenkins
# URL: http://localhost:8080
# Initial setup required
```

### Pipeline Configuration
- **Performance Pass Criteria**: P90 response time < 250ms
- **Agentic Self-Correction**: Automatic resource utilization analysis
- **Failure Handling**: Auto-diagnosis and scaling recommendations

## 🎛️ Monitoring & Observability

### Starting Monitoring Stack
```powershell
# Start Prometheus and Grafana
docker-compose --profile monitoring up -d
```

### Access Points
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin123)
- **Application Metrics**: http://localhost:5000/metrics

## 📊 Performance Testing Details

### JMeter Configuration
- **Test Plan**: `/performance/txn_load_test.jmx`
- **Concurrent Users**: 50 (configurable)
- **Test Duration**: 60 seconds
- **Ramp-up Time**: 10 seconds
- **Think Time**: 0.5-1.5 seconds random

### Performance Validation
- **P90 Threshold**: 250ms (configurable)
- **Success Rate**: ≥95% required
- **Auto-Diagnosis**: Resource utilization analysis on failure
- **Self-Healing**: Automatic scaling recommendations

### Agentic Performance Analysis
When performance tests fail (P90 > 250ms), the system automatically:
1. **Checks CPU utilization** of application container
2. **Analyzes memory consumption** patterns
3. **Suggests configuration changes** (e.g., "Increase CPU from 2 to 4 cores")
4. **Provides database optimization recommendations**
5. **Logs diagnostic information** for review

## 🗄️ Database Configuration

### PostgreSQL Database Details
- **Service**: ORCLPDB1
- **User**: b2b_user / b2b_password
- **Port**: 1521
- **Data Volume**: 50,000+ records
  - Customers: 50,000
  - Transactions: 80,000
  - Audit Records: 80,000

### Database Schema
```sql
-- Core tables with referential integrity
customers (customer_id, customer_name, company_name, balance, ...)
transactions (txn_id, customer_id, amount, transaction_type, status, ...)
transaction_audit (audit_id, txn_id, customer_id, old_balance, new_balance, ...)
```

### Complex Join Queries
The SQL Agent validates data integrity using complex queries across all 3 tables, ensuring referential integrity and business rule compliance.

## 🤖 Autonomous Agents

### SQL Agent (`run_sql_validation.sh`)
**Capabilities:**
- Data volume verification across all tables
- Referential integrity validation
- Business logic compliance (no negative balances)
- Complex join query performance testing
- Audit trail completeness verification

**Validations Performed:**
- Customer-Transaction integrity
- Transaction-Audit consistency  
- Balance calculation accuracy
- Query performance benchmarks

### BASH Agent (`run_log_analysis.sh`)
**Capabilities:**
- Transaction pattern analysis from `/opt/app/logs/portal.log`
- TXN_ID extraction and validation (UUID format)
- Processing time metrics calculation
- Error pattern detection and categorization
- Log format consistency validation

**Metrics Analyzed:**
- Transaction completion rates
- Average/P90/P99 processing times
- Error frequencies by category
- Transaction throughput patterns

### Performance Agent (`run_performance_test.sh`)
**Capabilities:**
- JMeter test orchestration
- Real-time performance monitoring
- P90 threshold validation
- Automatic failure diagnosis
- Resource utilization analysis

**Auto-Diagnosis Features:**
- CPU utilization assessment
- Memory consumption analysis
- Network latency validation
- Database performance correlation
- Infrastructure scaling recommendations

## 🔧 Configuration

### Environment Variables
```bash
# Application Configuration
BASE_URL=http://app:5000
DB_HOST=postgres-db
DB_USER=b2b_user
DB_PASSWORD=b2b_password

# Performance Testing
THREADS=50
DURATION=60
P90_THRESHOLD=250
SKIP_PERFORMANCE_TESTS=false

# Resource Limits
APP_CPU_LIMIT=2.0
APP_MEMORY_LIMIT=4g
DB_CPU_LIMIT=2.0
DB_MEMORY_LIMIT=6g
```

### Scaling Recommendations
The system provides automatic scaling recommendations based on resource utilization:

**High CPU (>80%)**:
```yaml
# Increase in docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '4.0'  # Increase from 2.0
```

**High Memory (>80%)**:
```yaml
# Increase in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 8G  # Increase from 4G
```

## 📈 Results & Reporting

### Automated Reports Generated
1. **Regression Test Results**: XML (Jenkins-compatible) + JSON summary
2. **SQL Validation Report**: Detailed integrity analysis
3. **Log Analysis Report**: Transaction patterns and error analysis  
4. **Performance Test Report**: HTML dashboard with metrics
5. **Final Comprehensive Report**: HTML + JSON with recommendations

### Agentic Self-Healing Output
```bash
=== AGENTIC SELF-HEALING ANALYSIS ===
CRITICAL: High CPU utilization detected (>80%) -> Increase CPU limit from 2 to 4 cores in docker-compose.yml
HIGH: P90 response time exceeds 250ms threshold -> Optimize database queries and implement connection pooling
MEDIUM: Elevated error rate in logs (15 errors) -> Implement better error handling and monitoring
```

### Report Locations
- **HTML Reports**: `automation/results/final_report.html`
- **JSON Summaries**: `automation/results/*_summary.json`
- **Performance Dashboard**: `performance/results/html_report/index.html`
- **Log Files**: `automation/results/*_$(date).log`

## 🛠️ Development & Customization

### Adding New Test Cases
1. **Regression Tests**: Modify `automation/run_regression_tests.sh`
2. **SQL Validations**: Add queries to `automation/run_sql_validation.sh`
3. **Performance Scenarios**: Update `performance/txn_load_test.jmx`

### Custom Validation Agents
Create new agent scripts following the pattern:
```bash
#!/bin/bash
# Custom Agent Template
set -e
RESULTS_DIR="$SCRIPT_DIR/results"
# ... validation logic ...
# Generate JSON summary for integration
```

### Pipeline Customization
Modify `cicd/Jenkinsfile` to:
- Add custom validation stages
- Integrate with external tools
- Customize notification systems
- Add deployment targets

## 🔍 Troubleshooting

### Common Issues

**Application Not Starting**:
```bash
# Check logs
docker-compose logs app
# Verify database connectivity
docker-compose exec app ping postgres-db
```

**Database Connection Failures**:
```bash
# Verify Oracle container status
docker-compose ps postgres-db
# Check database logs
docker-compose logs postgres-db
# Test connection manually
docker-compose exec postgres-db sqlplus b2b_user/b2b_password@//localhost:5432/b2b_db
```

**Performance Test Failures**:
```bash
# Check resource utilization
docker stats
# Review performance diagnostic output
cat performance/results/performance_summary.json
# Run diagnostic analysis
./performance/diagnose_performance.sh
```

### Health Check Commands
```bash
# Application health
curl http://localhost:5000/health

# Database connectivity  
docker-compose exec automation-agent ping postgres-db

# Service status
docker-compose ps

# Resource usage
docker stats --no-stream
```

## 📋 Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Application API | http://localhost:5000 | - |
| Application Health | http://localhost:5000/health | - |
| Application Stats | http://localhost:5000/api/v1/stats | - |
| Jenkins | http://localhost:8080 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin/admin123 |
| PostgreSQL DB | localhost:5432/b2b_db | b2b_user/b2b_password |

## 🎯 Success Criteria Validation

The environment successfully validates:

✅ **Deployment**: Resource-constrained application service (2 CPU, 4GB RAM)
✅ **Database Integration**: PostgreSQL 13 with 50,000+ records across 3 joined tables  
✅ **Performance Testing**: JMeter with 50 concurrent users, 250ms P90 threshold
✅ **CI/CD Pipeline**: Complete automation with 4 validation stages
✅ **Agentic Self-Correction**: Auto-diagnosis with scaling recommendations
✅ **Log Integration**: TXN_ID tracking to `/opt/app/logs/portal.log`
✅ **Complex SQL Validation**: Multi-table integrity checks
✅ **End-to-End Automation**: Full pipeline execution with comprehensive reporting

## 📧 Support & Maintenance

For issues or enhancements:
1. Check application and container logs
2. Review automated diagnostic reports
3. Consult the agentic recommendations in final reports
4. Use the built-in health checks and monitoring

This environment provides a complete, production-ready QA validation system with autonomous capabilities and self-healing recommendations.

---

## 👤 Author

**Andreea Miut**  
[![GitHub](https://img.shields.io/badge/GitHub-@andreeamiut-181717?logo=github)](https://github.com/andreeamiut)

---

<p align="center">Made for DevOps & QA Excellence</p>
