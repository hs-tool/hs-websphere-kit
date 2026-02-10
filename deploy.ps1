<#
.SYNOPSIS
    Deploy HS WebSphere Toolkit to GCP servers.

.DESCRIPTION
    Builds the tarball, copies it to the target server(s) via gcloud compute scp,
    extracts it, runs the installer, and cleans up.

.EXAMPLE
    .\deploy.ps1 jukcndwasb01
    .\deploy.ps1 jukcndwasb01,wtukcwasbs01
    .\deploy.ps1 -All
    .\deploy.ps1 -All -Zone europe-west2-a
#>

param(
    [Parameter(Position = 0)]
    [string[]]$Servers,

    [switch]$All,
    [string]$Zone,
    [string]$Project = "john-lewis-partnership-190122",
    [string]$Prefix = "/home/wasadmin/toolkit"
)

$ErrorActionPreference = "Stop"

# --- Server inventory ---
$AllServers = @(
    "jukcgsb01"
    "jukcndwasb01"
    "jukcnewasb01"
    "wtukcwasbs01"
    "wtukcwasbs02"
    "wtukcfwasbs01"
)

if ($All) {
    $Servers = $AllServers
}

if (-not $Servers -or $Servers.Count -eq 0) {
    Write-Host "`n  Usage:" -ForegroundColor Yellow
    Write-Host "    .\deploy.ps1 jukcndwasb01              # single server"
    Write-Host "    .\deploy.ps1 jukcndwasb01,wtukcwasbs01  # multiple servers"
    Write-Host "    .\deploy.ps1 -All                       # all servers"
    Write-Host ""
    Write-Host "  Available servers:" -ForegroundColor Yellow
    $AllServers | ForEach-Object { Write-Host "    $_" }
    Write-Host ""
    exit 1
}

$RepoRoot = $PSScriptRoot
$Version = (Get-Content "$RepoRoot\VERSION" -Raw).Trim()
$Tarball = "build-toolkit-$Version.tar.gz"
$RemoteTmp = "/tmp/build-toolkit-deploy"

# --- Build tarball ---
Write-Host "`n  Building $Tarball..." -ForegroundColor Cyan
Push-Location $RepoRoot
try {
    make dist
    if (-not (Test-Path $Tarball)) {
        throw "make dist did not produce $Tarball"
    }
}
finally { Pop-Location }

# --- Build gcloud common args ---
$GcloudArgs = @("--project=$Project")
if ($Zone) { $GcloudArgs += "--zone=$Zone" }

# --- Deploy to each server ---
$Failed = @()
foreach ($Server in $Servers) {
    Write-Host "`n  [$Server] Deploying v$Version..." -ForegroundColor Green

    try {
        # Copy tarball
        Write-Host "    Copying tarball..." -ForegroundColor DarkGray
        gcloud compute scp "$RepoRoot\$Tarball" "wasadmin@${Server}:/tmp/$Tarball" @GcloudArgs --quiet
        if ($LASTEXITCODE -ne 0) { throw "scp failed" }

        # Extract, install, clean up
        Write-Host "    Installing..." -ForegroundColor DarkGray
        $RemoteCmd = @(
            "set -e"
            "mkdir -p $RemoteTmp"
            "tar xzf /tmp/$Tarball -C $RemoteTmp --strip-components=1"
            "$RemoteTmp/install.sh --prefix $Prefix"
            "rm -rf $RemoteTmp /tmp/$Tarball"
        ) -join " && "

        gcloud compute ssh "wasadmin@$Server" @GcloudArgs --quiet --command="$RemoteCmd"
        if ($LASTEXITCODE -ne 0) { throw "install failed" }

        Write-Host "    Done" -ForegroundColor Green
    }
    catch {
        Write-Host "    FAILED: $_" -ForegroundColor Red
        $Failed += $Server
    }
}

# --- Clean local tarball ---
Remove-Item "$RepoRoot\$Tarball" -ErrorAction SilentlyContinue

# --- Summary ---
Write-Host ""
Write-Host "  ────────────────────────────────────────" -ForegroundColor DarkGray
$Deployed = $Servers | Where-Object { $_ -notin $Failed }
if ($Deployed.Count -gt 0) {
    Write-Host "  Deployed v$Version to: $($Deployed -join ', ')" -ForegroundColor Green
}
if ($Failed.Count -gt 0) {
    Write-Host "  Failed: $($Failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host ""
