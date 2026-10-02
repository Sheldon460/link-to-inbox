#requires -Version 5.1
<#
  ssh-watchdog.ps1
  For the RECURRING sshd death pattern (works, then dies, needs manual restart).
  NOT a config rewriter. Three jobs:
    A. Collect crash evidence (Application + System + OpenSSH/Operational logs,
       memory pressure, service recovery config)
    B. Set service recovery so Windows auto-restarts sshd on crash
    C. Install a 5-minute scheduled-task watchdog that probes loopback banner
       and restarts sshd if it stops greeting
  Output is written straight to a file (no in-memory collection) so it is
  immune to collection-type corruption.
  ASCII-only by design.
  Result: %USERPROFILE%\Desktop\ssh-watchdog-result.txt
#>

$ErrorActionPreference = 'Continue'
$out = Join-Path $env:USERPROFILE 'Desktop\ssh-watchdog-result.txt'
"" | Set-Content -Path $out -Encoding UTF8

function Sec($t){ Add-Content -Path $out -Value ""; Add-Content -Path $out -Value "=== $t ===" }
function W($t){ Add-Content -Path $out -Value ([string]$t) }

$prog    = "$env:WINDIR\System32\OpenSSH"
$keydir  = "$env:ProgramData\ssh"
$wdPs1   = "$keydir\wd.ps1"
$wdLog   = "$keydir\watchdog.log"
$taskName= 'sshd-watchdog'

