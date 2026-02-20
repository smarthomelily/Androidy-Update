@echo off
:: Androidy Update - Starter
:: Selfupdate-Pruefung vor dem Start der Hauptanwendung
:: Versionsnummer und Hauptskript werden dynamisch ermittelt

:: UTF-8 Codepage setzen
chcp 65001 >nul 2>&1

:: Ins Skript-Verzeichnis wechseln
cd /d "%~dp0"

:: Admin-Check
>nul 2>&1 net session
if %errorLevel% neq 0 (
    echo.
    echo   Fordere Administrator-Rechte an...
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs -WorkingDirectory '%~dp0'"
    exit /b
)

:: Hauptskript per Wildcard finden
set MAIN_PS1=
for %%f in ("%~dp0Androidy-Update-v*.ps1") do set MAIN_PS1=%%f

if not defined MAIN_PS1 (
    echo.
    echo   FEHLER: Kein Androidy-Update Skript gefunden!
    echo   Bitte alle Dateien in denselben Ordner entpacken.
    echo.
    pause
    exit /b 1
)

:: Version aus PS1 auslesen
set CURRENT_VERSION=
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "$v = (Select-String -Path \"%MAIN_PS1%\" -Pattern \"\\\$script:Version\s*=\s*['\"']([^'\"']+)['\"']\").Matches[0].Groups[1].Value; $v"') do set CURRENT_VERSION=%%i

:: Selfupdate-Pruefung (nur wenn Updater vorhanden)
if exist "%~dp0Androidy-Updater.ps1" (
    if defined CURRENT_VERSION (
        powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Androidy-Updater.ps1" ^
            -RepoOwner "smarthomelily" ^
            -RepoName "Androidy-Update" ^
            -CurrentVersion "%CURRENT_VERSION%" ^
            -InstallDir "%~dp0" ^
            -RestartBat "%~f0"

        :: Exit 99 = Update installiert, Helper-Bat laeuft bereits
        if %errorLevel% equ 99 exit /b
    )
)

:: Hauptanwendung starten
powershell -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%MAIN_PS1%"

if %errorLevel% neq 0 (
    echo.
    echo   Beendet mit Fehlercode: %errorLevel%
    pause
)
