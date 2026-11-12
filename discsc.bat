@echo off
setlocal EnableDelayedExpansion
title Offline Files (CSC) - Verify and Disable

:: =====================================================
::  Offline Files (CSC) - combined verify/disable tool
::  Run as Administrator. Reboot required after changes.
:: =====================================================

net session >nul 2>&1
if errorlevel 1 (
    echo [X] Please run this script as Administrator.
    pause
    exit /b 1
)

:: ---------- read current state ----------
set "CSC_START="
set "FORMATDB="

for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\CSC" /v Start 2^>nul ^| findstr /i "Start"') do set "CSC_START=%%A"

for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\CSC\Parameters" /v FormatDatabase 2^>nul ^| findstr /i "FormatDatabase"') do set "FORMATDB=%%A"

echo.
echo -----------------------------------------
echo  Current state
echo -----------------------------------------
if not defined CSC_START (
    echo  CSC driver Start value : could not be read
) else (
    echo  CSC driver Start value : !CSC_START!   [0x1 = enabled, 0x4 = disabled]
)
if not defined FORMATDB (
    echo  Cache wipe scheduled   : no
) else (
    echo  Cache wipe scheduled   : !FORMATDB!   [0x1 = yes, reboot pending]
)
echo.

:: ---------- decide what to do ----------
if not defined CSC_START goto :verify
if /i "!CSC_START!"=="0x4" (
    echo [i] Offline Files is already DISABLED - skipping disable steps.
    goto :verify
)

echo [X] Offline Files feature is ENABLED.
echo.
echo     SAFETY CHECK before the cache is wiped:
echo      - Be online / connected to the file server
echo      - Sync Center ^> "View sync conflicts" - resolve any entries
echo      - If you only READ from these shares, it is safe to continue
echo      - If files were EDITED while offline, sync them first.
echo.
choice /c YN /n /m "Disable Offline Files now? [Y/N]: "
if errorlevel 2 (
    echo Aborted - no changes made.
    goto :verify
)

:: ---------- disable ----------
echo.
echo [1/5] Stopping Offline Files service (CscService)...
sc stop CscService >nul 2>&1

echo [2/5] Setting CscService startup type to Disabled...
sc config CscService start= disabled >nul 2>&1

echo [3/5] Writing local policy (NetCache Enabled = 0)...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetCache" /v Enabled /t REG_DWORD /d 0 /f >nul

echo [4/5] Disabling CSC driver (Start = 4)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\CSC" /v Start /t REG_DWORD /d 4 /f >nul

echo [5/5] Scheduling cache wipe (FormatDatabase = 1)...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\CSC\Parameters" /v FormatDatabase /t REG_DWORD /d 1 /f >nul

echo.
echo [OK] All changes written. A REBOOT is required to apply them
echo      and to wipe the cache (C:\Windows\CSC).
echo.
choice /c YN /n /m "Reboot now? [Y/N]: "
if errorlevel 2 goto :verify
shutdown /r /t 10 /c "Rebooting to disable Offline Files and wipe the CSC cache"
exit /b 0

:: ---------- verification ----------
:verify
echo.
echo -----------------------------------------
echo  Verification
echo -----------------------------------------
echo.
echo [1] CSC driver Start - expected 0x4:
reg query "HKLM\SYSTEM\CurrentControlSet\Services\CSC" /v Start 2>nul | findstr /i "Start"
echo.
echo [2] FormatDatabase - expected 0x0 or missing:
reg query "HKLM\SYSTEM\CurrentControlSet\Services\CSC\Parameters" /v FormatDatabase 2>nul | findstr /i "FormatDatabase"
if errorlevel 1 echo     missing - OK (auto-reset after the wipe)
echo.
echo [3] Local policy Enabled - expected 0x0:
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetCache" /v Enabled 2>nul | findstr /i "Enabled"
echo.
echo [4] CscService state - expected STOPPED:
sc query CscService 2>nul | findstr /i "STATE"
echo.
echo [5] CscService start type - expected 4 DISABLED:
sc qc CscService 2>nul | findstr /i "START_TYPE"
echo.
echo -----------------------------------------
echo  Manual checks:
echo   - Sync Center: "Offline Files is currently disabled"
echo   - Explorer status bar: no sync state shown
echo   - Free disk space on C: increased (after reboot)
echo -----------------------------------------
echo.
pause
exit /b 0