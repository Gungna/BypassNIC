# DiscRoute

Dual-NIC split router for Windows. Keeps primary traffic on Ethernet while sending blocked apps (currently only bypasses Discord voice (WebRTC)) and media traffic over a secondary Wi-Fi connection.

## Problem

Campus and office firewalls frequently block outbound UDP or inspect WebRTC traffic, causing Discord voice channels to cycle endlessly through `Connecting -> RTC Connecting -> No Route`. 

Switching the entire laptop connection to a Wi-Fi hotspot fixes voice, but sacrifices LAN speeds for browsing, downloads, and low-latency internal services.

## Solution

DiscRoute dynamically splits traffic at the Windows IP routing layer:
1. **Ethernet stays default (`0.0.0.0/0`, Metric 35)**: All browser, download, and game traffic routes through LAN.
2. **Discord media routes via Wi-Fi (Metric 1)**: Subnets for Discord gateways (`162.159.128.0/21`, `162.159.136.0/21`), voice servers (`66.22.0.0/20`), and dynamic regional endpoints (`104.29.140-142.0/24`) are routed directly to the Wi-Fi gateway.
3. **Live voice detection**: The engine reads Discord client logs to identify newly assigned WebRTC media nodes and binds host routes immediately.
4. **Idle protection**: When Wi-Fi is disconnected, the daemon sleeps without consuming CPU or generating network calls.

## Installation

### 1-Click Install
1. Grab `DiscRoute-v1.0.0-Windows.zip` from [Releases](https://github.com/Hooligans-Jaringan-Lab-FTTH-PENS/DiscRoute/releases/latest).
2. Extract the archive.
3. Right-click `Install-DiscRoute.bat` and select **Run as administrator**.

The script registers a Scheduled Task (`DiscRouteService`) running with elevated rights at system startup, starts the daemon, and loads the system tray indicator.

### PowerShell Install
Run an elevated PowerShell prompt:
```powershell
irm https://raw.githubusercontent.com/Hooligans-Jaringan-Lab-FTTH-PENS/DiscRoute/main/install.ps1 | iex
```

## How It Routes

```
                          [ Windows Host ]
                                 |
                 +---------------+---------------+
                 |                               |
        Discord Voice / RTC               All Other Traffic
        (UDP / Media Ports)             (Web / HTTPS / LAN)
                 |                               |
                 v                               v
           [ Wi-Fi NIC ]                  [ Ethernet NIC ]
       Metric 1 Host Routes           Metric 35 Default Route
                 |                               |
                 v                               v
           Mobile Hotspot                   Campus LAN
```

## Verification

Check routes in PowerShell:
```powershell
Get-NetRoute -InterfaceAlias 'Wi-Fi' | Where-Object { $_.DestinationPrefix -like '162.159.*' -or $_.DestinationPrefix -like '104.29.*' }
```

Check default egress IP (should reflect LAN, not Wi-Fi):
```powershell
curl.exe -s https://ifconfig.me
```

## Uninstall
Right-click `Uninstall-DiscRoute.bat` and select **Run as administrator**. This removes the scheduled task, kills running background processes, and unregisters the startup entry.

## License
MIT - Created by Gungna.
