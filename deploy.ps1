<#
.SYNOPSIS
    Deploy HS WebSphere Toolkit to a GCP server.

.DESCRIPTION
    Builds the tarball, copies it to the target server via gcloud compute scp,
    extracts it, runs the installer, and cleans up.

.EXAMPLE
    .\deploy.ps1 JLUKCNDWASBS01
    .\deploy.ps1 JLUKCNDWASBS01 -Zone europe-west2-a
    .\deploy.ps1 JLUKCNDWASBS01,JLUKCNDWASBS02
#>

param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$Servers,

    [string]$Zone,
    [string]$Project,
    [string]$Prefix = "/home/wasadmin/toolkit"
)

$ErrorActionPreference = "Stop"
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
$GcloudArgs = @()
if ($Zone)    { $GcloudArgs += "--zone=$Zone" }
if ($Project) { $GcloudArgs += "--project=$Project" }

# --- Deploy to each server ---
foreach ($Server in $Servers) {
    Write-Host "`n  Deploying v$Version to $Server..." -ForegroundColor Green

    # Copy tarball
    Write-Host "    Copying tarball..." -ForegroundColor DarkGray
    gcloud compute scp "$RepoRoot\$Tarball" "wasadmin@${Server}:/tmp/$Tarball" @GcloudArgs --quiet
    if ($LASTEXITCODE -ne 0) { throw "scp to $Server failed" }

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
    if ($LASTEXITCODE -ne 0) { throw "install on $Server failed" }

    Write-Host "    Done on $Server" -ForegroundColor Green
}

# --- Clean local tarball ---
Remove-Item "$RepoRoot\$Tarball" -ErrorAction SilentlyContinue

Write-Host "`n  Deployed v$Version to: $($Servers -join ', ')" -ForegroundColor Cyan
Write-Host ""
