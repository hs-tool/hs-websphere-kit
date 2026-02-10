@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: deploy.cmd — Deploy toolkit to GCP servers via CMD
:: ============================================================
:: Usage:
::   deploy jukcndwasb01
::   deploy jukcndwasb01 jukcnewasb01
::   deploy --all
:: ============================================================

set "PROJECT=john-lewis-partnership-190122"
set "ZONE=europe-west1-b"
set "PREFIX=/home/wasadmin/toolkit"
set "SVC_USER=wasadmin"
set "SVC_PASS=wasadmin"
set "REPOROOT=%~dp0"
set /p VERSION=<"%REPOROOT%VERSION"
set "TARBALL=build-toolkit-%VERSION%.tar.gz"
set "DISTDIR=%REPOROOT%build-toolkit"
set "REMOTETMP=/tmp/build-toolkit-deploy"

:: --- Server inventory ---
set "ALL_SERVERS=jukcgsb01 jukcndwasb01 jukcnewasb01 wtukcwasbs01 wtukcwasbs02 wtukcfwasbs01"

:: --- Parse args ---
set "SERVERS="
if "%~1"=="" goto :usage
if "%~1"=="--all" (
    set "SERVERS=%ALL_SERVERS%"
    goto :build
)
:parse_args
if "%~1"=="" goto :build
set "SERVERS=!SERVERS! %~1"
shift
goto :parse_args

:usage
echo.
echo   Usage:
echo     deploy jukcndwasb01                          single server
echo     deploy jukcndwasb01 jukcnewasb01             multiple servers
echo     deploy --all                                 all servers
echo.
echo   Available servers:
for %%S in (%ALL_SERVERS%) do echo     %%S
echo.
exit /b 1

:build
:: --- Build tarball ---
echo.
echo   Building %TARBALL%...

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
    echo   ERROR: Failed to create tarball.
    exit /b 1
)
echo   [OK] %TARBALL%

:: --- Deploy to each server ---
set "FAIL_COUNT=0"
for %%S in (%SERVERS%) do (
    echo.
    echo   [%%S] Deploying v%VERSION%...

    echo     Copying tarball...
    gcloud compute scp "%REPOROOT%%TARBALL%" "%%S:/tmp/%TARBALL%" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet
    if errorlevel 1 (
        echo     FAILED: scp to %%S
        set /a FAIL_COUNT+=1
    ) else (
        echo     Installing as %SVC_USER%...
        gcloud compute ssh "%%S" --project=%PROJECT% --zone=%ZONE% --tunnel-through-iap --quiet --command="set -e && rm -rf %REMOTETMP% && mkdir -p %REMOTETMP% && tar xzf /tmp/%TARBALL% -C %REMOTETMP% --strip-components=1 && chmod -R +x %REMOTETMP%/*.sh && find %REMOTETMP%/scripts -name '*.sh' -exec chmod +x {} + && rm -f /tmp/%TARBALL% && echo %SVC_PASS% | sudo -S -u %SVC_USER% bash %REMOTETMP%/install.sh --prefix %PREFIX% && rm -rf %REMOTETMP%"
        if errorlevel 1 (
            echo     FAILED: install on %%S
            set /a FAIL_COUNT+=1
        ) else (
            echo     [OK] Done
        )
    )
)

:: --- Cleanup ---
del /q "%REPOROOT%%TARBALL%" 2>nul

echo.
echo   ----------------------------------------
if %FAIL_COUNT% equ 0 (
    echo   Deployed v%VERSION% successfully.
) else (
    echo   %FAIL_COUNT% server^(s^) failed.
    exit /b 1
)
echo.
