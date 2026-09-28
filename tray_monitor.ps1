Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
$script:notifyIcon.Text = "Hybrid Network Router (Discord RTC Protected)"
$script:notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$itemStatus = New-Object System.Windows.Forms.ToolStripMenuItem
$itemStatus.Text = "Status: Protecting Discord & Voice"
$itemStatus.Enabled = $false
$contextMenu.Items.Add($itemStatus) | Out-Null

$itemReload = New-Object System.Windows.Forms.ToolStripMenuItem
$itemReload.Text = "Reload Routes Now"
$itemReload.Add_Click({
    schtasks /run /tn "HybridNetworkRouter" | Out-Null
    $script:notifyIcon.ShowBalloonTip(2000, "Hybrid Router", "Routes re-checked and applied via Wi-Fi!", [System.Windows.Forms.ToolTipIcon]::Info)
})
$contextMenu.Items.Add($itemReload) | Out-Null

$itemLog = New-Object System.Windows.Forms.ToolStripMenuItem
$itemLog.Text = "View Activity Log"
$itemLog.Add_Click({
    Start-Process "notepad.exe" -ArgumentList "C:\Tools\HybridRouter\hybrid_router.log"
})
$contextMenu.Items.Add($itemLog) | Out-Null

$itemExit = New-Object System.Windows.Forms.ToolStripMenuItem
$itemExit.Text = "Exit Tray"
$itemExit.Add_Click({
    $script:notifyIcon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})
$contextMenu.Items.Add($itemExit) | Out-Null

$script:notifyIcon.ContextMenuStrip = $contextMenu

$script:notifyIcon.ShowBalloonTip(3000, "Hybrid Router Active", "LAN primary preserved. Blocked Discord traffic routed via Wi-Fi.", [System.Windows.Forms.ToolTipIcon]::Info)

[System.Windows.Forms.Application]::Run()
