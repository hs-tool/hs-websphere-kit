@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: downloadLogs.cmd — Download WAS logs from GCP servers
:: ============================================================
:: Usage:
::   downloadLogs jukcndwasb01
::   downloadLogs jukcndwasb01 jukcnewasb01
::   downloadLogs --all
::
:: Downloads WAS logs + beanstore directory from each server
:: into downloaded-logs\{server}\{timestamp}\
:: ============================================================

set "PROJECT=john-lewis-partnership-190122"
set "ZONE=europe-west1-b"
set "REPOROOT=%~dp0"
set "LOGDIR=%REPOROOT%downloaded-logs"
set "WAS_BASE=/opt/was/profiles"

:: --- Server inventory ---
set "ALL_SERVERS=jukcgsb01 jukcndwasb01 jukcnewasb01 wtukcwasbs01 wtukcwasbs02 wtukcfwasbs01"

:: --- Timestamp ---
for /f %%i in ('powershell -noprofile -command "Get-Date -Format yyyy-MM-dd_HHmmss"') do set "TIMESTAMP=%%i"

:: --- Parse args ---
set "SERVERS="
if "%~1"=="" goto :usage
if "%~1"=="--all" (
    set "SERVERS=%ALL_SERVERS%"
    goto :download
)
:parse_args
if "%~1"=="" goto :download
set "SERVERS=!SERVERS! %~1"
shift
goto :parse_args

:usage
echo.
echo   Usage:
echo     downloadLogs jukcndwasb01                        single server
echo     downloadLogs jukcndwasb01 jukcnewasb01           multiple servers
echo     downloadLogs --all                               all servers
echo.
echo   Available servers:
for %%S in (%ALL_SERVERS%) do echo     %%S
echo.
exit /b 1

:download
echo.
echo   Downloading WAS logs...
echo   Timestamp: %TIMESTAMP%
echo.

set "FAIL_COUNT=0"
for %%S in (%SERVERS%) do (
    echo.
    echo   [%%S] Collecting logs...

    set "DEST=%LOGDIR%\%%S\%TIMESTAMP%"
    if not exist "!DEST!" mkdir "!DEST!"

    :: Step 1: SSH — find beanstore + tar up logs and beanstore
    echo     Packaging logs + beanstore on server...
    gcloud compute ssh "%%S" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet --command="H=$(hostname) && BS=$(find /wasappdata /home /opt -maxdepth 5 -type d -name beanstore 2>/dev/null | head -1) && tar czf /tmp/was-logs.tar.gz --ignore-failed-read -C %WAS_BASE% ${H}_NDM/logs ${H}_NODE01/logs $([ -n \"$BS\" ] && echo \"-C $(dirname $BS) beanstore\") 2>/dev/null; exit 0"
    if errorlevel 1 (
        echo     FAILED: SSH to %%S
        set /a FAIL_COUNT+=1
    ) else (
        :: Step 2: Download tarball
        echo     Downloading...
        gcloud compute scp "%%S:/tmp/was-logs.tar.gz" "!DEST!\was-logs.tar.gz" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet
        if errorlevel 1 (
            echo     FAILED: SCP from %%S
            set /a FAIL_COUNT+=1
        ) else (
            :: Step 3: Extract locally
            echo     Extracting...
            tar xzf "!DEST!\was-logs.tar.gz" -C "!DEST!"
            del /q "!DEST!\was-logs.tar.gz" 2>nul

            :: Step 4: Clean up remote tarball
            gcloud compute ssh "%%S" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet --command="rm -f /tmp/was-logs.tar.gz"

            echo     [OK] %%S
        )
    )
)

echo.
echo   ----------------------------------------
if %FAIL_COUNT% equ 0 (
    echo   All logs downloaded successfully.
) else (
    echo   %FAIL_COUNT% server^(s^) failed.
)
echo   Location: %LOGDIR%
echo.
