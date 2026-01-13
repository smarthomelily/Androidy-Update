@echo off
:: Androidy Update v1.0 - Starter
:: Startet das PowerShell-Skript mit Admin-Rechten

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

:: Pruefe ob PowerShell-Skript existiert
if not exist "%~dp0Androidy-Update-v1.0.ps1" (
    echo.
    echo   FEHLER: Androidy-Update-v1.0.ps1 nicht gefunden!
    echo   Bitte alle Dateien in denselben Ordner entpacken.
    echo.
    pause
    exit /b 1
)

:: PowerShell-Skript starten
powershell -ExecutionPolicy Bypass -NoProfile -NoLogo -File "%~dp0Androidy-Update-v1.0.ps1"

:: Pause nur bei Fehler
if %errorLevel% neq 0 (
    echo.
    echo   Beendet mit Fehlercode: %errorLevel%
    pause
)
