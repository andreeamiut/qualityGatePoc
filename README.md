# Quality Gate PoC

[![Full-Spectrum QA Pipeline](https://github.com/andreeamiut/qualityGatePoc/actions/workflows/full-spectrum-qa.yml/badge.svg)](https://github.com/andreeamiut/qualityGatePoc/actions/workflows/full-spectrum-qa.yml)

A proof of concept for an automated **quality gate** around a containerised B2B transaction API:
functional, data-integrity, log and performance checks run against the whole stack in Docker,
and a pipeline decides pass/fail from the results.

## What this demonstrates

- **API regression tests** for a Flask transaction service (`/health`, `/api/v1/transaction`, `/api/v1/stats`)
- **SQL data validation** – row counts, referential integrity and business rules (e.g. no negative balances) across 3 joined PostgreSQL tables
- **Log analysis** – transaction IDs, processing times (avg / P90 / P99) and error patterns parsed from the application log
- **Performance testing** – JMeter, 50 concurrent users, pass criterion P90 < 250 ms
- **Failure diagnosis** – when the performance gate fails, a script checks container CPU / memory and prints tuning suggestions
- **CI/CD** – GitHub Actions pipeline (code quality, build, test matrix, pipeline validation); an equivalent `Jenkinsfile` is included
- **Observability** – optional Prometheus + Grafana stack (`monitoring` profile)

## Architecture

| Service | Image | Port | Profile |
|---|---|---|---|
| `app`, `app-2` | Flask API (`./app`) | 5000, 5001 | default |
| `postgres-db` | postgres:13 | 5432 | default |
| `redis` | redis:7-alpine | 6379 | default |
| `jmeter` | justb4/jmeter | – | `performance` |
| `automation-agent` | python:3.9-slim | – | `automation` |
| `jenkins` | jenkins/jenkins:lts | 8080 | `cicd` |
| `prometheus`, `grafana` | prom / grafana | 9090, 3000 | `monitoring` |

The database is seeded automatically on first start from `database/postgres/`
(50,000 customers plus transactions and audit records).

## Quick start

Requires Docker with Docker Compose. 8 GB+ RAM recommended for the full stack.

```bash
docker compose up -d              # app, app-2, postgres-db, redis
curl http://localhost:5000/health
curl http://localhost:5000/api/v1/stats
```

## Running the checks

```bash
docker compose --profile automation up -d
docker compose exec automation-agent /opt/automation/run_full_suite.sh

# individual stages
docker compose exec automation-agent /opt/automation/run_regression_tests.sh
docker compose exec automation-agent /opt/automation/run_sql_validation.sh
docker compose exec automation-agent /opt/automation/run_log_analysis.sh

# performance
docker compose --profile performance up -d jmeter
docker compose exec jmeter /opt/performance/run_performance_test.sh
```

Performance settings can be overridden with environment variables: `THREADS` (default 50),
`DURATION` (60 s), `P90_THRESHOLD` (250 ms).

Results are written to `automation/results/` (JUnit XML, JSON summaries and an HTML report)
and `performance/results/`.

## CI/CD

- **GitHub Actions** – `.github/workflows/full-spectrum-qa.yml` runs on push, PR and nightly:
  code quality & security scan → build & infrastructure test → test matrix → pipeline validation.
  `pr-validation.yml` runs a lighter check on pull requests.
- **Jenkins** – `cicd/Jenkinsfile` runs regression, performance, SQL and log-analysis stages; start Jenkins locally with
  `docker compose --profile cicd up -d`.

## Notes

- Credentials in `docker-compose.yml` are local demo defaults only. Change them before using this anywhere else.
- This is a portfolio proof of concept, not a production system.

## Author

Andreea Miut
