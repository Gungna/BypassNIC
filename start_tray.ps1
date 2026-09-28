# Kill old instances gracefully
Get-Process -Name "HybridRouter" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
}

# Start System Tray Monitor silently
Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ""C:\Tools\HybridRouter\tray_monitor.ps1"""
