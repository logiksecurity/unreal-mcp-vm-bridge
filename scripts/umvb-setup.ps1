# umvb-setup.ps1
# One-shot setup for unreal-mcp-vm-bridge
# Run as Administrator on the HOST machine.

$Port     = 8000
$RuleName = "unreal-mcp VM bridge"

Write-Host ""
Write-Host "=== unreal-mcp-vm-bridge setup ===" -ForegroundColor Cyan
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

# --- Detect LAN IP (exclude virtual/unstable adapters) ---
$candidates = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -notmatch "VMware|VirtualBox|Hyper-V|WAN|Bluetooth|Loopback|Docker|Tailscale" -and
        $_.PrefixOrigin -ne "WellKnown"
    } |
    Sort-Object InterfaceAlias

if (-not $candidates) {
    Write-Host "[FAIL] No suitable LAN IP found." -ForegroundColor Red
    exit 1
}

if ($candidates.Count -eq 1) {
    $HostIP = $candidates[0].IPAddress
    Write-Host "[AUTO] Detected: $HostIP  ($($candidates[0].InterfaceAlias))" -ForegroundColor Green
} else {
    Write-Host "Multiple network adapters found:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host "  [$i] $($candidates[$i].IPAddress)  -  $($candidates[$i].InterfaceAlias)"
    }
    $idx = Read-Host "`nSelect adapter index"
    if ($idx -notin 0..($candidates.Count - 1)) {
        Write-Host "Invalid selection." -ForegroundColor Red
        exit 1
    }
    $HostIP = $candidates[$idx].IPAddress
}

Write-Host ""
$confirm = Read-Host "Use $HostIP ? (Y/n)"
if ($confirm -match '^n') {
    $HostIP = Read-Host "Enter host IP manually"
    if (-not (Test-IPv4Address $HostIP)) {
        Write-Host "[FAIL] Invalid IPv4 address." -ForegroundColor Red
        exit 1
    }
}

# --- Allowed source(s) to scope the firewall rule (defense in depth) ---
# Accepts a single VM IP, a range (a-b), a subnet (CIDR), or a comma-separated list.
# Character guard blocks spaces and other tokens to prevent netsh argument injection.
# netsh validates the actual address semantics, the exit code is checked below.
Write-Host ""
Write-Host "Allowed source(s) for the firewall rule:"
Write-Host "  single IP (192.168.1.50), range (192.168.1.10-192.168.1.50),"
Write-Host "  subnet (192.168.1.0/24), or comma-separated list."
$AllowedScope = Read-Host "Enter allowed source(s) (leave blank to allow the whole LAN)"
if ($AllowedScope) {
    if ($AllowedScope -notmatch '^[0-9./,\-]+$') {
        Write-Host "[FAIL] Invalid characters. Use IPs, ranges, CIDR and commas only." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[WARN] Firewall rule will allow connections from any host on the LAN." -ForegroundColor Yellow
    Write-Host "       The unreal-mcp server has no authentication. Scope it if possible." -ForegroundColor Yellow
}

Write-Host ""

# --- Remove existing rules (idempotent reruns) ---
Write-Host "Cleaning up old rules..."
netsh interface portproxy delete v4tov4 listenaddress=$HostIP listenport=$Port | Out-Null
netsh advfirewall firewall delete rule name="$RuleName" | Out-Null

Write-Host "[1/2] Adding portproxy rule ($HostIP`:$Port -> 127.0.0.1:$Port)..."
netsh interface portproxy add v4tov4 listenaddress=$HostIP listenport=$Port connectaddress=127.0.0.1 connectport=$Port
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Failed to add portproxy rule." -ForegroundColor Red
    exit 1
}
Write-Host "      OK" -ForegroundColor Green

Write-Host "[2/2] Adding firewall rule..."
if ($AllowedScope) {
    netsh advfirewall firewall add rule name="$RuleName" dir=in action=allow protocol=TCP localport=$Port remoteip=$AllowedScope
} else {
    netsh advfirewall firewall add rule name="$RuleName" dir=in action=allow protocol=TCP localport=$Port
}
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Failed to add firewall rule." -ForegroundColor Red
    exit 1
}
Write-Host "      OK" -ForegroundColor Green

Write-Host ""
Write-Host "=== Verification ===" -ForegroundColor Cyan

$proxyOk = netsh interface portproxy show v4tov4 | Select-String -SimpleMatch -Quiet $HostIP
$fwOk    = [bool](Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $true })

if ($proxyOk) { Write-Host "[OK] Portproxy rule active." -ForegroundColor Green }
else          { Write-Host "[FAIL] Portproxy rule not found." -ForegroundColor Red }

if ($fwOk)   { Write-Host "[OK] Firewall rule active." -ForegroundColor Green }
else         { Write-Host "[FAIL] Firewall rule issue." -ForegroundColor Red }

Write-Host ""
Write-Host "Setup finished." -ForegroundColor Green
Write-Host "Use this address in your VM .mcp.json:"
Write-Host "    http://$HostIP`:$Port/mcp" -ForegroundColor Yellow
Write-Host ""
Write-Host "Restart Claude Code in the VM after updating .mcp.json."
Write-Host ""
