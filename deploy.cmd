@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: deploy.cmd — Deploy toolkit to GCP servers via CMD
:: ============================================================
:: Run without arguments for interactive menu, or pass servers:
::   deploy
::   deploy JLUKCNDWASBS01
::   deploy --all
:: ============================================================

:: --- ANSI colors ---
for /f %%E in ('echo prompt $E ^| cmd') do set "ESC=%%E"
set "GREEN=%ESC%[92m"
set "CYAN=%ESC%[96m"
set "YELLOW=%ESC%[93m"
set "RED=%ESC%[91m"
set "WHITE=%ESC%[97m"
set "MAGENTA=%ESC%[95m"
set "BOLD=%ESC%[1m"
set "DIM=%ESC%[2m"
set "NC=%ESC%[0m"

set "PROJECT=john-lewis-partnership-190122"
set "ZONE=europe-west1-b"
set "PREFIX=/home/wasadmin/toolkit"
set "SVC_USER=wasadmin"
set "SVC_PASS=wasadmin"
set "REPOROOT=%~dp0"
set "DISTDIR=%REPOROOT%build-toolkit"
set "REMOTETMP=/tmp/build-toolkit-deploy"

:: --- Auto-increment patch version ---
set /p OLD_VERSION=<"%REPOROOT%VERSION"
for /f "tokens=1-3 delims=." %%A in ("%OLD_VERSION%") do (
    set "MAJOR=%%A"
    set "MINOR=%%B"
    set /a "PATCH=%%C+1"
)
set "VERSION=%MAJOR%.%MINOR%.%PATCH%"
echo %VERSION%> "%REPOROOT%VERSION"
set "TARBALL=build-toolkit-%VERSION%.tar.gz"

:: --- Server inventory ---
set "S1=jlkcndgbs01"
set "S2=jlukcndwasbs01"
set "S3=jlukcnewasbs01"
set "S4=wtukcewasbs01"
set "S5=wtukcewasbs02"
set "S6=wtukcfwasbs01"
set "ALL_SERVERS=%S1% %S2% %S3% %S4% %S5% %S6%"

:: --- If args provided, use them directly ---
if not "%~1"=="" (
    if "%~1"=="--all" (
        set "SERVERS=%ALL_SERVERS%"
        goto :build
    )
    set "SERVERS="
    :parse_args
    if "%~1"=="" goto :build
    set "SERVERS=!SERVERS! %~1"
    shift
    goto :parse_args
)

:: --- Interactive menu ---
:menu
cls
echo.
echo   %BOLD%%MAGENTA%Deploy Toolkit%NC%    %DIM%v%OLD_VERSION% -^> v%VERSION%%NC%
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
    goto :build
)
if "%choice%"=="1" set "SERVERS=%S1%"& goto :build
if "%choice%"=="2" set "SERVERS=%S2%"& goto :build
if "%choice%"=="3" set "SERVERS=%S3%"& goto :build
if "%choice%"=="4" set "SERVERS=%S4%"& goto :build
if "%choice%"=="5" set "SERVERS=%S5%"& goto :build
if "%choice%"=="6" set "SERVERS=%S6%"& goto :build

echo.
echo   %RED%Invalid option.%NC%
timeout /t 1 >nul
goto :menu

:build
:: --- Build tarball ---
echo.
echo   %BOLD%%CYAN%Building %TARBALL%...%NC%

if exist "%DISTDIR%" rmdir /s /q "%DISTDIR%"
mkdir "%DISTDIR%"
for %%F in (config.sh menu.sh banner.txt install.sh uninstall.sh VERSION) do (
    copy /y "%REPOROOT%%%F" "%DISTDIR%\" >nul
)
xcopy /s /e /q /y "%REPOROOT%scripts" "%DISTDIR%\scripts\" >nul

pushd "%REPOROOT%"
tar czf "%TARBALL%" "build-toolkit"
popd
rmdir /s /q "%DISTDIR%"

if not exist "%REPOROOT%%TARBALL%" (
    echo   %RED%ERROR: Failed to create tarball.%NC%
    exit /b 1
)
echo   %GREEN%[OK]%NC% %TARBALL%

:: --- Deploy to each server ---
set "FAIL_COUNT=0"
for %%S in (%SERVERS%) do call :deploy_server %%S
goto :results

:: --- Per-server subroutine (no parenthesized blocks around gcloud) ---
:deploy_server
set "SRV=%~1"
echo.
echo   %BOLD%%YELLOW%[%SRV%]%NC% Deploying v%VERSION%...

echo     %DIM%Copying tarball...%NC%
call gcloud compute scp "%REPOROOT%%TARBALL%" "%SRV%:/tmp/%TARBALL%" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet
if errorlevel 1 goto :dep_scp_fail

echo     %DIM%Installing as %SVC_USER%...%NC%
call gcloud compute ssh "%SRV%" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet --command="set -e && rm -rf %REMOTETMP% && mkdir -p %REMOTETMP% && tar xzf /tmp/%TARBALL% -C %REMOTETMP% --strip-components=1 && chmod -R +x %REMOTETMP%/*.sh && find %REMOTETMP%/scripts -name '*.sh' -exec chmod +x {} + && rm -f /tmp/%TARBALL% && echo %SVC_PASS% | sudo -S -u %SVC_USER% bash %REMOTETMP%/install.sh --prefix %PREFIX% && rm -rf %REMOTETMP%"
if errorlevel 1 goto :dep_ssh_fail

echo     %GREEN%[OK] Done%NC%
goto :eof

:dep_scp_fail
echo     %RED%FAILED: scp to %SRV%%NC%
set /a FAIL_COUNT+=1
goto :eof

:dep_ssh_fail
echo     %RED%FAILED: install on %SRV%%NC%
set /a FAIL_COUNT+=1
goto :eof

:results
:: --- Cleanup ---
del /q "%REPOROOT%%TARBALL%" 2>nul

echo.
echo   %DIM%----------------------------------------%NC%
if %FAIL_COUNT% equ 0 (
    echo   %GREEN%%BOLD%Deployed v%VERSION% successfully.%NC%
) else (
    echo   %RED%%BOLD%%FAIL_COUNT% server^(s^) failed.%NC%
    exit /b 1
)
echo.
