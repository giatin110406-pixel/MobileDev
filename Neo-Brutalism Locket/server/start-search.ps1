# Starts AI search v2 on this laptop so the phone can reach it on the same Wi-Fi.
# Usage (from server/):  .\start-search.ps1
# Stop the Van Gogh server first: both need the 6 GB GPU.
$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
$set = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*(.+)$') { $set[$Matches[1]] = $Matches[2].Trim() }
}
$missing = @("SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY", "LOCKET_TOKEN") |
    Where-Object { -not $set.ContainsKey($_) }
if ($missing) {
    Write-Host "Missing in server/.env: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "See the comments at the end of server/.env."
    exit 1
}
if (-not $set.ContainsKey("LOCKET_SEARCH_TAG_OWNER")) {
    Write-Host "LOCKET_SEARCH_TAG_OWNER is not set: searching works, but new posts are not tagged." -ForegroundColor Yellow
}

# Let the phone in on port 8766 (asks for admin once; skipped when the rule exists).
$rule = "Locket AI search 8766"
if (-not (Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue)) {
    Write-Host "Adding firewall rule '$rule' (Windows will ask for admin)..."
    Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile", "-Command",
        "New-NetFirewallRule -DisplayName '$rule' -Direction Inbound -Protocol TCP -LocalPort 8766 -Action Allow -Profile Private"
}

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.PrefixOrigin -eq "Dhcp" -and $_.IPAddress -notlike "169.*" } |
    Select-Object -First 1).IPAddress
Write-Host ""
Write-Host "In the app: History > server icon > address  $ip`:8766  and the LOCKET_TOKEN from server/.env" -ForegroundColor Green
Write-Host "The first start loads the models (about a minute or two)."
Write-Host ""

$env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"
$env:PYTHONWARNINGS = "ignore"
& "$PSScriptRoot\.venv\Scripts\python.exe" -m uvicorn locket_server.api:search_app_factory --factory --host 0.0.0.0 --port 8766 --workers 1
