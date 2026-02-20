<#
.SYNOPSIS
    Androidy Update v1.1 - Windows Update Tool (WinGet)
.DESCRIPTION
    Vier Modi:
    - Updates anzeigen: Verfuegbare Updates auflisten
    - Alle Updates: Automatisch alles aktualisieren
    - Interaktiv: Updates einzeln bestaetigen
    - Alle ausser Auswahl: Bestimmte Updates ueberspringen
    Plus: Exclude-Liste, Desktop-Icon-Bereinigung
.AUTHOR
    smarthomelily
.VERSION
    1.1
.BUILD
    20260219
.LICENSE
    GPL v3 - https://www.gnu.org/licenses/gpl-3.0
    Copyright (c) 2026 smarthomelily
    
    Dieses Programm ist freie Software. Du kannst es weitergeben und/oder
    modifizieren unter den Bedingungen der GNU General Public License v3.
    Abgeleitete Werke muessen ebenfalls unter GPL v3 veroeffentlicht werden.
.LINK
    https://github.com/smarthomelily/Androidy-Update
#>

#Requires -Version 5.1

# ============================================================================
# KONFIGURATION
# ============================================================================
$script:Version = "1.1"
$script:Build = "20260219"
$script:LogFile = Join-Path $PSScriptRoot "Androidy-Update.log"
$script:ExcludeFile = Join-Path $PSScriptRoot "Androidy-Update-Exclude.txt"
$script:DryRun = $false
$script:CleanDesktopIcons = $true

# Update-Quellen
$script:Sources = @{
    WinGet = $true
    MSStore = $true
    WindowsUpdate = $true
}

# Statistik
$script:Stats = @{
    Updated = 0
    Skipped = 0
    Failed = 0
    Excluded = 0
    IconsRemoved = 0
    WindowsUpdates = 0
}

# Desktop-Pfade (inkl. OneDrive auf Windows 11)
$script:DesktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('CommonDesktopDirectory')
)

# OneDrive Desktop hinzufuegen falls vorhanden (Windows 11)
if ($env:OneDrive) {
    $oneDriveDesktop = Join-Path $env:OneDrive "Desktop"
    if (Test-Path $oneDriveDesktop -ErrorAction SilentlyContinue) {
        $script:DesktopPaths += $oneDriveDesktop
    }
    $oneDriveDesktopDE = Join-Path $env:OneDrive "Schreibtisch"
    if (Test-Path $oneDriveDesktopDE -ErrorAction SilentlyContinue) {
        $script:DesktopPaths += $oneDriveDesktopDE
    }
}

# Duplikate entfernen
$script:DesktopPaths = $script:DesktopPaths | Select-Object -Unique

# Bekannte problematische Pakete (werden automatisch uebersprungen)
$script:AutoSkipPackages = @(
    "Microsoft.WindowsTerminal",
    "Microsoft.WindowsTerminal.Preview"
)

