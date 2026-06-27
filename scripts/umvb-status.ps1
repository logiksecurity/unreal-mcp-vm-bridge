# umvb-status.ps1
# Read-only check of the portproxy and firewall rules.
# Run as Administrator on the HOST machine.

$Port     = 8000
$RuleName = "unreal-mcp VM bridge"

Write-Host ""
Write-Host "=== unreal-mcp-vm-bridge status ===" -ForegroundColor Cyan
Write-Host ""

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[FAIL] Please run this script as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Portproxy rules (port $Port):"
$proxyLines = netsh interface portproxy show v4tov4 | Select-String $Port
if ($proxyLines) {
    $proxyLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
} else {
    Write-Host "  none found." -ForegroundColor Yellow
}

Write-Host ""

Write-Host "Firewall rule ($RuleName):"
$fwRule    = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
$fwEnabled = $fwRule -and ($fwRule.Enabled -eq $true)
$fwExists  = [bool]$fwRule

if ($fwEnabled) {
    Write-Host "  [OK] Rule exists and is enabled." -ForegroundColor Green
} elseif ($fwExists) {
    Write-Host "  [WARN] Rule exists but is disabled." -ForegroundColor Yellow
} else {
    Write-Host "  [FAIL] Rule not found." -ForegroundColor Red
}

Write-Host ""
Write-Host "To reconfigure: run umvb-setup.ps1" -ForegroundColor White
Write-Host "To remove:      run umvb-remove.ps1" -ForegroundColor White
Write-Host ""
