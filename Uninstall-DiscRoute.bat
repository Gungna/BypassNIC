@echo off
title DiscRoute Uninstaller
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

schtasks /delete /tn "DiscRouteService" /f >nul 2>&1
schtasks /delete /tn "HybridNetworkRouter" /f >nul 2>&1
taskkill /F /IM "HybridRouter.exe" >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "DiscRouteTray" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "HybridRouterTray" /f >nul 2>&1

echo DiscRoute successfully removed.
timeout /t 3 >nul
