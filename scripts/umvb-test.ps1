# umvb-test.ps1
# Tests connectivity from this VM to the unreal-mcp server on the host.
# Usage: .\umvb-test.ps1 [-HostIP <ip>] [-Port <port>]

param(
    [string]$HostIP = "",
    [int]$Port = 8000
)

if (-not $HostIP) {
    $HostIP = Read-Host "Enter host IP (the machine running Unreal Editor)"
}

$url = "http://${HostIP}:${Port}/mcp"

Write-Host ""
Write-Host "=== unreal-mcp connection test ===" -ForegroundColor Cyan
Write-Host "Target: $url"
Write-Host ""

Write-Host "[1/3] TCP reachability..."
$tcp = Test-NetConnection -ComputerName $HostIP -Port $Port -WarningAction SilentlyContinue
if ($tcp.TcpTestSucceeded) {
    Write-Host "      OK - port $Port is open on $HostIP" -ForegroundColor Green
} else {
    Write-Host "      FAIL - cannot reach $HostIP on port $Port" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check:"
    Write-Host "  - portproxy rule:  netsh interface portproxy show v4tov4"
    Write-Host "  - firewall rule:   netsh advfirewall firewall show rule name=""unreal-mcp VM bridge"""
    Write-Host "  - Unreal Editor is open with unreal-mcp plugin active"
    exit 1
}

Write-Host "[2/3] HTTP GET $url ..."
try {
    $response = Invoke-WebRequest -Uri $url -TimeoutSec 5 -UseBasicParsing
    $status = $response.StatusCode
    $body   = $response.Content
    Write-Host "      OK - HTTP $status" -ForegroundColor Green
    if ($body) { Write-Host "      Body: $body" }
} catch [System.Net.WebException] {
    $status = [int]$_.Exception.Response.StatusCode
    if ($status -eq 405) {
        Write-Host "      OK - HTTP 405 (server is up, MCP requires POST not GET)" -ForegroundColor Green
    } else {
        Write-Host "      FAIL - HTTP $status : $($_.Exception.Message)" -ForegroundColor Red
    }
} catch {
    Write-Host "      FAIL - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "[3/3] curl.exe check..."
$curlPath = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
if ($curlPath) {
    & curl.exe -s -o NUL -w "      HTTP status: %{http_code}`n      Time total: %{time_total}s`n" --connect-timeout 5 $url
} else {
    Write-Host "      curl.exe not found - skipping" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ""
