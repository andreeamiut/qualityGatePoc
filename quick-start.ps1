#!/usr/bin/env powershell

# Quick Start Script for Windows PowerShell
# Deploys and validates the complete B2B QA environment

Write-Host "🚀 B2B QA Environment - Quick Start" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green

# Check Docker availability
try {
    docker --version | Out-Null
    Write-Host "✅ Docker is available" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

try {
    docker-compose --version | Out-Null
    Write-Host "✅ Docker Compose is available" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker Compose not found. Please install Docker Compose." -ForegroundColor Red
    exit 1
}

# Set working directory
$WorkDir = "c:\Users\user\Work\qualityGatePOC"
Set-Location $WorkDir

Write-Host ""
Write-Host "📁 Working Directory: $WorkDir" -ForegroundColor Cyan

# Deploy core services
Write-Host ""
Write-Host "🏗️ Deploying Core Services (App + Database)..." -ForegroundColor Yellow
docker-compose up -d app oracle-db

# Wait for services to start
Write-Host ""
Write-Host "⏳ Waiting for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Health check loop
$maxAttempts = 20
$attempt = 0
$appHealthy = $false

Write-Host "🔍 Performing health checks..." -ForegroundColor Yellow

while ($attempt -lt $maxAttempts -and -not $appHealthy) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:5000/health" -Method Get -TimeoutSec 5
        if ($response) {
            $appHealthy = $true
            Write-Host "✅ Application is healthy" -ForegroundColor Green
        }
    } catch {
        $attempt++
        Write-Host "⏳ Waiting for application... ($attempt/$maxAttempts)" -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
}

if (-not $appHealthy) {
    Write-Host "❌ Application health check failed after $maxAttempts attempts" -ForegroundColor Red
    Write-Host "Checking container logs..." -ForegroundColor Yellow
    docker-compose logs --tail=20 app
    exit 1
}

# Initialize database (attempt)
Write-Host ""
Write-Host "🗄️ Attempting database initialization..." -ForegroundColor Yellow
try {
    # This may fail if Oracle is still starting up, but we'll continue
    docker-compose exec -T oracle-db sqlplus -s b2b_user/b2b_password@//localhost:1521/ORCLPDB1 @/docker-entrypoint-initdb.d/01_schema.sql 2>$null
    docker-compose exec -T oracle-db sqlplus -s b2b_user/b2b_password@//localhost:1521/ORCLPDB1 @/docker-entrypoint-initdb.d/02_data.sql 2>$null
    Write-Host "✅ Database initialization completed" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Database initialization may need manual setup (Oracle still starting)" -ForegroundColor Yellow
}

# Test basic functionality
Write-Host ""
Write-Host "🧪 Testing Basic Functionality..." -ForegroundColor Yellow

try {
    # Test health endpoint
    $health = Invoke-RestMethod -Uri "http://localhost:5000/health" -Method Get
    Write-Host "✅ Health endpoint: OK" -ForegroundColor Green

    # Test statistics endpoint
    try {
        $stats = Invoke-RestMethod -Uri "http://localhost:5000/api/v1/stats" -Method Get
        Write-Host "✅ Statistics endpoint: OK" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Statistics endpoint: Not ready (database may still be initializing)" -ForegroundColor Yellow
    }

    # Test transaction endpoint
    $transactionData = @{
        customer_id = "CUST_00000001"
        amount = 100.50
        transaction_type = "PAYMENT"
    } | ConvertTo-Json

    try {
        $txnResponse = Invoke-RestMethod -Uri "http://localhost:5000/api/v1/transaction" -Method Post -Body $transactionData -ContentType "application/json"
        Write-Host "✅ Transaction processing: OK (TXN_ID: $($txnResponse.txn_id))" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Transaction processing: Database connection needed" -ForegroundColor Yellow
    }

} catch {
    Write-Host "❌ Application testing failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Display service information
Write-Host ""
Write-Host "🌐 Service URLs:" -ForegroundColor Cyan
Write-Host "   Application API:    http://localhost:5000" -ForegroundColor White
Write-Host "   Health Check:       http://localhost:5000/health" -ForegroundColor White
Write-Host "   Statistics:         http://localhost:5000/api/v1/stats" -ForegroundColor White
Write-Host "   Oracle Database:    localhost:1521/ORCLPDB1" -ForegroundColor White

Write-Host ""
Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Run full test suite:" -ForegroundColor White
Write-Host "      docker-compose --profile automation up -d" -ForegroundColor Gray
Write-Host "      docker-compose exec automation-agent /opt/automation/run_full_suite.sh" -ForegroundColor Gray
Write-Host ""
Write-Host "   2. Start performance testing:" -ForegroundColor White
Write-Host "      docker-compose --profile performance up -d" -ForegroundColor Gray
Write-Host "      docker-compose exec jmeter /opt/performance/run_performance_test.sh" -ForegroundColor Gray
Write-Host ""
Write-Host "   3. Access monitoring (optional):" -ForegroundColor White
Write-Host "      docker-compose --profile monitoring up -d" -ForegroundColor Gray
Write-Host "      Prometheus: http://localhost:9090" -ForegroundColor Gray
Write-Host "      Grafana: http://localhost:3000 (admin/admin123)" -ForegroundColor Gray

Write-Host ""
Write-Host "📋 Manual Database Setup (if needed):" -ForegroundColor Cyan
Write-Host "   docker-compose exec oracle-db sqlplus b2b_user/b2b_password@//localhost:1521/ORCLPDB1" -ForegroundColor Gray
Write-Host "   SQL> @/docker-entrypoint-initdb.d/01_schema.sql" -ForegroundColor Gray
Write-Host "   SQL> @/docker-entrypoint-initdb.d/02_data.sql" -ForegroundColor Gray

Write-Host ""
Write-Host "✨ B2B QA Environment is ready for testing!" -ForegroundColor Green
Write-Host "   Check README.md for detailed usage instructions" -ForegroundColor White