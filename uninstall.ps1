<#
.SYNOPSIS
    cc-switch uninstaller for Windows PowerShell.

.DESCRIPTION
    Uninstalls cc-switch from uv tool install.
    User data (~\.claude\cc-switch.json) is NOT removed - delete it manually if needed.

    ASCII only: Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI, so a
    literal em-dash would show up as mojibake in Get-Help output.

.EXAMPLE
    .\uninstall.ps1
#>

$ErrorActionPreference = "Continue"

function Write-Step($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Ok($msg)   { Write-Host "  $([char]0x2713) $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  $([char]0x2717) $msg" -ForegroundColor Red }
function Write-Dim($msg)  { Write-Host "  $msg" -ForegroundColor DarkGray }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }

Write-Host ""
Write-Host "cc-switch Uninstaller" -ForegroundColor Cyan
Write-Host ""

# 1. Remove the ANTHROPIC_AUTH_TOKEN that ``activate`` injected into the
# system environment (HKCU\Environment here).  This has to run BEFORE the
# uninstall below: credstore ships inside the cc-switch tool environment,
# so its CLI disappears with it.  credstore only removes the value it
# injected, so nothing unrelated is touched.
$envKey = "ANTHROPIC_AUTH_TOKEN"
if (Get-Command credstore -ErrorAction SilentlyContinue) {
    credstore uninject $envKey 2>&1 | Out-Null
    Write-Ok "Removed $envKey from the environment"
} else {
    Write-Dim "credstore not on PATH - skipping $envKey cleanup."
    Write-Dim "  If you activated a provider, unset $envKey manually."
}

# 2. Uninstall from uv tool
$installed = uv tool list 2>$null | Select-String "cc-switch"
if ($installed) {
    Write-Step "Uninstalling cc-switch..."
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $uninstallOutput = uv tool uninstall cc-switch 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prevEAP
    if ($ok) {
        Write-Ok "cc-switch removed"
    } else {
        Write-Fail "uninstall failed"
        if ($uninstallOutput) {
            $uninstallOutput | Select-Object -Last 5 | ForEach-Object { Write-Dim "    $_" }
        }
    }
} else {
    Write-Dim "cc-switch is not installed."
}

# 3. Clean up wrapper binaries
$localBin = "$env:USERPROFILE\.local\bin"
foreach ($bin in @("$localBin\cc-switch.exe", "$localBin\cc-switch.cmd")) {
    if (Test-Path $bin) {
        Remove-Item $bin -Force -ErrorAction SilentlyContinue
        Write-Dim "  Removed: $bin"
    }
}

# 4. Remaining data
Write-Host ""
$configFile = "$env:USERPROFILE\.claude\cc-switch.json"
$settingsFile = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $configFile) {
    Write-Warn "Data files NOT removed (delete manually if desired):"
    Write-Dim "  $configFile       - provider/model configs"
    if (Test-Path $settingsFile) {
        Write-Dim "  $settingsFile          - written by 'cc-switch activate'"
    }
} else {
    Write-Ok "No remaining data files."
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
