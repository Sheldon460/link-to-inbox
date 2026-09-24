$ErrorActionPreference = "Continue"
$log = @()

# Section 1: OpenSSH Server
Write-Host "[1/5] Installing OpenSSH Server..."
$ok = $true
try {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 2>&1 | Out-Null
    Start-Service sshd 2>&1 | Out-Null
    Set-Service -Name sshd -StartupType Automatic 2>&1 | Out-Null
    if (-not (Get-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }
} catch { Write-Host "  OpenSSH: FAILED - $_"; $ok = $false }
if ($ok) { Write-Host "  OpenSSH: OK" }

# Section 2: RDP clipboard fix (ensure redirection enabled)
Write-Host "[2/5] RDP clipboard fix..."
try {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name "fDisableClip" -Value 0 -Type DWord -Force
    Write-Host "  Clipboard enabled (fDisableClip=0)"
} catch {
    Write-Host "  Clipboard reg fix: FAILED - $_"
}

# Section 3: 7-Zip
Write-Host "[3/5] Installing 7-Zip..."
try { winget install --id 7zip.7zip --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null; Write-Host "  7-Zip: OK" } catch { Write-Host "  7-Zip: FAILED - $_" }

# Section 4: VS Code
Write-Host "[4/5] Installing VS Code..."
try { winget install --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null; Write-Host "  VS Code: OK" } catch { Write-Host "  VS Code: FAILED - $_" }

# Section 5: PowerToys
Write-Host "[5/5] Installing PowerToys..."
try { winget install --id Microsoft.PowerToys --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null; Write-Host "  PowerToys: OK" } catch { Write-Host "  PowerToys: FAILED - $_" }

# Notes (not installed - user already has or built-in):
# - Chinese IME (Microsoft Pinyin): built-in to Windows 11, enable in Settings -> Time & Language -> Language
# - OneDrive: built-in to Windows 11, sign in with the same Google-account-tied Microsoft account if any

Write-Host ""
Write-Host "=== BOOTSTRAP_DONE ==="
Write-Host "OpenSSH listening on port 22. Connect from your Mac: ssh Administrator@165.154.135.98"