@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: downloadLogs.cmd — Download WAS logs from GCP servers
:: ============================================================
:: Run without arguments for interactive menu, or pass servers:
::   downloadLogs
::   downloadLogs JLUKCNDWASBS01
::   downloadLogs --all
:: ============================================================

:: --- ANSI colors ---
for /f %%E in ('echo prompt $E ^| cmd') do set "ESC=%%E"
set "GREEN=%ESC%[92m"
set "CYAN=%ESC%[96m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "WHITE=%ESC%[97m"
set "BOLD=%ESC%[1m"
set "DIM=%ESC%[2m"
set "NC=%ESC%[0m"

set "PROJECT=john-lewis-partnership-190122"
set "ZONE=europe-west1-b"
set "REPOROOT=%~dp0"
set "LOGDIR=%REPOROOT%downloaded-logs"
set "HELPER=%REPOROOT%scripts\remote\package-logs.sh"

:: --- Server inventory ---
set "S1=jlkcndgbs01"
set "S2=jlukcndwasbs01"
set "S3=jlukcnewasbs01"
set "S4=wtukcewasbs01"
set "S5=wtukcewasbs02"
set "S6=wtukcfwasbs01"
set "ALL_SERVERS=%S1% %S2% %S3% %S4% %S5% %S6%"

:: --- Timestamp ---
for /f %%i in ('powershell -noprofile -command "Get-Date -Format yyyy-MM-dd_HHmmss"') do set "TIMESTAMP=%%i"

:: --- If args provided, use them directly ---
if not "%~1"=="" (
    if "%~1"=="--all" (
        set "SERVERS=%ALL_SERVERS%"
        goto :download
    )
    set "SERVERS="
    :parse_args
    if "%~1"=="" goto :download
    set "SERVERS=!SERVERS! %~1"
    shift
    goto :parse_args
)

:: --- Interactive menu ---
:menu
cls
echo.
echo   %BOLD%%CYAN%Download WAS Logs%NC%
echo   %DIM%------------------%NC%
echo.
echo     %BOLD%1%NC%  %WHITE%%S1%%NC%
echo     %BOLD%2%NC%  %WHITE%%S2%%NC%
echo     %BOLD%3%NC%  %WHITE%%S3%%NC%
echo     %BOLD%4%NC%  %WHITE%%S4%%NC%
echo     %BOLD%5%NC%  %WHITE%%S5%%NC%
echo     %BOLD%6%NC%  %WHITE%%S6%%NC%
echo.
echo     %BOLD%7%NC%  %GREEN%All servers%NC%
echo     %BOLD%0%NC%  %DIM%Exit%NC%
echo.
set /p "choice=  %BOLD%Select server:%NC% "

if "%choice%"=="0" exit /b 0
if "%choice%"=="7" (
    set "SERVERS=%ALL_SERVERS%"
    goto :download
)
if "%choice%"=="1" set "SERVERS=%S1%"& goto :download
if "%choice%"=="2" set "SERVERS=%S2%"& goto :download
if "%choice%"=="3" set "SERVERS=%S3%"& goto :download
if "%choice%"=="4" set "SERVERS=%S4%"& goto :download
if "%choice%"=="5" set "SERVERS=%S5%"& goto :download
if "%choice%"=="6" set "SERVERS=%S6%"& goto :download

echo.
echo   %RED%Invalid option.%NC%
timeout /t 1 >nul
goto :menu

:download
echo.
echo   %BOLD%%CYAN%Downloading WAS logs...%NC%
echo   %DIM%Timestamp: %TIMESTAMP%%NC%
echo.

set "FAIL_COUNT=0"
for %%S in (%SERVERS%) do call :download_server %%S
goto :results

:download_server
set "SRV=%~1"
set "DEST=%LOGDIR%\%SRV%\%TIMESTAMP%"
if not exist "%DEST%" mkdir "%DEST%"
echo.
echo   %BOLD%%YELLOW%[%SRV%]%NC% Collecting logs...

:: Upload helper script
echo     %DIM%Uploading packager...%NC%
call gcloud compute scp "%HELPER%" "%SRV%:/tmp/package-logs.sh" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet
if errorlevel 1 goto :dl_fail_ssh

:: Run it on server
echo     %DIM%Packaging logs + beanstore on server...%NC%
call gcloud compute ssh "%SRV%" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet --command="chmod +x /tmp/package-logs.sh && /tmp/package-logs.sh"
if errorlevel 1 goto :dl_fail_ssh

:: Download tarball
echo     %DIM%Downloading...%NC%
call gcloud compute scp "%SRV%:/tmp/was-logs.tar.gz" "%DEST%\was-logs.tar.gz" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet
if errorlevel 1 goto :dl_fail_scp

:: Extract locally
echo     %DIM%Extracting...%NC%
tar xzf "%DEST%\was-logs.tar.gz" -C "%DEST%"
del /q "%DEST%\was-logs.tar.gz" 2>nul

:: Clean up remote
call gcloud compute ssh "%SRV%" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet --command="rm -f /tmp/was-logs.tar.gz /tmp/package-logs.sh"

echo     %GREEN%[OK] %SRV%%NC%
goto :eof

:dl_fail_ssh
echo     %RED%FAILED: SSH to %SRV%%NC%
set /a FAIL_COUNT+=1
goto :eof

:dl_fail_scp
echo     %RED%FAILED: SCP from %SRV%%NC%
set /a FAIL_COUNT+=1
goto :eof

:results
echo.
echo   %DIM%----------------------------------------%NC%
if %FAIL_COUNT% equ 0 (
    echo   %GREEN%%BOLD%All logs downloaded successfully.%NC%
) else (
    echo   %RED%%BOLD%%FAIL_COUNT% server^(s^) failed.%NC%
)
echo   %DIM%Location: %LOGDIR%%NC%
echo.
