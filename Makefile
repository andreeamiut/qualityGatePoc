# QA Environment Quick Start Scripts

# Start core services (app + database)
start-core:
	docker-compose up -d app oracle-db

# Start with performance testing capability
start-performance:
	docker-compose --profile performance up -d

# Start full CI/CD environment
start-cicd:
	docker-compose --profile cicd --profile automation up -d

# Start monitoring stack
start-monitoring:
	docker-compose --profile monitoring up -d

# Start everything
start-all:
	docker-compose --profile performance --profile cicd --profile automation --profile monitoring up -d

# Stop all services
stop:
	docker-compose down --remove-orphans

# Clean environment (remove volumes)
clean:
	docker-compose down -v --remove-orphans
	docker system prune -f

# View logs
logs-app:
	docker-compose logs -f app

logs-db:
	docker-compose logs -f oracle-db

logs-all:
	docker-compose logs -f

# Health check
health:
	@echo "Checking service health..."
	@curl -f http://localhost:5000/health || echo "❌ App not healthy"
	@curl -f http://localhost:8080/login || echo "❌ Jenkins not accessible"
	@curl -f http://localhost:9090/-/healthy || echo "❌ Prometheus not healthy"

# Run performance tests
performance-test:
	docker-compose --profile performance exec jmeter /opt/performance/run_performance_test.sh

# Run full automation suite
run-automation:
	docker-compose --profile automation exec automation-agent /opt/automation/run_full_suite.sh

# Initialize database with test data
init-db:
	@echo "Initializing database with test data..."
	docker-compose exec oracle-db sqlplus b2b_user/b2b_password@//localhost:1521/ORCLPDB1 @/docker-entrypoint-initdb.d/01_schema.sql
	docker-compose exec oracle-db sqlplus b2b_user/b2b_password@//localhost:1521/ORCLPDB1 @/docker-entrypoint-initdb.d/02_data.sql

# Monitoring URLs
show-urls:
	@echo "=== Service URLs ==="
	@echo "Application: http://localhost:5000"
	@echo "Application Health: http://localhost:5000/health"
	@echo "Application Stats: http://localhost:5000/api/v1/stats"
	@echo "Jenkins: http://localhost:8080"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000 (admin/admin123)"
	@echo "Oracle DB: localhost:1521/ORCLPDB1"

.PHONY: start-core start-performance start-cicd start-monitoring start-all stop clean logs-app logs-db logs-all health performance-test run-automation init-db show-urls