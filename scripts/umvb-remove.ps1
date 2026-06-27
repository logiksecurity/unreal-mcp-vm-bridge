# umvb-remove.ps1
# Removes the portproxy rule and firewall rule created by umvb-setup.ps1.
# Run as Administrator on the HOST machine.

$Port     = 8000
$RuleName = "unreal-mcp VM bridge"

Write-Host ""
Write-Host "=== unreal-mcp-vm-bridge cleanup ===" -ForegroundColor Cyan
Write-Host ""

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[FAIL] Please run this script as Administrator." -ForegroundColor Red
    exit 1
}

# Strict IPv4 validation for manually entered addresses
function Test-IPv4Address {
    param([string]$Value)
    if ($Value -notmatch '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$') { return $false }
    foreach ($octet in $Matches[1..4]) {
        if ([int]$octet -gt 255) { return $false }
    }
    return $true
}

$HostIP = Read-Host "Enter the host IP used during setup (e.g. 192.168.x.x)"
if (-not (Test-IPv4Address $HostIP)) {
    Write-Host "[FAIL] Invalid IPv4 address." -ForegroundColor Red
    exit 1
}

Write-Host ""

Write-Host "[1/2] Removing portproxy rule..."
netsh interface portproxy delete v4tov4 listenaddress=$HostIP listenport=$Port | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "      OK" -ForegroundColor Green
} else {
    Write-Host "      WARN - rule may not have existed." -ForegroundColor Yellow
}

Write-Host "[2/2] Removing firewall rule..."
netsh advfirewall firewall delete rule name="$RuleName" | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "      OK" -ForegroundColor Green
} else {
    Write-Host "      WARN - rule may not have existed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan

$proxyGone = -not (netsh interface portproxy show v4tov4 | Select-String -SimpleMatch -Quiet $HostIP)
$fwGone    = -not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)

if ($proxyGone) { Write-Host "[OK] Portproxy rule removed." -ForegroundColor Green }
else            { Write-Host "[WARN] Portproxy rule still present." -ForegroundColor Yellow }

if ($fwGone)   { Write-Host "[OK] Firewall rule removed." -ForegroundColor Green }
else           { Write-Host "[WARN] Firewall rule still present." -ForegroundColor Yellow }

Write-Host ""
Write-Host "Cleanup finished." -ForegroundColor Green
Write-Host ""
