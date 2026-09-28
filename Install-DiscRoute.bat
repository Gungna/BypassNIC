@echo off
title DiscRoute 1-Click Installer
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
