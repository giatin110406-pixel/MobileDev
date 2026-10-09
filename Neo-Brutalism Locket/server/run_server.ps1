# Starts the Locket stylize server on the LAN. Usage: .un_server.ps1
# Restarts automatically when the server exits with code 3 (CUDA fault); Ctrl+C stops it.
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = "1"
$env:PYTHONWARNINGS = "ignore"
do {
    & "$PSScriptRoot\.venv\Scripts\python.exe" -m uvicorn locket_server.api:app_factory --factory --host 0.0.0.0 --port 8765
} while ($LASTEXITCODE -eq 3)
