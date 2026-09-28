# Self-elevating 1-Click Installer for DiscRoute
# Requires Administrator privileges to configure Windows IP routes

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ""$PSCommandPath"""
    exit
}

$InstallDir = "C:\Tools\DiscRoute"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Installing DiscRoute Engine...      " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

$CurrentDir = Split-Path -Parent $PSCommandPath
if ($CurrentDir -ne $InstallDir) {
    Copy-Item -Path "$CurrentDir\*" -Destination $InstallDir -Recurse -Force
}

# Register Windows Scheduled Task with highest privileges
$action = New-ScheduledTaskAction -Execute "$InstallDir\HybridRouter.exe"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

Register-ScheduledTask -TaskName "DiscRouteService" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName "DiscRouteService" | Out-Null

# Register System Tray monitor to user startup
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "DiscRouteTray" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$InstallDir\tray_monitor.ps1"""

# Launch tray monitor immediately
Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ""$InstallDir\tray_monitor.ps1"""

Write-Host "[SUCCESS] DiscRoute is fully installed and running!" -ForegroundColor Green
Write-Host "Discord Voice & RTC traffic will now route via Wi-Fi." -ForegroundColor Cyan
Write-Host "Primary Internet traffic remains on your College LAN." -ForegroundColor Cyan
Start-Sleep -Seconds 3
