# DiscRoute (Hybrid Dual-NIC Discord Bypass)

> **Intelligent, lightweight split-routing engine for Windows 11/10.**
> Automatically routes blocked Discord voice (WebRTC) and media traffic through Wi-Fi while preserving your campus / office LAN (Ethernet) as the high-speed primary connection for everything else.

---

## ⚡ Features
- **100% Zero-Touch LAN Preservation**: Your default gateway remains pinned to your Ethernet connection (Metric 35). All web browsing, steam downloads, browser video streams, and general applications continue utilizing LAN bandwidth.
- **Dynamic RTC Voice Detection**: Monitors Discord voice connection attempts in real-time, detecting assigned regional voice servers (Singapore, US, EU, Hong Kong, etc.) and seamlessly tunneling UDP/TCP voice packets across Wi-Fi.
- **Subnet Pre-Seeding**: Discord signaling, gateway endpoints (`162.159.128.0/21`, `162.159.136.0/21`), and voice server clusters (`66.22.0.0/20`, `104.29.140-142.0/24`) are pre-routed with Metric 1 priority on Wi-Fi.
- **Resource Efficient**: Single-threaded, zero-CPU idle loop written in native Go with Windows GUI subsystem (no console window popups).
- **System Tray Guardian**: Runs quietly in your Windows system tray with balloon notifications and status controls.
- **Battery & Disconnect Safe**: If Wi-Fi disconnects or is turned off, the engine instantly enters low-power sleep without spamming routes or causing network lag.

---

## 🚀 1-Click Install (Windows 11)

### Option 1: Quick Install (Recommended)
1. Download the latest `DiscRoute.zip` from Releases.
2. Extract the folder anywhere (e.g., `C:\Tools\DiscRoute`).
3. Right-click **`Install-DiscRoute.bat`** and click **"Run as administrator"**.
4. **Done!** DiscRoute is now registered in Windows Task Scheduler to run with highest privileges automatically at startup and live in your System Tray.

### Option 2: 1-Line PowerShell Install
Open PowerShell as Administrator and run:
```powershell
irm https://raw.githubusercontent.com/agung-krisna/DiscRoute/main/install.ps1 | iex
```

---

## 🛠️ Architecture

```
                 +------------------------------+
                 |       Windows 11 PC          |
                 +------------------------------+
                           |          |
            Discord Voice  |          |  All Other Traffic
            (UDP/WebRTC)   |          |  (HTTP/HTTPS/Games)
                           v          v
                  [ Wi-Fi Adapter ]  [ Ethernet Adapter ]
                  Metric 1           Metric 35 (Default GW)
                         |                  |
                         v                  v
                   Mobile Hotspot     College / Campus LAN
                   (Unfiltered)       (High Bandwidth)
```

---

## 🗑️ Uninstallation
Right-click `Uninstall-DiscRoute.bat` and select **"Run as administrator"**. It will remove the Scheduled Task, delete the startup tray item, and stop all processes cleanly.

---

## 📄 License
MIT License. Created by Gung.
