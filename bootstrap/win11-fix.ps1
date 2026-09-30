#requires -Version 5.1
<#
  win11-fix.ps1
  Single-shot repair + diagnostics for the UCloud Windows 11 Pro VM.
  ASCII-only on purpose: RDP clipboard corruption mangles non-ASCII input.
  Result file: %USERPROFILE%\Desktop\win11-fix-result.txt
#>

$ErrorActionPreference = 'Continue'
$out = Join-Path $env:USERPROFILE 'Desktop\win11-fix-result.txt'
$lines = New-Object System.Collections.Generic.List[string]

function Add-Section($t) { $lines.Add(''); $lines.Add("=== $t ===") }
function Add-Line($t)   { $lines.Add([string]$t) }

Add-Section "RUN"
Add-Line ("Time      : " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'))
Add-Line ("Computer  : " + $env:COMPUTERNAME)
Add-Line ("User      : " + $env:USERNAME)
Add-Line ("OS        : " + (Get-CimInstance Win32_OperatingSystem).Caption)

# ---------------------------------------------------------------- ACTIVATION
Add-Section "ACTIVATION (read-only, no key is set)"

try {
    $osp = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" -ErrorAction Stop |
           Where-Object { $_.Name -like '*Windows*' -and $_.Name -notlike '*Server*' }
    if (-not $osp) {
        Add-Line "No Windows licensing product found at all."
    }
    foreach ($p in $osp) {
        Add-Line ("Name            : " + $p.Name)
        Add-Line ("Description     : " + $p.Description)
        Add-Line ("PartialProductKey: " + $p.PartialProductKey)
        Add-Line ("LicenseStatus   : " + $p.LicenseStatus + "  (0=Unlicensed 1=Licensed 2=OOBGrace 3=OOTGrace 4=NonGenuineGrace 5=Notification 6=ExtendedGrace)")
    }

    $svc = Get-CimInstance SoftwareLicensingService
    Add-Line ("ClientMachineID : " + $svc.ClientMachineID)
    try { Add-Line ("OEM/App key file: " + ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform' -Name BackupProductKeyDefault -ErrorAction Stop).BackupProductKeyDefault)) }
    catch { Add-Line "OEM/App key file : <none>" }
    try { Add-Line ("OEM key (OA3)   : " + (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop).OA3xOriginalProductKey) }
    catch { Add-Line "OEM key (OA3)   : <unavailable>" }
} catch { Add-Line ("licensing query failed: " + $_.Exception.Message) }

Add-Line ""
Add-Line "Interpretation:"
Add-Line "  0xC004F213 = no product key found on this device. Not an OEM/firmware issue."
Add-Line "  A valid key (or a digital entitlement bound to this hardware) is required."

# ------------------------------------------------------------------- SSH
Add-Section "OPENSSSH SERVER"

$sshCap = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction SilentlyContinue
if ($sshCap -and $sshCap.State -ne 'Installed') {
    Add-Line "State: $($sshCap.State) -> installing (this pulls ~4MB, needs internet)"
    try { $r = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop; Add-Line ("Result: " + $r.RestartNeeded) }
    catch { Add-Line ("Install FAILED: " + $_.Exception.Message) }
} elseif ($sshCap) {
    Add-Line "State: Installed"
} else {
    Add-Line "Capability not reported by this build of Windows."
}

try {
    Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop
    Start-Service -Name sshd -ErrorAction Stop
    Add-Line "Service sshd: running, startup=Automatic"
} catch { Add-Line ("Service FAILED: " + $_.Exception.Message) }

if (-not (Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'sshd' -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Add-Line "Firewall rule sshd: created"
} else {
    Enable-NetFirewallRule -Name 'sshd'
    Add-Line "Firewall rule sshd: exists and enabled"
}

$listen = Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction SilentlyContinue
if ($listen) { Add-Line ("Listening on: " + (($listen | ForEach-Object { "$($_.LocalAddress):$($_.LocalPort)" }) -join ', ')) }
else { Add-Line "NOT listening on port 22." }

# ------------------------------------------------------------- CLIPBOARD
Add-Section "RDP CLIPBOARD"

foreach ($path in 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services',
                 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp') {
    try {
        Set-ItemProperty -Path $path -Name 'fDisableClip' -Value 0 -Type DWord -Force -ErrorAction Stop
        Add-Line ("fDisableClip=0 -> " + $path)
    } catch { Add-Line ("failed on " + $path + " : " + $_.Exception.Message) }
}
Get-Process rdpclip -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath "$env:SystemRoot\System32\rdpclip.exe"
Add-Line "rdpclip restarted."

# ------------------------------------------------------------ UU REMOTE
Add-Section "UU REMOTE (NetEase)"

$uu = @()
foreach ($n in 'UURemote','UURemoteDesktop','UURemoteClient') {
    $uu += Get-Process -Name $n -ErrorAction SilentlyContinue
}
if ($uu.Count) { foreach ($p in $uu) { Add-Line ("running: " + $p.ProcessName) } }
else { Add-Line "Not running. Startup entry / service was not found." }
Add-Section "PATH"
Add-Line $env:PATH
