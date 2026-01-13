# Erstellt Desktop-Verknuepfung fuer Androidy Update
# Kompatibel mit Windows 10 und Windows 11 (inkl. OneDrive)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Desktop-Pfad ermitteln (OneDrive-kompatibel fuer Windows 11)
$Desktop = [Environment]::GetFolderPath('Desktop')

# Falls leer (kann bei OneDrive passieren), Fallback verwenden
if ([string]::IsNullOrEmpty($Desktop)) {
    if ($env:OneDrive -and (Test-Path (Join-Path $env:OneDrive "Desktop"))) {
        $Desktop = Join-Path $env:OneDrive "Desktop"
    } elseif ($env:OneDrive -and (Test-Path (Join-Path $env:OneDrive "Schreibtisch"))) {
        $Desktop = Join-Path $env:OneDrive "Schreibtisch"
    } else {
        $Desktop = Join-Path $env:USERPROFILE "Desktop"
    }
}

$ShortcutPath = Join-Path $Desktop "Androidy Update.lnk"

Write-Host ""
Write-Host "  Erstelle Desktop-Verknuepfung..." -ForegroundColor Cyan
Write-Host "  Desktop-Pfad: $Desktop" -ForegroundColor DarkGray
Write-Host ""

try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = Join-Path $ScriptDir "Androidy-Update-v1.0.bat"
    $Shortcut.WorkingDirectory = $ScriptDir
    $Shortcut.IconLocation = Join-Path $ScriptDir "Androidy-Update-v1.0.ico"
    $Shortcut.Description = "Windows Update Tool (WinGet, Store, Windows)"
    $Shortcut.Save()
    
    Write-Host "  [OK] Verknuepfung erstellt!" -ForegroundColor Green
    Write-Host "  Pfad: $ShortcutPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  HINWEIS: Fuer Admin-Rechte bei jedem Start:" -ForegroundColor Yellow
    Write-Host "  1. Rechtsklick auf die Verknuepfung"
    Write-Host "  2. Eigenschaften"
    Write-Host "  3. Erweitert..."
    Write-Host "  4. 'Als Administrator ausfuehren' aktivieren"
    Write-Host ""
}
catch {
    Write-Host "  [FEHLER] $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host "  Enter zum Beenden"