# Encoding auf UTF-8 setzen
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Add-Content:Encoding'] = 'utf8'

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DRYRUN", "UPDATE")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Konsole
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "DRYRUN"  { "Cyan" }
        "UPDATE"  { "Magenta" }
        default   { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
    
    # Datei
    Add-Content -Path $script:LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Show-Header {
    Clear-Host
    $dryRunHint = if ($script:DryRun) { " [DRY-RUN MODUS]" } else { "" }
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host "      ANDROIDY UPDATE v$($script:Version)$dryRunHint" -ForegroundColor Cyan
    Write-Host "              Update-Zentrale" -ForegroundColor DarkCyan
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-WinGet {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Log "WinGet ist nicht installiert!" -Level "ERROR"
        Write-Host ""
        Write-Host "  WinGet kann ueber den Microsoft Store installiert werden:" -ForegroundColor Yellow
        Write-Host "  'App Installer' suchen und installieren" -ForegroundColor Gray
        Write-Host ""
        return $false
    }
    return $true
}

function Test-AdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ExcludeList {
    if (Test-Path $script:ExcludeFile) {
        $excludes = Get-Content $script:ExcludeFile -ErrorAction SilentlyContinue | 
                    Where-Object { $_ -and $_.Trim() -and -not $_.StartsWith("#") }
        return $excludes
    }
    return @()
}

function Add-ToExcludeList {
    param([string]$AppId)
    
    if (-not (Test-Path $script:ExcludeFile)) {
        $header = "# Androidy Update - Exclude Liste`r`n"
        $header += "# Apps hier eintragen die NICHT aktualisiert werden sollen`r`n"
        $header += "# Eine App-ID pro Zeile, Zeilen mit # werden ignoriert`r`n"
        $header += "# Beispiel: Microsoft.Edge`r`n"
        $header | Out-File $script:ExcludeFile -Encoding utf8
    }
    
    Add-Content -Path $script:ExcludeFile -Value $AppId
    Write-Log "Zur Exclude-Liste hinzugefuegt: $AppId" -Level "SUCCESS"
}

function Remove-FromExcludeList {
    param([string]$AppId)
    
    if (Test-Path $script:ExcludeFile) {
        $content = Get-Content $script:ExcludeFile | Where-Object { $_.Trim() -ne $AppId }
        $content | Out-File $script:ExcludeFile -Encoding utf8
        Write-Log "Von Exclude-Liste entfernt: $AppId" -Level "SUCCESS"
    }
}

function Test-AutoSkipPackage {
    param([string]$PackageId)
    
    foreach ($skip in $script:AutoSkipPackages) {
        if ($PackageId -like "*$skip*") {
            return $true
        }
    }
    return $false
}

function Show-TerminalWarning {
    param([array]$Updates)
    
    $terminalUpdate = $Updates | Where-Object { $_.Id -like "*WindowsTerminal*" }
    
    if ($terminalUpdate) {
        Write-Host ""
        Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
        Write-Host "  |  HINWEIS: Windows Terminal Update verfuegbar             |" -ForegroundColor Yellow
        Write-Host "  |                                                          |" -ForegroundColor Yellow
        Write-Host "  |  Das Terminal kann sich nicht selbst aktualisieren       |" -ForegroundColor Yellow
        Write-Host "  |  waehrend es laeuft. Bitte manuell ueber den             |" -ForegroundColor Yellow
        Write-Host "  |  Microsoft Store aktualisieren.                          |" -ForegroundColor Yellow
        Write-Host "  |                                                          |" -ForegroundColor Yellow
        Write-Host "  |  Das Update wird automatisch uebersprungen.              |" -ForegroundColor Yellow
        Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
        Write-Host ""
        Write-Log "Windows Terminal Update verfuegbar - wird automatisch uebersprungen" -Level "WARNING"
    }
}

# ============================================================================
# DESKTOP-ICON FUNKTIONEN
# ============================================================================

function Get-DesktopIcons {
    # Sammle alle .lnk Dateien von beiden Desktops
    $icons = @()
    foreach ($path in $script:DesktopPaths) {
        if (Test-Path $path) {
            $icons += Get-ChildItem -Path $path -Filter "*.lnk" -ErrorAction SilentlyContinue
        }
    }
    return $icons
}

function Remove-NewDesktopIcons {
    param(
        [array]$IconsBefore,
        [datetime]$StartTime
    )
    
    if (-not $script:CleanDesktopIcons) { return }
    
    $iconsAfter = Get-DesktopIcons
    $beforeNames = $IconsBefore | ForEach-Object { $_.Name }
    
    foreach ($icon in $iconsAfter) {
        # Icon ist neu wenn: nicht in vorheriger Liste ODER nach StartTime erstellt
        $isNew = ($icon.Name -notin $beforeNames) -or ($icon.CreationTime -gt $StartTime)
        
        if ($isNew) {
            if ($script:DryRun) {
                Write-Log "[DRY-RUN] Wuerde Desktop-Icon loeschen: $($icon.Name)" -Level "DRYRUN"
            } else {
                try {
                    Remove-Item -Path $icon.FullName -Force -ErrorAction Stop
                    Write-Log "Desktop-Icon entfernt: $($icon.Name)" -Level "SUCCESS"
                    $script:Stats.IconsRemoved++
                } catch {
                    Write-Log "Konnte Icon nicht loeschen: $($icon.Name)" -Level "WARNING"
                }
            }
        }
    }
}

# ============================================================================
# WINDOWS UPDATE FUNKTIONEN
# ============================================================================

function Test-WindowsUpdateModule {
    # Pruefe ob PSWindowsUpdate Modul verfuegbar ist
    $module = Get-Module -ListAvailable -Name PSWindowsUpdate -ErrorAction SilentlyContinue
    return $null -ne $module
}

function Install-WindowsUpdateModule {
    Write-Log "Installiere PSWindowsUpdate Modul..." -Level "INFO"
    
    if ($script:DryRun) {
        Write-Log "[DRY-RUN] Wuerde PSWindowsUpdate Modul installieren" -Level "DRYRUN"
        return $false
    }
    
    try {
        # NuGet Provider sicherstellen
        $null = Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
        
        # Modul installieren
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
        Write-Log "PSWindowsUpdate Modul installiert" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Fehler bei Installation von PSWindowsUpdate: $_" -Level "ERROR"
        return $false
    }
}

function Get-WindowsUpdatesAvailable {
    Write-Log "Suche nach Windows Updates..." -Level "INFO"
    
    # Methode 1: PSWindowsUpdate Modul (bevorzugt)
    if (Test-WindowsUpdateModule) {
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            $updates = Get-WindowsUpdate -ErrorAction Stop
            return $updates
        }
        catch {
            Write-Log "Fehler bei PSWindowsUpdate: $_" -Level "WARNING"
        }
    }
    
    # Methode 2: COM-Objekt (Fallback)
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        
        Write-Host "  Suche nach Windows Updates (kann etwas dauern)..." -ForegroundColor Gray
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
        
        $updates = @()
        foreach ($update in $searchResult.Updates) {
            $updates += [PSCustomObject]@{
                Title = $update.Title
                KB = ($update.KBArticleIDs | Select-Object -First 1)
                Size = [math]::Round($update.MaxDownloadSize / 1MB, 1)
                IsMandatory = $update.IsMandatory
                UpdateObject = $update
            }
        }
        return $updates
    }
    catch {
        Write-Log "Fehler bei Windows Update Suche: $_" -Level "ERROR"
        return @()
    }
}

