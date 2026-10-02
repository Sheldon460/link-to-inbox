#requires -Version 5.1
<#
  ssh-diag.ps1
  Diagnose "port 22 open but no SSH banner" on the UCloud Win11 VM.
  Distinguishes: (A) sshd broken  vs  (B) UCloud network layer dropping it.
  ASCII-only by design (RDP clipboard mangles non-ASCII).
  Output: %USERPROFILE%\Desktop\ssh-diag-result.txt
#>

$ErrorActionPreference = 'Continue'
$out = Join-Path $env:USERPROFILE 'Desktop\ssh-diag-result.txt'
$L = New-Object System.Collections.Generic.List[string]
function Sec($t){ $L.Add(''); $L.Add("=== $t ===") }
function W($t){ $L.Add([string]$t) }

Sec "RUN"
W ("Time     : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'))
W ("Computer : " + $env:COMPUTERNAME)

# ------------------------------------------------------------ 1. SERVICE
Sec "1. SERVICE STATE"
try {
    $svc = Get-Service sshd -ErrorAction Stop
    W ("Name          : " + $svc.Name)
    W ("Status        : " + $svc.Status)
    W ("StartType     : " + $svc.StartType)
} catch { W ("Get-Service failed: " + $_.Exception.Message) }

try {
    Restart-Service sshd -Force -ErrorAction Stop
    Start-Sleep -Seconds 3
    W ("Restart      : OK, now " + (Get-Service sshd).Status)
} catch { W ("Restart FAILED: " + $_.Exception.Message) }

# --------------------------------------------------------- 2. CONFIG TEST
Sec "2. CONFIG TEST  (sshd -t)"
W "No output below = config is fine."
W "Any line below = THIS IS THE ROOT CAUSE."
W "----------------------------------------"
$cfgPaths = @(
  "$env:ProgramData\ssh\sshd_config",
  "$env:ProgramData\ssh\sshd_config.d"
)
foreach ($p in $cfgPaths) {
    if (Test-Path $p) {
        W ("present: " + $p)
        if ((Get-Item $p).PSIsContainer) {
            Get-ChildItem $p -File | ForEach-Object { W ("  drop-in: " + $_.Name) }
        }
    } else {
        W ("MISSING: " + $p)
    }
}
W "----------------------------------------"
$sshdExe = "$env:WINDIR\System32\OpenSSH\sshd.exe"
W ("sshd.exe exists : " + (Test-Path $sshdExe))
if (Test-Path $sshdExe) {
    W ("sshd.exe version: " + (Get-Item $sshdExe).VersionInfo.ProductVersion)
    W "--- begin sshd -t output ---"
    $t = & $sshdExe -t 2>&1
    if ($t) { $t | ForEach-Object { W ("  >> " + $_) } } else { W "  (clean - no config errors)" }
    W "--- end sshd -t output ---"
}

# ------------------------------------------------------------ 3. LISTENING
Sec "3. LISTENING SOCKETS"
$l = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
     Where-Object { $_.LocalPort -in 22,3389,35389 }
if ($l) {
    $l | ForEach-Object { W ("  " + $_.LocalAddress + ":" + $_.LocalPort + "  pid=" + $_.OwningProcess) }
} else { W "  nothing listening on 22/3389/35389" }

$pid22 = ($l | Where-Object { $_.LocalPort -eq 22 } | Select-Object -First 1).OwningProcess
if ($pid22) {
    $p22 = Get-Process -Id $pid22 -ErrorAction SilentlyContinue
    W ("  port22 owner  : " + $p22.ProcessName + " (expected: sshd)")
    W ("  listening on ALL interfaces? -> " +
       [bool]($l | Where-Object { $_.LocalPort -eq 22 -and $_.LocalAddress -eq '0.0.0.0' }))
}

# -------------------------------------------- 4. LOCAL LOOPBACK TEST (KEY)
Sec "4. LOOPBACK TEST  (ssh to localhost:22)"
W "This separates sshd problems from UCloud network problems."
W "If localhost works but external fails -> UCloud/firewall is the culprit."
W "If localhost also fails -> sshd itself is broken."
W "----------------------------------------"
try {
    $job = Start-Job -ScriptBlock {
        $c = New-Object System.Net.Sockets.TcpClient
        $c.ReceiveTimeout = 8000; $c.SendTimeout = 8000
        $c.Connect('127.0.0.1', 22)
        $s = $c.GetStream()
        $buf = New-Object byte[] 256
        $n = $s.Read($buf, 0, 256)
        $banner = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
        $c.Close()
        $banner
    }
    $r = Receive-Job $job -Wait -Timeout 20
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    if ($r) { W ("  LOCAL BANNER OK: " + $r.Trim()) }
    else    { W "  LOCAL BANNER EMPTY -> sshd is not greeting. sshd is broken." }
} catch { W ("  loopback test error: " + $_.Exception.Message) }

Sec "5. HOST KEYS"
$hk = "$env:ProgramData\ssh"
if (Test-Path $hk) { Get-ChildItem $hk -Filter 'ssh_host_*' -ErrorAction SilentlyContinue |
                    ForEach-Object { W ("  " + $_.Name + "  " + $_.Length + " bytes") } }
else { W "  host key dir missing" }

# ---------------------------------------------------------------- 6. LOG
Sec "6. OPENSSH/Operational LOG (last 20)"
try {
    $ev = Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 20 -ErrorAction Stop
    if ($ev) { $ev | ForEach-Object { W ("[" + $_.TimeCreated + "] id=" + $_.Id + " " + ($_.Message -replace '\s+',' ')) } }
    else { W "  (log exists but is empty)" }
} catch { W ("  no log: " + $_.Exception.Message) }

Sec "7. SYSTEM LOG (sshd service events, last 10)"
try {
    Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='Service Control Manager'; StartTime=(Get-Date).AddHours(-6) } -MaxEvents 40 -ErrorAction Stop |
      Where-Object { $_.Message -match 'sshd|OpenSSH' } |
      Select-Object -First 10 | ForEach-Object { W ("[" + $_.TimeCreated + "] " + ($_.Message -replace '\s+',' ')) }
} catch { W ("  " + $_.Exception.Message) }

Sec "8. FIREWALL"
foreach ($n in 'sshd','OpenSSH-Server-In-TCP','OpenSSH-Server-In-TCP-SSHD') {
    $r = Get-NetFirewallRule -Name $n -ErrorAction SilentlyContinue
    if ($r) { W ("  rule " + $n + ": " + $r.Enabled + " / " + $r.Direction + " / " + $r.Action) }
}
W "  --- all enabled inbound rules mentioning 22 ---"
Get-NetFirewallRule -Enabled True -Direction Inbound -ErrorAction SilentlyContinue |
  ForEach-Object {
    $pf = $_ | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
    if ($pf -and ($pf.LocalPort -eq '22' -or $pf.LocalPort -eq 'Any')) {
      $af = $_ | Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue
      if ($pf.LocalPort -eq '22') { W ("  " + $_.DisplayName + "  remote=" + $af.RemoteAddress) }
    }
  }

$L | Set-Content -Path $out -Encoding UTF8
Write-Host ""
Write-Host "RESULT WRITTEN TO: $out"