Sec "RUN"
W ("Time     : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'))
W ("Computer : " + $env:COMPUTERNAME)

# ------------------------------------------- A1. CURRENT STATE
Sec "A1. CURRENT STATE"
try {
    $s = Get-Service sshd -ErrorAction Stop
    W ("  sshd service : " + $s.Status + " / " + $s.StartType)
} catch { W ("  sshd service : NOT FOUND") }
$l = Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction SilentlyContinue
if ($l) {
    $l | ForEach-Object { W ("  listening    : $($_.LocalAddress):$($_.LocalPort)  pid=$($_.OwningProcess)") }
    $p = Get-Process -Id $l[0].OwningProcess -ErrorAction SilentlyContinue
    if ($p) { W ("  process      : " + $p.ProcessName + "  started=" + $p.StartTime) }
} else { W "  listening    : NOTHING on 22" }

$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
$freeGB  = [math]::Round($os.FreePhysicalMemory/1MB, 2)
$usedPct = [math]::Round(100 - ($freeGB / $totalGB * 100), 1)
W ("  memory       : total ${totalGB} GB, free ${freeGB} GB, used ${usedPct}%")
if ($usedPct -gt 90) { W "  !! MEMORY PRESSURE HIGH - likely the killer on a 4 GB VM" }

# ------------------------------------------- A2. CRASH EVIDENCE - Application
Sec "A2. CRASH EVIDENCE - Application log (sshd / Event 1000,1001,1002)"
try {
    Get-WinEvent -FilterHashtable @{ LogName='Application'; StartTime=(Get-Date).AddDays(-2) } -MaxEvents 300 -ErrorAction Stop |
      Where-Object { ($_.Message -match 'sshd|OpenSSH') -or $_.Id -in 1000,1001,1002 } |
      Select-Object -First 15 |
      ForEach-Object { $m = ($_.Message -replace '\s+',' '); W ("  [" + $_.TimeCreated + "] id=" + $_.Id + "  " + $m.Substring(0, [Math]::Min(160, $m.Length))) }
} catch { W ("  " + $_.Exception.Message) }

# ------------------------------------------- A3. CRASH EVIDENCE - System
Sec "A3. CRASH EVIDENCE - System log (Service Control Manager, sshd)"
try {
    Get-WinEvent -FilterHashtable @{ LogName='System'; StartTime=(Get-Date).AddDays(-2) } -MaxEvents 500 -ErrorAction Stop |
      Where-Object { $_.Message -match 'sshd|OpenSSH' } |
      Select-Object -First 20 |
      ForEach-Object { $m = ($_.Message -replace '\s+',' '); W ("  [" + $_.TimeCreated + "] id=" + $_.Id + "  " + $m.Substring(0, [Math]::Min(160, $m.Length))) }
} catch { W ("  " + $_.Exception.Message) }

# ------------------------------------------- A4. OPENSSH/Operational
Sec "A4. OPENSSH/Operational (last 40)"
try {
    Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 40 -ErrorAction Stop |
      ForEach-Object { $m = ($_.Message -replace '\s+',' '); W ("  [" + $_.TimeCreated + "] id=" + $_.Id + "  " + $m.Substring(0, [Math]::Min(140, $m.Length))) }
} catch { W ("  " + $_.Exception.Message) }

# ------------------------------------------- A5. RECOVERY SETTINGS
Sec "A5. CURRENT SERVICE RECOVERY SETTINGS"
& sc.exe qfailure sshd 2>&1 | ForEach-Object { W ("  " + $_) }

# ------------------------------------------- B. SERVICE RECOVERY
Sec "B. SET SERVICE RECOVERY (auto-restart on crash)"
try {
    & sc.exe failure sshd reset= 86400 actions= restart/5000/restart/5000/restart/10000 | Out-Null
    W "  sc failure sshd -> restart after 5s / 5s / 10s, reset daily"
    & sc.exe failureflag sshd 1 | Out-Null
    W "  failureflag = 1 (also act when service stops unexpectedly)"
} catch { W ("  recovery step error: " + $_.Exception.Message) }

# ------------------------------------------- C. WATCHDOG
Sec "C. WATCHDOG (every 5 min)"
$wd = @'
$ErrorActionPreference = 'SilentlyContinue'
$log = "$env:ProgramData\ssh\watchdog.log"
$ok = $false
try {
    $c = New-Object System.Net.Sockets.TcpClient
    $c.ReceiveTimeout = 5000; $c.SendTimeout = 5000
    $c.Connect('127.0.0.1', 22)
    $st = $c.GetStream(); $b = New-Object byte[] 64
    $n = $st.Read($b, 0, 64); $c.Close()
    if ($n -gt 0) { $ok = $true }
} catch { }
if (-not $ok) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $log -Value "[$ts] no banner on loopback -> restarting sshd"
    Restart-Service sshd -Force
    Start-Sleep -Seconds 4
    $s2 = Get-Service sshd
    Add-Content -Path $log -Value "[$ts] after restart: $($s2.Status)"
}
'@
try {
    Set-Content -Path $wdPs1 -Value $wd -Encoding ASCII -Force
    W ("  watchdog script -> " + $wdPs1)
    $act  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$wdPs1`""
    $trg  = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
    $prin = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $set  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $taskName -Action $act -Trigger $trg -Principal $prin -Settings $set -Force | Out-Null
    W "  scheduled task '$taskName' registered (every 5 min, SYSTEM)"
} catch { W ("  watchdog registration error: " + $_.Exception.Message) }

try {
    & $wdPs1
    W "  watchdog ran once now."
    W ("  watchdog log -> " + $wdLog)
    if (Test-Path $wdLog) { Get-Content $wdLog -Tail 5 | ForEach-Object { W ("    " + $_) } }
} catch { W ("  first-run error: " + $_.Exception.Message) }

# ------------------------------------------- VERDICT
Sec "VERDICT"
try {
    $s = Get-Service sshd
    $l2 = Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction SilentlyContinue
    W ("  sshd now      : " + $s.Status)
    W ("  listening 22  : " + [bool]$l2)
    W ("  memory used   : ${usedPct}%")
    if ($usedPct -gt 90) {
        W ""
        W "  RECOMMENDATION: memory is the likely killer. Free RAM (close unused Chrome tabs)"
        W "  or upgrade the VM to 8 GB. Watchdog masks the symptom, not the cause."
    }
    W ""
    W "  NEXT: from Mac, try  ssh -p 22 administrator@165.154.135.98"
    W "  If it dies again within ~10 min, send me A2/A3/A4 output - that names the real killer."
} catch { W ("  verdict error: " + $_.Exception.Message) }

Write-Host ""
Write-Host "RESULT_FILE = $out"
