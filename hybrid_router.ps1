# Hybrid Router PowerShell Guardian
# Runs invisibly, checks Wi-Fi connectivity, routes blocked Discord/voice traffic to Wi-Fi, leaves LAN as primary.

param(
    [string]$WifiAlias = "Wi-Fi",
    [int]$CheckIntervalSeconds = 5
)

$ErrorActionPreference = "SilentlyContinue"

# Log location
$LogPath = "C:\Tools\HybridRouter\hybrid_router.log"
function Write-Log($msg) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "[$timestamp] $msg" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

Write-Log "Hybrid Router PowerShell Engine initialized."

$DiscordDomains = @(
    "discord.com",
    "gateway.discord.gg",
    "cdn.discordapp.com",
    "discordapp.com",
    "discord.gg",
    "discord.media",
    "status.discord.com",
    "latency.discord.media"
)

# Expand voice servers
$regions = @("rotterdam", "singapore", "sydney", "us-east", "us-central", "us-west", "us-south", "japan", "hongkong")
foreach ($r in $regions) {
    for ($i = 1; $i -le 30; $i++) {
        $DiscordDomains += "$r$i.discord.gg"
        $DiscordDomains += "$r$i.discord.media"
    }
}

$RoutedIPs = @{}
$BlockedIPs = @{}

function Test-TCPPort($ip, $port, $timeoutMs = 800) {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($ip, $port, $null, $null)
        $success = $iar.AsyncWaitHandle.WaitOne($timeoutMs, $false)
        if (-not $success) {
            $client.Close()
            return $false
        }
        $client.EndConnect($iar)
        $client.Close()
        return $true
    } catch {
        return $false
    }
}

while ($true) {
    # Check if Wi-Fi has active default gateway
    $wifiRoute = Get-NetRoute -InterfaceAlias $WifiAlias -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $wifiRoute -or [string]::IsNullOrWhiteSpace($wifiRoute.NextHop) -or $wifiRoute.NextHop -eq "0.0.0.0") {
        # Wi-Fi disconnected or no gateway; sleep 10s without doing any DNS queries or adding routes
        Start-Sleep -Seconds 10
        continue
    }

    $wifiGateway = $wifiRoute.NextHop

    # Inspect domain IPs
    foreach ($domain in $DiscordDomains) {
        try {
            $entry = [System.Net.Dns]::GetHostEntry($domain)
            foreach ($addr in $entry.AddressList) {
                if ($addr.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
                    continue
                }
                $ipStr = $addr.IPAddressToString

                if ($RoutedIPs.ContainsKey($ipStr)) {
                    continue
                }

                if ($BlockedIPs.ContainsKey($ipStr)) {
                    # Add route to Wi-Fi
                    route.exe add "$ipStr" mask 255.255.255.255 "$wifiGateway" metric 1 | Out-Null
                    $RoutedIPs[$ipStr] = $true
                    Write-Log "[REDIRECTED] $ipStr ($domain) routed to Wi-Fi ($wifiGateway)"
                    continue
                }

                # Probe through LAN
                $open = Test-TCPPort $ipStr 443 750
                if (-not $open) {
                    $BlockedIPs[$ipStr] = $true
                    route.exe add "$ipStr" mask 255.255.255.255 "$wifiGateway" metric 1 | Out-Null
                    $RoutedIPs[$ipStr] = $true
                    Write-Log "[BLOCKED-DETECTED] $ipStr ($domain) blocked on LAN -> Redirected to Wi-Fi ($wifiGateway)"
                }
            }
        } catch {
            # DNS resolution failed or temporary glitch, ignore
        }
    }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
