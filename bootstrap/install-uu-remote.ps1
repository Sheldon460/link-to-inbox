# install-uu-remote.ps1 - One-shot UU Remote install on Windows
# Usage: in PowerShell as Administrator, run: & "C:\Windows\Temp\install-uu-remote.ps1"
$ErrorActionPreference = "Continue"

Write-Host "[1/1] Installing UU Remote (NetEase.UURemote) via winget..."
try {
    winget install --id NetEase.UURemote --exact --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    Write-Host "  UU Remote: INSTALLED"
} catch {
    Write-Host "  UU Remote: FAILED - $_"
    Write-Host "  Try opening Microsoft Store and searching 'UU Remote' manually."
}

Write-Host ""
Write-Host "=== UU_INSTALL_DONE ==="
Write-Host "Open UU Remote from Start Menu and sign in with the same account as your Mac client."
Write-Host "Recommended: choose 'Scan QR Code' login to avoid typing password."