function Install-WindowsUpdatesAll {
    Write-Log "=== WINDOWS UPDATES INSTALLIEREN ===" -Level "INFO"
    
    # Methode 1: PSWindowsUpdate
    if (Test-WindowsUpdateModule) {
        try {
            Import-Module PSWindowsUpdate -ErrorAction Stop
            
            if ($script:DryRun) {
                Write-Log "[DRY-RUN] Wuerde Windows Updates installieren" -Level "DRYRUN"
                $updates = Get-WindowsUpdate
                foreach ($update in $updates) {
                    Write-Log "[DRY-RUN] Wuerde installieren: $($update.Title)" -Level "DRYRUN"
                }
                return
            }
            
            Write-Host ""
            Write-Host "  Installiere Windows Updates..." -ForegroundColor Cyan
            Write-Host "  (Dies kann einige Minuten dauern)" -ForegroundColor Gray
            Write-Host ""
            
            # Updates installieren (ohne automatischen Neustart)
            $result = Install-WindowsUpdate -AcceptAll -IgnoreReboot -ErrorAction Stop
            
            $count = ($result | Measure-Object).Count
            $script:Stats.WindowsUpdates = $count
            Write-Log "Windows Updates installiert: $count" -Level "SUCCESS"
            
            # Neustart-Check (verschiedene Methoden fuer Kompatibilitaet)
            $needsReboot = $false
            try {
                # Methode 1: PSWindowsUpdate
                $needsReboot = Get-WURebootStatus -ErrorAction SilentlyContinue
            }
            catch {
                # Methode 2: Registry Check (Windows 11 kompatibel)
                $rebootRequired = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue
                $needsReboot = $null -ne $rebootRequired
            }
            
            if ($needsReboot) {
                Write-Host ""
                Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
                Write-Host "  |  HINWEIS: Neustart erforderlich                          |" -ForegroundColor Yellow
                Write-Host "  |  Bitte den Computer neu starten um die Installation      |" -ForegroundColor Yellow
                Write-Host "  |  der Windows Updates abzuschliessen.                     |" -ForegroundColor Yellow
                Write-Host "  +----------------------------------------------------------+" -ForegroundColor Yellow
                Write-Log "Neustart erforderlich fuer Windows Updates" -Level "WARNING"
            }
            return
        }
        catch {
            Write-Log "Fehler bei PSWindowsUpdate Installation: $_" -Level "ERROR"
        }
    }
    
    # Methode 2: COM-Objekt Fallback
    try {
        $updates = Get-WindowsUpdatesAvailable
        
        if ($updates.Count -eq 0) {
            Write-Host "  Keine Windows Updates verfuegbar" -ForegroundColor Green
            return
        }
        
        if ($script:DryRun) {
            foreach ($update in $updates) {
                Write-Log "[DRY-RUN] Wuerde installieren: $($update.Title)" -Level "DRYRUN"
            }
            return
        }
        
        Write-Host ""
        Write-Host "  Installiere $($updates.Count) Windows Updates..." -ForegroundColor Cyan
        Write-Host ""
        
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateDownloader = $updateSession.CreateUpdateDownloader()
        $updateInstaller = $updateSession.CreateUpdateInstaller()
        
        # Updates Collection erstellen
        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $updates) {
            $updatesToInstall.Add($update.UpdateObject) | Out-Null
        }
        
        # Download
        Write-Host "  Lade Updates herunter..." -ForegroundColor Gray
        $updateDownloader.Updates = $updatesToInstall
        $downloadResult = $updateDownloader.Download()
        
        # Installation
        Write-Host "  Installiere Updates..." -ForegroundColor Gray
        $updateInstaller.Updates = $updatesToInstall
        $installResult = $updateInstaller.Install()
        
        $script:Stats.WindowsUpdates = $updates.Count
        Write-Log "Windows Updates installiert: $($updates.Count)" -Level "SUCCESS"
        
        if ($installResult.RebootRequired) {
            Write-Host ""
            Write-Host "  HINWEIS: Neustart erforderlich!" -ForegroundColor Yellow
            Write-Log "Neustart erforderlich fuer Windows Updates" -Level "WARNING"
        }
    }
    catch {
        Write-Log "Fehler bei Windows Update Installation: $_" -Level "ERROR"
    }
}

function Show-WindowsUpdates {
    $updates = Get-WindowsUpdatesAvailable
    
    if ($updates.Count -eq 0) {
        Write-Host ""
        Write-Host "  Keine Windows Updates verfuegbar - System ist aktuell!" -ForegroundColor Green
        Write-Host ""
        return
    }
    
    Write-Host ""
    Write-Host "  Verfuegbare Windows Updates: $($updates.Count)" -ForegroundColor White
    Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    
    $index = 1
    foreach ($update in $updates) {
        $title = if ($update.Title) { $update.Title } else { $update.KB }
        $size = if ($update.Size) { " ($($update.Size) MB)" } else { "" }
        $mandatory = if ($update.IsMandatory) { " [WICHTIG]" } else { "" }
        
        Write-Host "  [$index] $title$size$mandatory" -ForegroundColor White
        $index++
    }
    Write-Host ""
}

# ============================================================================
# WINGET FUNKTIONEN
# ============================================================================

function Get-AvailableUpdates {
    param(
        [ValidateSet("winget", "msstore", "all")]
        [string]$Source = "all"
    )
    
    Write-Log "Suche nach verfuegbaren Updates (Quelle: $Source)..." -Level "INFO"
    Write-Host ""
    
    # WinGet Source aktualisieren (kann auf Windows 11 etwas dauern)
    if (-not $script:DryRun) {
        Write-Host "  Aktualisiere Paketquellen (bitte warten)..." -ForegroundColor Gray
        try {
            $null = winget source update --disable-interactivity 2>&1
        }
        catch {
            Write-Log "Warnung: Quellen-Update fehlgeschlagen, fahre fort..." -Level "WARNING"
        }
    }
    
    Write-Host "  Suche nach Updates..." -ForegroundColor Gray
    
    $allUpdates = @()
    
    # WinGet Updates
    if ($Source -eq "winget" -or $Source -eq "all") {
        if ($script:Sources.WinGet) {
            $wingetUpdates = Get-WinGetUpdates -SourceFilter "winget"
            $allUpdates += $wingetUpdates
        }
    }
    
    # Microsoft Store Updates
    if ($Source -eq "msstore" -or $Source -eq "all") {
        if ($script:Sources.MSStore) {
            $storeUpdates = Get-WinGetUpdates -SourceFilter "msstore"
            $allUpdates += $storeUpdates
        }
    }
    
    Write-Host ""
    return $allUpdates
}

