@echo off
:: Erstellt eine Desktop-Verknuepfung fuer Androidy Update
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0Androidy-Update-Verknuepfung.ps1"
