package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	defaultWifiAlias = "Wi-Fi"
	loopInterval     = 2 * time.Second
	logFileName      = "hybrid_router.log"
	cacheFileName    = "blocked_cache.txt"
)

var (
	wifiGateway    string
	blockedCache   sync.Map
	cachedRoutes   sync.Map
	discordSubnets = []string{
		"162.159.128.0/21", // Cloudflare / Discord Primary (Signaling, Gateways, Media)
		"162.159.136.0/21", // Discord Voice & Media Gateways
		"66.22.196.0/22",   // Discord Voice Infrastructure (Rotterdam, US, Asia)
		"66.22.200.0/22",   // Discord Voice Infrastructure
		"66.22.204.0/22",   // Discord Voice Infrastructure
		"66.22.208.0/20",   // Discord Core WebRTC
		"66.22.224.0/20",   // Discord Core WebRTC
		"104.29.141.0/24",  // Discord Singapore / Southeast Asia Media Voice Server Pool
		"104.29.140.0/24",  // Discord Regional Media Server Pool
		"104.29.142.0/24",  // Discord Regional Media Server Pool
	}
	logger *log.Logger
	logDir string
)

func loadBlockedCache() {
	cachePath := filepath.Join(logDir, cacheFileName)
	file, err := os.Open(cachePath)
	if err != nil {
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		ip := strings.TrimSpace(scanner.Text())
		if ip != "" && !strings.HasPrefix(ip, "#") {
			blockedCache.Store(ip, true)
		}
	}
	logger.Printf("Loaded persistent blocked cache from %s\n", cachePath)
}

func appendBlockedCache(ip string) {
	cachePath := filepath.Join(logDir, cacheFileName)
	f, err := os.OpenFile(cachePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.WriteString(ip + "\n")
}

func getWifiStatus(alias string) (bool, string) {
	cmd := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command",
		fmt.Sprintf(`$r = Get-NetRoute -InterfaceAlias '%s' -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object -First 1; if ($r) { $r.NextHop } else { "" }`, alias))
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	out, err := cmd.Output()
	if err != nil {
		return false, ""
	}
	gw := strings.TrimSpace(string(out))
	if gw == "" || gw == "0.0.0.0" {
		return false, ""
	}
	return true, gw
}

func addPrefixRoute(prefix, gateway, alias string) error {
	cmd := exec.Command("netsh", "interface", "ipv4", "add", "route",
		prefix, alias, gateway, "metric=1", "store=active")
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	return cmd.Run()
}

func ensureRoute(ipOrPrefix, alias, gw string) {
	if _, exists := cachedRoutes.Load(ipOrPrefix); exists {
		return
	}
	var prefix string
	if strings.Contains(ipOrPrefix, "/") {
		prefix = ipOrPrefix
	} else {
		prefix = ipOrPrefix + "/32"
	}

	err := addPrefixRoute(prefix, gw, alias)
	if err == nil {
		cachedRoutes.Store(ipOrPrefix, true)
		logger.Printf("[ROUTE-ACTIVE] Route %s -> Wi-Fi Gateway %s\n", prefix, gw)
	}
}

func applyDiscordSubnetRoutes(alias, gw string) {
	for _, subnet := range discordSubnets {
		ensureRoute(subnet, alias, gw)
	}
}

func inspectActiveDiscordMediaConnections(wifiAlias, gw string) {
	// Dynamically scan any active discord media server connections or renderer voice targets
	appData := os.Getenv("APPDATA")
	if appData == "" {
		return
	}
	logPath := filepath.Join(appData, "discord", "logs", "renderer_js.log")
	file, err := os.Open(logPath)
	if err != nil {
		return
	}
	defer file.Close()

	// Read last 64KB of log
	stat, err := file.Stat()
	if err != nil {
		return
	}
	offset := stat.Size() - 65536
	if offset < 0 {
		offset = 0
	}
	_, _ = file.Seek(offset, 0)

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, "Creating connection to") {
			// Format: "Creating connection to 104.29.141.217:19310"
			idx := strings.Index(line, "Creating connection to ")
			if idx != -1 {
				sub := line[idx+len("Creating connection to "):]
				parts := strings.Split(sub, " ")
				if len(parts) > 0 {
					hostPort := parts[0]
					host, _, err := net.SplitHostPort(hostPort)
					if err == nil && host != "" {
						if _, ok := blockedCache.Load(host); !ok {
							blockedCache.Store(host, true)
							appendBlockedCache(host)
							ensureRoute(host, wifiAlias, gw)
							logger.Printf("[DISCORD-VOICE-ENDPOINT-DETECTED] %s actively redirected to Wi-Fi\n", host)
						}
					}
				}
			}
		}
	}
}

func main() {
	exePath, err := os.Executable()
	if err != nil {
		logDir = "C:\\Tools\\HybridRouter"
	} else {
		logDir = filepath.Dir(exePath)
	}

	logFile, err := os.OpenFile(filepath.Join(logDir, logFileName), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err == nil {
		logger = log.New(logFile, "[HybridRouter] ", log.Ldate|log.Ltime|log.Lshortfile)
	} else {
		logger = log.New(os.Stdout, "[HybridRouter] ", log.Ldate|log.Ltime|log.Lshortfile)
	}

	logger.Println("Ultra-efficient Single-Engine Hybrid Router starting up...")
	loadBlockedCache()

	wifiAlias := defaultWifiAlias
	if len(os.Args) > 1 {
		wifiAlias = os.Args[1]
	}

	wasConnected := false

	for {
		hasWifi, gw := getWifiStatus(wifiAlias)
		if !hasWifi {
			if wasConnected {
				logger.Println("Wi-Fi disconnected. Entering ultra-low-power sleep until Wi-Fi re-establishes.")
				wasConnected = false
			}
			time.Sleep(10 * time.Second)
			continue
		}

		if !wasConnected || wifiGateway != gw {
			wifiGateway = gw
			wasConnected = true
			logger.Printf("Wi-Fi verified. Gateway: %s. Applying Discord Voice & Media Subnet routes...\n", wifiGateway)
			cachedRoutes = sync.Map{}
			applyDiscordSubnetRoutes(wifiAlias, wifiGateway)
		}

		// Replay blocked cached IPs
		blockedCache.Range(func(key, value interface{}) bool {
			ipStr := key.(string)
			ensureRoute(ipStr, wifiAlias, wifiGateway)
			return true
		})

		// Automatically inspect active Discord media servers in real-time
		inspectActiveDiscordMediaConnections(wifiAlias, wifiGateway)

		time.Sleep(loopInterval)
	}
}
