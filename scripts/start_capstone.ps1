# Khởi động toàn bộ capstone: 3 A2A specialists + ADK Web UI trên Windows PowerShell

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
Set-Location $ROOT

Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Day 26 Capstone — MCP + A2A Multi-Agent (Windows)" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Force -Path "logs" | Out-Null
}

function Start-Agent {
    param([string]$name, [int]$port)
    Write-Host "→ Khởi động $name trên port $port ..."
    
    # Check if port is in use and kill process
    $proc = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "⚠ Cổng $port đang được dùng — dừng process cũ..." -ForegroundColor Yellow
        Stop-Process -Id $proc.OwningProcess -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    # Start process in background
    $processOptions = @{
        FilePath = "python"
        ArgumentList = "-m", "uvicorn", "agents.${name}.agent:a2a_app", "--host", "localhost", "--port", "$port"
        RedirectStandardOutput = "logs\${name}.log"
        RedirectStandardError = "logs\${name}.err"
        WindowStyle = "Hidden"
    }
    $job = Start-Process @processOptions -PassThru
    $job.Id | Out-File -FilePath "logs\${name}.pid" -Encoding ASCII
}

Start-Agent -name "search_agent" -port 8001
Start-Agent -name "database_agent" -port 8002
Start-Agent -name "synthesis_agent" -port 8003

Write-Host "Đợi server khởi động (khoảng 3-5 giây)..."
Start-Sleep -Seconds 4

Write-Host ""
Write-Host "→ Khởi động ADK Web UI (orchestrator)..." -ForegroundColor Green
Write-Host "  Mở trình duyệt: http://localhost:8000" -ForegroundColor Yellow
Write-Host "  Để tắt các agent ngầm sau khi dùng xong, hãy đóng cửa sổ terminal này hoặc tìm và tắt các process python."
Write-Host "══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Find adk.exe path dynamically based on python path
$pythonPath = (Get-Command python).Source
$adkPath = Join-Path (Split-Path $pythonPath) "Scripts\adk.exe"

if (!(Test-Path $adkPath)) {
    # Sometimes it's in the same directory as python.exe on certain envs
    $adkPath = Join-Path (Split-Path $pythonPath) "adk.exe"
}

if (Test-Path $adkPath) {
    & $adkPath web agents/orchestrator
} else {
    Write-Host "Không tìm thấy file adk.exe trong thư mục Python Scripts." -ForegroundColor Red
}