function Get-WinGetUpdates {
    param(
        [string]$SourceFilter = ""
    )
    
    $updates = @()
    
    # Build command (Windows 10/11 kompatibel)
    $cmd = "winget upgrade --include-unknown --accept-source-agreements --disable-interactivity"
    if ($SourceFilter) {
        $cmd += " --source $SourceFilter"
    }
    
    # Updates abrufen
    $output = Invoke-Expression $cmd 2>&1
    $lines = $output | ForEach-Object { $_.ToString() }
    
    # Finde Header-Zeile und Trennlinie
    $headerIndex = -1
    $separatorIndex = -1
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Header erkennen (Name, Id, Version in verschiedenen Sprachen)
        if ($line -match 'Name\s+.*Id\s+.*Version' -or 
            $line -match 'Name\s+.*ID\s+.*Version') {
            $headerIndex = $i
        }
        
        # Trennlinie nach Header (nur Bindestriche)
        if ($headerIndex -ge 0 -and $i -eq $headerIndex + 1 -and $line -match '^[-\s]+$') {
            $separatorIndex = $i
            break
        }
    }
    
    if ($separatorIndex -lt 0) {
        # Keine Updates gefunden oder Parsing fehlgeschlagen
        Write-Host ""
        return @()
    }
    
    # Spaltenbreiten aus Header ermitteln
    $headerLine = $lines[$headerIndex]
    
    # Finde Spaltenpositionen
    $nameStart = 0
    $idStart = $headerLine.IndexOf('Id')
    if ($idStart -lt 0) { $idStart = $headerLine.IndexOf('ID') }
    $versionStart = $headerLine.IndexOf('Version')
    $availableStart = $headerLine.IndexOf('Available')
    if ($availableStart -lt 0) { $availableStart = $headerLine.IndexOf('Verfuegbar') }
    if ($availableStart -lt 0) { $availableStart = $headerLine.IndexOf('Verfuegbar') }
    $sourceStart = $headerLine.IndexOf('Source')
    if ($sourceStart -lt 0) { $sourceStart = $headerLine.IndexOf('Quelle') }
    
    # Parse Update-Zeilen
    for ($i = $separatorIndex + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Abbruchbedingungen (Ende der Liste)
        if ($line -match '^\d+\s+(upgrade|Aktualisierung)' -or 
            $line -match 'upgrades?\s+available' -or
            $line -match 'Aktualisierung.*verfuegbar' -or
            [string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        
        # Zeile muss mindestens so lang sein wie die ID-Spalte
        if ($line.Length -lt $versionStart) { continue }
        
        try {
            # Extrahiere Felder basierend auf Spaltenpositionen
            $name = $line.Substring($nameStart, [Math]::Min($idStart - $nameStart, $line.Length - $nameStart)).Trim()
            
            $idLength = $versionStart - $idStart
            $id = if ($line.Length -ge $versionStart) { 
                $line.Substring($idStart, $idLength).Trim() 
            } else { "" }
            
            $versionLength = if ($availableStart -gt 0) { $availableStart - $versionStart } else { 20 }
            $currentVersion = if ($line.Length -ge $versionStart + $versionLength) {
                $line.Substring($versionStart, [Math]::Min($versionLength, $line.Length - $versionStart)).Trim()
            } else { "" }
            
            $newVersion = ""
            if ($availableStart -gt 0 -and $line.Length -gt $availableStart) {
                $availableLength = if ($sourceStart -gt 0) { $sourceStart - $availableStart } else { 20 }
                $newVersion = $line.Substring($availableStart, [Math]::Min($availableLength, $line.Length - $availableStart)).Trim()
            }
            
            $source = ""
            if ($sourceStart -gt 0 -and $line.Length -gt $sourceStart) {
                $source = $line.Substring($sourceStart).Trim()
            }
            
            # Nur gueltige Eintraege hinzufuegen
            if ($id -and $id.Length -gt 2 -and $id -notmatch '^[-\s]+$') {
                $update = [PSCustomObject]@{
                    Name = $name
                    Id = $id
                    CurrentVersion = $currentVersion
                    NewVersion = $newVersion
                    Source = if ($source) { $source } else { "winget" }
                }
                $updates += $update
            }
        } catch {
            # Zeile konnte nicht geparst werden, ueberspringe
            continue
        }
    }
    
    return $updates
}

function Show-Updates {
    param([array]$Updates)
    
    $excludeList = Get-ExcludeList
    
    if ($Updates.Count -eq 0) {
        Write-Host "  Keine Updates verfuegbar - Alles aktuell!" -ForegroundColor Green
        Write-Host ""
        return
    }
    
    # Windows Terminal Warnung anzeigen
    Show-TerminalWarning -Updates $Updates
    
    Write-Host "  Verfuegbare Updates: $($Updates.Count)" -ForegroundColor White
    Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    
    $index = 1
    foreach ($update in $Updates) {
        $isExcluded = $excludeList -contains $update.Id
        $isAutoSkip = Test-AutoSkipPackage -PackageId $update.Id
        
        # Farbcodierung nach Quelle
        $sourceColor = switch ($update.Source) {
            "msstore" { "Magenta" }
            "winget"  { "Cyan" }
            default   { "White" }
        }
        
        $marker = ""
        $nameColor = $sourceColor
        
        if ($isAutoSkip) {
            $marker = " [AUTO-SKIP]"
            $nameColor = "DarkYellow"
        } elseif ($isExcluded) {
            $marker = " [EXCLUDE]"
            $nameColor = "DarkGray"
        }
        
        Write-Host "  [$index] " -NoNewline -ForegroundColor $sourceColor
        Write-Host "$($update.Name)$marker" -ForegroundColor $nameColor
        Write-Host "      $($update.Id) " -NoNewline -ForegroundColor DarkGray
        Write-Host "($($update.Source))" -ForegroundColor $sourceColor
        Write-Host "      $($update.CurrentVersion) -> $($update.NewVersion)" -ForegroundColor Gray
        Write-Host ""
        
        $index++
    }
}

function Install-SingleUpdate {
    param(
        [PSCustomObject]$Update,
        [bool]$Silent = $true
    )
    
    $excludeList = Get-ExcludeList
    
    # Auto-Skip Check (z.B. Windows Terminal)
    if (Test-AutoSkipPackage -PackageId $Update.Id) {
        Write-Log "Uebersprungen (Auto-Skip): $($Update.Name)" -Level "WARNING"
        $script:Stats.Skipped++
        return $true
    }
    
    # Exclude-Check
    if ($excludeList -contains $Update.Id) {
        Write-Log "Uebersprungen (Exclude): $($Update.Name)" -Level "WARNING"
        $script:Stats.Excluded++
        return $true
    }
    
    Write-Log "Aktualisiere: $($Update.Name) ($($Update.CurrentVersion) -> $($Update.NewVersion))" -Level "UPDATE"
    
    if ($script:DryRun) {
        Write-Log "[DRY-RUN] Wuerde aktualisieren: $($Update.Id)" -Level "DRYRUN"
        return $true
    }
    
    try {
        # Desktop-Icons vorher erfassen
        $iconsBefore = Get-DesktopIcons
        $startTime = Get-Date
        
        # WinGet Argumente (Windows 10/11 kompatibel)
        $wingetArgs = @(
            "upgrade",
            "--id", $Update.Id,
            "--accept-source-agreements",
            "--accept-package-agreements",
            "--disable-interactivity",
            "--include-unknown"
        )
        
        if ($Silent) {
            $wingetArgs += "--silent"
        }
        
        # Update ausfuehren
        $result = & winget @wingetArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        # Kurz warten damit Icons erstellt werden
        Start-Sleep -Milliseconds 1000
        
        # Desktop-Icons aufraeumen
        Remove-NewDesktopIcons -IconsBefore $iconsBefore -StartTime $startTime
        
        # Exit-Code auswerten (WinGet spezifisch fuer Windows 10/11)
        # 0 = Erfolg
        # -1978335189 = Keine neuere Version (OK)
        # -1978335212 = Bereits installiert (OK)
        # -1978335215 = Update nicht erforderlich (OK, Win11)
        # -1978335216 = Paket nicht gefunden in Quelle (ignorieren)
        $successCodes = @(0, -1978335189, -1978335212, -1978335215)
        $ignoreCodes = @(-1978335216)
        
        if ($exitCode -in $successCodes) {
            Write-Log "Erfolgreich: $($Update.Name)" -Level "SUCCESS"
            $script:Stats.Updated++
            return $true
        } elseif ($exitCode -in $ignoreCodes) {
            Write-Log "Uebersprungen (nicht in Quelle): $($Update.Name)" -Level "WARNING"
            $script:Stats.Skipped++
            return $true
        } else {
            Write-Log "Fehlgeschlagen: $($Update.Name) (Exit: $exitCode)" -Level "ERROR"
            $script:Stats.Failed++
            return $false
        }
    }
    catch {
        Write-Log "Fehler bei $($Update.Name): $_" -Level "ERROR"
        $script:Stats.Failed++
        return $false
    }
}

function Install-AllUpdates {
    param([bool]$Silent = $true)
    
    Write-Log "=== ALLE UPDATES INSTALLIEREN ===" -Level "INFO"
    
    # Stats zuruecksetzen
    $script:Stats = @{ Updated = 0; Skipped = 0; Failed = 0; Excluded = 0; IconsRemoved = 0; WindowsUpdates = 0 }
    
    $updates = Get-AvailableUpdates
    
    if ($updates.Count -eq 0) {
        Write-Host ""
        Write-Host "  Keine Updates verfuegbar - Alles aktuell!" -ForegroundColor Green
        return
    }
    
    # Windows Terminal Warnung anzeigen
    Show-TerminalWarning -Updates $updates
    
    Write-Host ""
    Write-Host "  $($updates.Count) Updates gefunden" -ForegroundColor White
    Write-Host ""
    
    $total = $updates.Count
    $current = 0
    
    foreach ($update in $updates) {
        $current++
        
        # Fortschrittsanzeige mit Farbcodierung nach Quelle
        $sourceColor = switch ($update.Source) {
            "msstore" { "Magenta" }
            "winget"  { "Cyan" }
            default   { "White" }
        }
        
        Write-Host "  [$current/$total] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($update.Name)" -NoNewline -ForegroundColor $sourceColor
        Write-Host " ($($update.Source))" -ForegroundColor DarkGray
        
        Install-SingleUpdate -Update $update -Silent $Silent
        Write-Host ""
    }
    
    # Zusammenfassung
    Show-Summary
}

function Install-Interactive {
    Write-Log "=== INTERAKTIVER MODUS ===" -Level "INFO"
    
    # Stats zuruecksetzen
    $script:Stats = @{ Updated = 0; Skipped = 0; Failed = 0; Excluded = 0; IconsRemoved = 0; WindowsUpdates = 0 }
    
    $updates = Get-AvailableUpdates
    
    if ($updates.Count -eq 0) {
        Write-Host ""
        Write-Host "  Keine Updates verfuegbar - Alles aktuell!" -ForegroundColor Green
        return
    }
    
    # Windows Terminal Warnung anzeigen
    Show-TerminalWarning -Updates $updates
    
    $excludeList = Get-ExcludeList
    
    Write-Host ""
    foreach ($update in $updates) {
        # Auto-Skip Check (z.B. Windows Terminal)
        if (Test-AutoSkipPackage -PackageId $update.Id) {
            Write-Log "Uebersprungen (Auto-Skip): $($update.Name)" -Level "WARNING"
            $script:Stats.Skipped++
            continue
        }
        
        # Exclude-Check
        if ($excludeList -contains $update.Id) {
            Write-Log "Uebersprungen (Exclude): $($update.Name)" -Level "WARNING"
            $script:Stats.Excluded++
            continue
        }
        
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  $($update.Name)" -ForegroundColor White
        Write-Host "  $($update.Id)" -ForegroundColor DarkGray
        Write-Host "  $($update.CurrentVersion) -> $($update.NewVersion)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [J] Installieren  [N] Ueberspringen  [E] Exclude  [A] Abbrechen" -ForegroundColor Yellow
        Write-Host "  Auswahl: " -NoNewline -ForegroundColor Yellow
        
        $choice = Read-Host
        
        switch ($choice.ToUpper()) {
            "J" {
                Install-SingleUpdate -Update $update -Silent $false
            }
            "N" {
                Write-Log "Uebersprungen: $($update.Name)" -Level "INFO"
                $script:Stats.Skipped++
            }
            "E" {
                Add-ToExcludeList -AppId $update.Id
                $script:Stats.Excluded++
            }
            "A" {
                Write-Log "Abgebrochen durch Benutzer" -Level "WARNING"
                Show-Summary
                return
            }
            default {
                Write-Log "Uebersprungen: $($update.Name)" -Level "INFO"
                $script:Stats.Skipped++
            }
        }
        Write-Host ""
    }
    
    # Zusammenfassung
    Show-Summary
}

function Install-AllExcept {
    Write-Log "=== ALLE AUSSER AUSWAHL ===" -Level "INFO"
    
    # Stats zuruecksetzen
    $script:Stats = @{ Updated = 0; Skipped = 0; Failed = 0; Excluded = 0; IconsRemoved = 0; WindowsUpdates = 0 }
    
    $updates = Get-AvailableUpdates
    
    if ($updates.Count -eq 0) {
        Write-Host ""
        Write-Host "  Keine Updates verfuegbar - Alles aktuell!" -ForegroundColor Green
        return
    }
    
    # Windows Terminal Warnung anzeigen
    Show-TerminalWarning -Updates $updates
    
    # Updates anzeigen mit Nummern
    Write-Host ""
    Write-Host "  Verfuegbare Updates:" -ForegroundColor White
    Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    
    $excludeList = Get-ExcludeList
    
    for ($i = 0; $i -lt $updates.Count; $i++) {
        $update = $updates[$i]
        $num = $i + 1
        $isExcluded = $excludeList -contains $update.Id
        $isAutoSkip = Test-AutoSkipPackage -PackageId $update.Id
        
        # Farbcodierung nach Quelle
        $sourceColor = switch ($update.Source) {
            "msstore" { "Magenta" }
            "winget"  { "Cyan" }
            default   { "White" }
        }
        
        $marker = ""
        $nameColor = $sourceColor
        
        if ($isAutoSkip) {
            $marker = " [AUTO-SKIP]"
            $nameColor = "DarkYellow"
        } elseif ($isExcluded) {
            $marker = " [EXCLUDE]"
            $nameColor = "DarkGray"
        }
        
        Write-Host "  [$num] " -NoNewline -ForegroundColor $sourceColor
        Write-Host "$($update.Name)$marker" -ForegroundColor $nameColor
        Write-Host "      $($update.Id) " -NoNewline -ForegroundColor DarkGray
        Write-Host "($($update.Source))" -ForegroundColor $sourceColor
        Write-Host "      $($update.CurrentVersion) -> $($update.NewVersion)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Legende: " -NoNewline -ForegroundColor DarkGray
    Write-Host "WinGet " -NoNewline -ForegroundColor Cyan
    Write-Host "Store " -NoNewline -ForegroundColor Magenta
    Write-Host "Windows" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Welche Updates sollen UEBERSPRUNGEN werden?" -ForegroundColor Yellow
    Write-Host "  Nummern eingeben, getrennt durch Leerzeichen (z.B. 1 3 5)" -ForegroundColor Gray
    Write-Host "  Oder Enter fuer alle installieren" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Auswahl: " -NoNewline -ForegroundColor Yellow
    
    $skipInput = Read-Host
    $skipNumbers = @()
    
    if ($skipInput) {
        $skipNumbers = $skipInput -split '\s+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    }
    
    Write-Host ""
    Write-Host "  Starte Updates..." -ForegroundColor Cyan
    Write-Host ""
    
    $total = $updates.Count
    $toInstall = $total - $skipNumbers.Count
    $current = 0
    
    for ($i = 0; $i -lt $updates.Count; $i++) {
        $update = $updates[$i]
        $num = $i + 1
        
        # Soll dieses Update uebersprungen werden?
        if ($skipNumbers -contains $num) {
            Write-Log "Uebersprungen (Auswahl): $($update.Name)" -Level "INFO"
            $script:Stats.Skipped++
            continue
        }
        
        $current++
        
        # Fortschrittsanzeige mit Farbcodierung
        $sourceColor = switch ($update.Source) {
            "msstore" { "Magenta" }
            "winget"  { "Cyan" }
            default   { "White" }
        }
        
        Write-Host "  [$current/$toInstall] " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($update.Name)" -NoNewline -ForegroundColor $sourceColor
        Write-Host " ($($update.Source))" -ForegroundColor DarkGray
        
        Install-SingleUpdate -Update $update -Silent $true
        Write-Host ""
    }
    
    # Zusammenfassung
    Show-Summary
}

function Show-Summary {
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host "              ZUSAMMENFASSUNG" -ForegroundColor Cyan
    Write-Host "  ==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Aktualisiert:      $($script:Stats.Updated)" -ForegroundColor Green
    Write-Host "  Uebersprungen:     $($script:Stats.Skipped)" -ForegroundColor Gray
    Write-Host "  Excluded:          $($script:Stats.Excluded)" -ForegroundColor Yellow
    Write-Host "  Fehlgeschlagen:    $($script:Stats.Failed)" -ForegroundColor $(if($script:Stats.Failed -gt 0){"Red"}else{"Gray"})
    if ($script:Stats.WindowsUpdates -gt 0) {
        Write-Host "  Windows Updates:   $($script:Stats.WindowsUpdates)" -ForegroundColor Magenta
    }
    if ($script:Stats.IconsRemoved -gt 0 -or $script:CleanDesktopIcons) {
        Write-Host "  Icons entfernt:    $($script:Stats.IconsRemoved)" -ForegroundColor Cyan
    }
    Write-Host ""
    
    Write-Log "Zusammenfassung: $($script:Stats.Updated) aktualisiert, $($script:Stats.Skipped) uebersprungen, $($script:Stats.Excluded) excluded, $($script:Stats.Failed) fehlgeschlagen, $($script:Stats.WindowsUpdates) Windows Updates, $($script:Stats.IconsRemoved) Icons entfernt" -Level "INFO"
}

# ============================================================================
# EXCLUDE-LISTE VERWALTEN
# ============================================================================

function Show-ExcludeMenu {
    while ($true) {
        Show-Header
        Write-Host "  EXCLUDE-LISTE VERWALTEN" -ForegroundColor Yellow
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        
        $excludeList = Get-ExcludeList
        
        if ($excludeList.Count -eq 0) {
            Write-Host "  (Liste ist leer)" -ForegroundColor DarkGray
        } else {
            $index = 1
            foreach ($item in $excludeList) {
                Write-Host "  [$index] $item" -ForegroundColor White
                $index++
            }
        }
        
        Write-Host ""
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [A] App hinzufuegen" -ForegroundColor White
        Write-Host "  [R] App entfernen (Nummer eingeben)" -ForegroundColor White
        Write-Host "  [O] Datei oeffnen" -ForegroundColor White
        Write-Host "  [0] Zurueck" -ForegroundColor DarkGray
        Write-Host ""
        
        $choice = Read-Host "  Auswahl"
        
        switch ($choice.ToUpper()) {
            "A" {
                Show-Header
                Write-Host "  APP ZUR EXCLUDE-LISTE HINZUFUEGEN" -ForegroundColor Yellow
                Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
                Write-Host ""
                Write-Host "  Lade installierte Programme..." -ForegroundColor Gray
                Write-Host "  (kann einen Moment dauern)" -ForegroundColor DarkGray
                
                # Hole alle WinGet-Programme
                $listOutput = winget list --disable-interactivity 2>$null
                $lines = $listOutput -split "`n"
                
                # Finde Trennlinie
                $separatorIndex = -1
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match '^-+') {
                        $separatorIndex = $i
                        break
                    }
                }
                
                if ($separatorIndex -lt 1) {
                    Write-Host ""
                    Write-Host "  Keine Programme gefunden" -ForegroundColor DarkGray
                    Read-Host "  Enter zum Fortfahren"
                    continue
                }
                
                # Parse Header fuer Spalten-Positionen
                $headerLine = $lines[$separatorIndex - 1]
                $nameStart = 0
                $idStart = $headerLine.IndexOf('Id')
                if ($idStart -lt 0) { $idStart = $headerLine.IndexOf('ID') }
                
                # Parse Programme
                $programs = @()
                for ($i = $separatorIndex + 1; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]
                    if ($line -and $line.Length -gt $idStart) {
                        $name = $line.Substring($nameStart, [Math]::Min($idStart, $line.Length)).Trim()
                        $rest = $line.Substring([Math]::Min($idStart, $line.Length - 1)).Trim()
                        $parts = $rest -split '\s+'
                        $id = $parts[0]
                        
                        if ($name -and $id -and $id -notmatch '^-+$') {
                            $programs += [PSCustomObject]@{
                                Name = $name
                                Id = $id
                            }
                        }
                    }
                }
                
                if ($programs.Count -eq 0) {
                    Write-Host ""
                    Write-Host "  Keine Programme gefunden" -ForegroundColor DarkGray
                    Read-Host "  Enter zum Fortfahren"
                    continue
                }
                
                # Seitenweise Anzeige
                $pageSize = 15
                $page = 0
                $totalPages = [Math]::Ceiling($programs.Count / $pageSize)
                
                while ($true) {
                    Show-Header
                    Write-Host "  PROGRAMM AUSWAEHLEN (Seite $($page + 1)/$totalPages)" -ForegroundColor Yellow
                    Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
                    Write-Host ""
                    
                    $startIdx = $page * $pageSize
                    $endIdx = [Math]::Min($startIdx + $pageSize, $programs.Count)
                    
                    for ($i = $startIdx; $i -lt $endIdx; $i++) {
                        $prog = $programs[$i]
                        $num = $i + 1
                        Write-Host "  [$num] $($prog.Name)" -ForegroundColor White
                        Write-Host "      $($prog.Id)" -ForegroundColor DarkGray
                    }
                    
                    Write-Host ""
                    Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
                    Write-Host "  [N] Naechste Seite  [V] Vorherige Seite" -ForegroundColor DarkGray
                    Write-Host "  [0] Zurueck" -ForegroundColor DarkGray
                    Write-Host ""
                    Write-Host "  Nummer oder Befehl: " -NoNewline -ForegroundColor Yellow
                    $selection = Read-Host
                    
                    if ($selection.ToUpper() -eq "N" -and $page -lt $totalPages - 1) {
                        $page++
                    }
                    elseif ($selection.ToUpper() -eq "V" -and $page -gt 0) {
                        $page--
                    }
                    elseif ($selection -eq "0") {
                        break
                    }
                    elseif ($selection -match '^\d+$') {
                        $idx = [int]$selection - 1
                        if ($idx -ge 0 -and $idx -lt $programs.Count) {
                            $selectedProg = $programs[$idx]
                            Add-ToExcludeList -AppId $selectedProg.Id
                            Write-Host ""
                            Write-Host "  '$($selectedProg.Id)' zur Exclude-Liste hinzugefuegt" -ForegroundColor Green
                            Start-Sleep -Seconds 1
                        }
                    }
                }
            }
            "R" {
                Write-Host ""
                Write-Host "  Nummer zum Entfernen: " -NoNewline -ForegroundColor Yellow
                $num = Read-Host
                if ($num -match '^\d+$') {
                    $idx = [int]$num - 1
                    if ($idx -ge 0 -and $idx -lt $excludeList.Count) {
                        Remove-FromExcludeList -AppId $excludeList[$idx]
                    }
                }
                Start-Sleep -Seconds 1
            }
            "O" {
                if (Test-Path $script:ExcludeFile) {
                    Start-Process notepad.exe -ArgumentList $script:ExcludeFile
                } else {
                    Write-Host "  Keine Exclude-Datei vorhanden" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            "0" {
                return
            }
        }
    }
}

# ============================================================================
# HAUPTMENUE
# ============================================================================

function Show-Menu {
    # WinGet pruefen
    if (-not (Test-WinGet)) {
        Read-Host "  Enter zum Beenden"
        return
    }
    
    # Admin-Hinweis
    if (-not (Test-AdminRights)) {
        Write-Host "  HINWEIS: Ohne Admin-Rechte koennen manche Updates fehlschlagen" -ForegroundColor Yellow
        Write-Host ""
    }
    
    while ($true) {
        Show-Header
        
        # Quellen-Status
        $sourceStatus = @()
        if ($script:Sources.WinGet) { $sourceStatus += "WinGet" }
        if ($script:Sources.MSStore) { $sourceStatus += "Store" }
        if ($script:Sources.WindowsUpdate) { $sourceStatus += "Windows" }
        Write-Host "  Quellen: $($sourceStatus -join ', ')" -ForegroundColor DarkGray
        Write-Host ""
        
        Write-Host "  [1] Alles aktualisieren" -ForegroundColor Green
        Write-Host "      Alle Updates ohne Nachfrage" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [2] Updates anzeigen" -ForegroundColor White
        Write-Host "      Verfuegbare Updates auflisten" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [3] Auswahl" -ForegroundColor White
        Write-Host "      Bestimmte Updates ausschliessen" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [E] Einstellungen" -ForegroundColor DarkGray
        Write-Host "  [L] Log-Datei oeffnen" -ForegroundColor DarkGray
        Write-Host "  [0] Beenden" -ForegroundColor DarkGray
        Write-Host ""
        
        $choice = Read-Host "  Auswahl"
        
        switch ($choice.ToUpper()) {
            "1" {
                # Alles aktualisieren ohne Nachfrage
                Show-Header
                Write-Host "  === ALLE UPDATES INSTALLIEREN ===" -ForegroundColor Green
                Write-Host ""
                
                # WinGet/Store Updates
                if ($script:Sources.WinGet -or $script:Sources.MSStore) {
                    Install-AllUpdates -Silent $true
                }
                
                # Windows Updates
                if ($script:Sources.WindowsUpdate) {
                    Write-Host ""
                    Write-Host "  === WINDOWS UPDATES ===" -ForegroundColor Yellow
                    Install-WindowsUpdatesAll
                }
                
                Show-Summary
                
                Write-Host ""
                Read-Host "  Enter zum Fortfahren"
            }
            "2" {
                Show-Header
                Write-Host "  === VERFUEGBARE UPDATES ===" -ForegroundColor Cyan
                Write-Host ""
                
                # WinGet/Store Updates
                $updates = Get-AvailableUpdates
                Show-Updates -Updates $updates
                
                # Windows Updates anzeigen
                if ($script:Sources.WindowsUpdate) {
                    Write-Host "  === WINDOWS UPDATES ===" -ForegroundColor Yellow
                    Show-WindowsUpdates
                }
                
                Read-Host "  Enter zum Fortfahren"
            }
            "3" {
                Show-Header
                Install-AllExcept
                
                Write-Host ""
                Read-Host "  Enter zum Fortfahren"
            }
            "E" {
                Show-SettingsMenu
            }
            "L" {
                if (Test-Path $script:LogFile) {
                    Start-Process notepad.exe -ArgumentList $script:LogFile
                } else {
                    Write-Host "  Keine Log-Datei vorhanden" -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                }
            }
            "0" {
                Write-Host ""
                Write-Host "  Auf Wiedersehen!" -ForegroundColor Cyan
                Write-Host ""
                return
            }
        }
    }
}

# ============================================================================
# EINSTELLUNGEN-MENU
# ============================================================================

function Show-SettingsMenu {
    while ($true) {
        Show-Header
        Write-Host "  EINSTELLUNGEN" -ForegroundColor Yellow
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [Q] Quellen konfigurieren" -ForegroundColor White
        Write-Host "  [X] Exclude-Liste verwalten" -ForegroundColor White
        Write-Host "  [I] Desktop-Icons loeschen: $(if($script:CleanDesktopIcons){'EIN'}else{'AUS'})" -ForegroundColor $(if($script:CleanDesktopIcons){'Green'}else{'DarkGray'})
        Write-Host "  [D] Dry-Run Modus: $(if($script:DryRun){'EIN'}else{'AUS'})" -ForegroundColor $(if($script:DryRun){'Cyan'}else{'DarkGray'})
        Write-Host ""
        Write-Host "  [0] Zurueck" -ForegroundColor DarkGray
        Write-Host ""
        
        $choice = Read-Host "  Auswahl"
        
        switch ($choice.ToUpper()) {
            "Q" {
                Show-SourcesMenu
            }
            "X" {
                Show-ExcludeMenu
            }
            "I" {
                $script:CleanDesktopIcons = -not $script:CleanDesktopIcons
                $status = if ($script:CleanDesktopIcons) { "aktiviert" } else { "deaktiviert" }
                Write-Log "Desktop-Icon Bereinigung $status" -Level "INFO"
            }
            "D" {
                $script:DryRun = -not $script:DryRun
                $status = if ($script:DryRun) { "aktiviert" } else { "deaktiviert" }
                Write-Log "Dry-Run Modus $status" -Level "INFO"
            }
            "0" {
                return
            }
        }
    }
}

# ============================================================================
# QUELLEN-MENU
# ============================================================================

function Show-SourcesMenu {
    while ($true) {
        Show-Header
        Write-Host "  QUELLEN KONFIGURIEREN" -ForegroundColor Yellow
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  Waehle welche Update-Quellen aktiv sein sollen:" -ForegroundColor Gray
        Write-Host ""
        
        $wingetStatus = if ($script:Sources.WinGet) { "[X]" } else { "[ ]" }
        $storeStatus = if ($script:Sources.MSStore) { "[X]" } else { "[ ]" }
        $windowsStatus = if ($script:Sources.WindowsUpdate) { "[X]" } else { "[ ]" }
        
        Write-Host "  [1] $wingetStatus WinGet (Programme)" -ForegroundColor $(if($script:Sources.WinGet){'Green'}else{'Gray'})
        Write-Host "      Installierte Programme aus dem WinGet Repository" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [2] $storeStatus Microsoft Store" -ForegroundColor $(if($script:Sources.MSStore){'Green'}else{'Gray'})
        Write-Host "      Apps aus dem Microsoft Store" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  [3] $windowsStatus Windows Updates" -ForegroundColor $(if($script:Sources.WindowsUpdate){'Green'}else{'Gray'})
        Write-Host "      System-Updates von Microsoft" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  ------------------------------------------" -ForegroundColor DarkGray
        Write-Host "  [A] Alle aktivieren" -ForegroundColor DarkGray
        Write-Host "  [N] Alle deaktivieren" -ForegroundColor DarkGray
        Write-Host "  [0] Zurueck" -ForegroundColor DarkGray
        Write-Host ""
        
        $choice = Read-Host "  Auswahl"
        
        switch ($choice.ToUpper()) {
            "1" {
                $script:Sources.WinGet = -not $script:Sources.WinGet
                $status = if ($script:Sources.WinGet) { "aktiviert" } else { "deaktiviert" }
                Write-Log "WinGet Quelle $status" -Level "INFO"
            }
            "2" {
                $script:Sources.MSStore = -not $script:Sources.MSStore
                $status = if ($script:Sources.MSStore) { "aktiviert" } else { "deaktiviert" }
                Write-Log "Microsoft Store Quelle $status" -Level "INFO"
            }
            "3" {
                $script:Sources.WindowsUpdate = -not $script:Sources.WindowsUpdate
                $status = if ($script:Sources.WindowsUpdate) { "aktiviert" } else { "deaktiviert" }
                Write-Log "Windows Update Quelle $status" -Level "INFO"
            }
            "A" {
                $script:Sources.WinGet = $true
                $script:Sources.MSStore = $true
                $script:Sources.WindowsUpdate = $true
                Write-Log "Alle Quellen aktiviert" -Level "INFO"
            }
            "N" {
                $script:Sources.WinGet = $false
                $script:Sources.MSStore = $false
                $script:Sources.WindowsUpdate = $false
                Write-Log "Alle Quellen deaktiviert" -Level "WARNING"
            }
            "0" {
                return
            }
        }
    }
}

# ============================================================================
# START
# ============================================================================

# Log initialisieren
Write-Log "=== Androidy Update v$script:Version gestartet ===" -Level "INFO"

# Menue anzeigen
Show-Menu

# Log beenden
Write-Log "=== Androidy Update beendet ===" -Level "INFO"
