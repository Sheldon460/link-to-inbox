#requires -Version 5.1
<#
  tailscale-status.ps1  (READ-ONLY, changes nothing)
  Checks whether this UCloud Win11 box can realistically be a Tailscale
  exit node: service state, direct-vs-DERP, UDP reachability, IP routing,
  and whether it is currently advertising / approved as an exit node.
  ASCII-only by design.
  Result: %USERPROFILE%\Desktop\tailscale-status.txt
#>

$ErrorActionPreference = 'Continue'
$out = Join-Path $env:USERPROFILE 'Desktop\tailscale-status.txt'
"" | Set-Content -Path $out -Encoding UTF8
function Sec($t){ Add-Content -Path $out -Value ""; Add-Content -Path $out -Value "=== $t ===" }
function W($t){ Add-Content -Path $out -Value ([string]$t) }

# locate tailscale CLI
$ts = $null
foreach ($c in @("$env:ProgramFiles\Tailscale\tailscale.exe",
                 "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe")) {
    if (Test-Path $c) { $ts = $c; break }
}
if (-not $ts) { $ts = (Get-Command tailscale.exe -ErrorAction SilentlyContinue).Source }

Sec "RUN"
W ("Time : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'))
W ("CLI  : " + $(if ($ts) { $ts } else { "NOT FOUND in common paths" }))

if (-not $ts) {
    W ""
    W "Tailscale CLI not found. Is the Tailscale client installed on this box?"
    Write-Host "RESULT_FILE = $out"
    return
}

Sec "1. VERSION"
& $ts version 2>&1 | ForEach-Object { W ("  " + $_) }

Sec "2. SERVICE STATE"
Get-Service Tailscale -ErrorAction SilentlyContinue | ForEach-Object {
    W ("  Tailscale service : " + $_.Status + " / " + $_.StartType)
}

Sec "3. STATUS (peers + direct vs relay)"
& $ts status 2>&1 | ForEach-Object { W ("  " + $_) }

Sec "4. NETCHECK (THE KEY ONE: UDP vs DERP)"
W "  UDP = true  -> direct P2P possible, speed can be good."
W "  UDP = false -> forced through overseas DERP relay, high latency, poor as an airport."
& $ts netcheck 2>&1 | ForEach-Object { W ("  " + $_) }

Sec "5. SELF / ROUTES (is it advertising exit node?)"
try {
    $j = (& $ts status --json 2>$null) | ConvertFrom-Json
    $self = $j.Self
    W ("  HostName        : " + ($self.HostName))
    W ("  Tailscale IP    : " + ($self.TailscaleIPs -join ', '))
    W ("  Online          : " + ($self.Online))
    W ("  PrimaryRoutes   : " + ($self.PrimaryRoutes -join ', '))
    W ("  AllowedIPs      : " + ($self.AllowedIPs -join ', '))
    $caps = $self.Capabilities
    if ($caps) { W ("  Capabilities    : " + ($caps -join ', ')) }
    if ($caps -contains 'https://tailscale.com/cap/exit-node') {
        W "  EXIT NODE       : advertised (still needs admin-console approval)"
    } else {
        W "  EXIT NODE       : NOT advertised"
    }
    W "  --- peers ---"
    $j.Peer.PSObject.Properties | ForEach-Object {
        $p = $_.Value
        W ("    " + $p.HostName + "  online=" + $p.Online + "  ip=" + ($p.TailscaleIPs -join ','))
    }
} catch { W ("  json parse error: " + $_.Exception.Message) }

Sec "6. WINDOWS IP FORWARDING (must be 1 to route as exit node)"
try {
    $r = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name IPEnableRouter -ErrorAction Stop
    W ("  IPEnableRouter registry = " + $r.IPEnableRouter + "   (1=enabled, 0=disabled; reboot required after change)")
} catch { W "  IPEnableRouter not set (defaults to 0 = disabled)" }

Sec "7. PUBLIC EGRESS IP (what the outside world sees)"
try {
    $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 15)
    W ("  This machine exits as : " + $ip)
} catch { W ("  could not fetch egress IP: " + $_.Exception.Message) }

Sec "VERDICT CHECKLIST"
W "  Look at section 4:"
W "    UDP=false + only DERP -> NOT a usable airport (overseas relay, slow)."
W "    UDP=true              -> could work; still mind the 4 GB RAM ceiling."
W "  Look at section 5: confirms whether exit node is advertised + approved."
W "  Look at section 6: IPEnableRouter must be 1 for Windows to route."

Write-Host ""
Write-Host "RESULT_FILE = $out"
