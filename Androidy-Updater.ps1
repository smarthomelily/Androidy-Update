<#
.SYNOPSIS
    Androidy Updater v1.0 - Selfupdate-Modul fuer alle Androidy-Tools
.DESCRIPTION
    Universelles Selfupdate-Modul. Wird von der jeweiligen .bat vor dem Start
    der Hauptanwendung aufgerufen. Prueft GitHub Releases auf neue Versionen.

    Ablauf:
      1. GitHub Releases API abfragen (Timeout 3s)
      2. Versionen vergleichen
      3. Bei neuer Version: Benutzer fragen [J/N]
      4. Bei J: ZIP laden, Backup anlegen, Dateien ersetzen, Tool neu starten
      5. Bei N oder kein Internet: Exit 0, Tool startet normal

    Exit-Codes:
       0  = Kein Update / abgelehnt / kein Internet -> .bat startet Hauptanwendung
      99  = Update installiert, Helper-Bat laeuft -> .bat beendet sich sofort

    Integration in neue Tools:
      Siehe Androidy-Updater-Integration.md

.PARAMETER RepoOwner
    GitHub-Nutzername oder Organisation (z.B. "smarthomelily")

.PARAMETER RepoName
    GitHub-Repository-Name (z.B. "Androidy-Update")

.PARAMETER CurrentVersion
    Aktuell installierte Version als String (z.B. "1.1")
    Wird von der .bat dynamisch aus $script:Version der Haupt-PS1 ausgelesen.

.PARAMETER InstallDir
    Vollstaendiger Pfad zum Installationsordner (Ordner der .bat-Datei).
    Wird gesichert (Backup) und dann mit neuen Dateien ueberschrieben.

.PARAMETER RestartBat
    Vollstaendiger Pfad zur .bat-Datei die nach dem Update neu gestartet wird.

.AUTHOR
    smarthomelily
.VERSION
    1.0
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

param(
    [Parameter(Mandatory = $true)]
    [string]$RepoOwner,      # GitHub-Nutzer, z.B. "smarthomelily"

    [Parameter(Mandatory = $true)]
    [string]$RepoName,       # Repository-Name, z.B. "Androidy-Update"

    [Parameter(Mandatory = $true)]
    [string]$CurrentVersion, # Aktuelle Version, z.B. "1.1"

    [Parameter(Mandatory = $true)]
    [string]$InstallDir,     # Installationsordner, z.B. "C:\Tools\Androidy-Update\"

    [Parameter(Mandatory = $true)]
    [string]$RestartBat      # Pfad zur .bat die nach Update neu gestartet wird
)

# ============================================================================
# KONFIGURATION
# ============================================================================

# Versionsnummer des Updater-Moduls selbst.
# Wird bei Weiterentwicklung erhoeht und in jedem Tool-Release mitgeliefert.
# Kein eigenes Repository — der Updater ist Bestandteil jedes Androidy-Tool-Releases.
$script:UpdaterVersion = "1.0"

# API-Timeout in Millisekunden — kurz halten damit kein haengender Start entsteht
$script:TimeoutMs = 3000

# Temporaere Arbeitsordner im Windows TEMP-Verzeichnis
$script:TempDir   = Join-Path $env:TEMP "androidy_update_$RepoName"
$script:HelperBat = Join-Path $env:TEMP "androidy_helper_$RepoName.bat"

# GitHub API URL fuer das neueste Release
$script:ApiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"

# Encoding auf UTF-8 setzen
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

function Write-UpdateInfo {
    # Einheitliche Ausgabe mit 2-Space-Einrueckung (Androidy Design-System)
    param([string]$Message, [string]$Color = "White")
    Write-Host "  $Message" -ForegroundColor $Color
}

function Get-LatestRelease {
    # GitHub API abfragen mit hartem Timeout.
    # Gibt $null zurueck bei Fehler, Timeout oder kein Internet — kein Absturz.
    try {
        $request           = [System.Net.WebRequest]::Create($script:ApiUrl)
        $request.Timeout   = $script:TimeoutMs
        $request.UserAgent = "Androidy-Updater/1.0"
        $request.Method    = "GET"

        $response = $request.GetResponse()
        $reader   = New-Object System.IO.StreamReader($response.GetResponseStream())
        $json     = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()

        return ($json | ConvertFrom-Json)
    }
    catch {
        # Kein Internet, DNS-Fehler, Timeout — alle Faelle stumm ignorieren
        return $null
    }
}

function Compare-Versions {
    # Vergleicht zwei Versionsstrings. Gibt $true zurueck wenn $Latest > $Current.
    # Fuehrendes "v" wird automatisch entfernt (z.B. "v1.1" -> "1.1").
    param([string]$Current, [string]$Latest)
    try {
        $c = [Version]($Current -replace '^v', '')
        $l = [Version]($Latest  -replace '^v', '')
        return $l -gt $c
    }
    catch {
        # Ungueltiges Versionsformat — kein Update erzwingen
        return $false
    }
}

function Get-DownloadUrl {
    # Ermittelt die Download-URL aus dem Release-Objekt.
    # Bevorzugt echte ZIP-Assets, faellt zurueck auf zipball_url (GitHub-generiert).
    param($Release)

    $asset = $Release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    if ($asset) {
        return $asset.browser_download_url
    }
    # Fallback: GitHub-generierter Quellcode-ZIP
    return $Release.zipball_url
}

function Download-Zip {
    # Laedt ZIP herunter. Gibt $true bei Erfolg, $false bei Fehler.
    param([string]$Url, [string]$Destination)
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Androidy-Updater/1.0")
        $webClient.DownloadFile($Url, $Destination)
        return $true
    }
    catch {
        return $false
    }
}

function Expand-ZipToTemp {
    # Entpackt ZIP in $OutDir.
    # Loest GitHub-typischen Unterordner (owner-repo-commithash) automatisch auf,
    # so dass die Dateien direkt in $OutDir liegen.
    param([string]$ZipPath, [string]$OutDir)
    try {
        if (Test-Path $OutDir) {
            Remove-Item $OutDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $OutDir)

        # GitHub zipball enthaelt einen Unterordner "owner-repo-hash" — eine Ebene aufloesen
        $subDirs = Get-ChildItem $OutDir -Directory
        if ($subDirs.Count -eq 1) {
            $inner = $subDirs[0].FullName
            Get-ChildItem $inner | Move-Item -Destination $OutDir -Force
            Remove-Item $inner -Recurse -Force -ErrorAction SilentlyContinue
        }

        return $true
    }
    catch {
        return $false
    }
}

function New-Backup {
    # Legt Backup des aktuellen Installationsordners an.
    # Backup-Name: <Ordnername>_backup_YYYYMMDD_HHmmss
    # Gibt den Backup-Pfad bei Erfolg zurueck, $null bei Fehler.
    param([string]$SourceDir)
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = "${SourceDir}_backup_$timestamp"

        Copy-Item -Path $SourceDir -Destination $backupDir -Recurse -Force
        return $backupDir
    }
    catch {
        return $null
    }
}

function New-HelperBat {
    # Erstellt eine temporaere Helper-Bat die:
    #   1. 3 Sekunden wartet (bis PS1 sauber beendet ist)
    #   2. Neue Dateien per xcopy in den Zielordner kopiert
    #   3. Temp-Ordner aufrauemt
    #   4. Das Tool (RestartBat) neu startet
    #   5. Sich selbst loescht
    #
    # Hintergrund: Eine laufende PS1 kann sich nicht selbst ersetzen.
    # Die Helper-Bat laeuft als separater Prozess und uebernimmt das Kopieren
    # nachdem das PS1-Skript beendet wurde.
    param(
        [string]$SourceDir,  # Entpacktes ZIP (Temp)
        [string]$TargetDir,  # Installationsordner
        [string]$RestartBat, # Tool das nach Update neu gestartet wird
        [string]$HelperPath  # Pfad wo die Helper-Bat abgelegt wird
    )

    $bat = @"
@echo off
chcp 65001 >nul 2>&1
:: Warten bis aufrufendes PS1-Skript beendet ist
timeout /t 3 /nobreak >nul

:: Neue Dateien in Installationsordner kopieren (ueberschreiben)
xcopy /E /Y /I "$SourceDir\*" "$TargetDir\" >nul 2>&1

:: Temporaeren Entpackordner loeschen
rd /s /q "$SourceDir" >nul 2>&1

:: Tool neu starten
start "" "$RestartBat"

:: Helper-Bat loescht sich selbst
del "%~f0"
"@

    $bat | Out-File -FilePath $HelperPath -Encoding ascii
}

# ============================================================================
# HAUPTABLAUF
# ============================================================================

# --- Schritt 1: GitHub API abfragen ---
$release = Get-LatestRelease

if ($null -eq $release) {
    # Kein Internet, Timeout oder API-Fehler — stumm beenden
    # Die .bat wertet Exit 0 aus und startet die Hauptanwendung normal
    exit 0
}

# --- Schritt 2: Versionen vergleichen ---
$latestTag       = $release.tag_name
$updateAvailable = Compare-Versions -Current $CurrentVersion -Latest $latestTag

if (-not $updateAvailable) {
    # Bereits aktuell — stumm beenden
    exit 0
}

# --- Schritt 3: Benutzer fragen ---
$latestClean = $latestTag -replace '^v', ''

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "      ANDROIDY UPDATE VERFUEGBAR" -ForegroundColor Cyan
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""
Write-UpdateInfo "Installiert :  v$CurrentVersion" "Gray"
Write-UpdateInfo "Verfuegbar  :  v$latestClean" "Green"
Write-Host ""
Write-Host "  Jetzt aktualisieren? [J/N]: " -NoNewline -ForegroundColor Yellow
$answer = Read-Host

if ($answer.ToUpper() -ne "J") {
    Write-Host ""
    exit 0
}

# --- Schritt 4: Download ---
Write-Host ""
Write-UpdateInfo "Lade v$latestClean herunter..." "Cyan"

$downloadUrl = Get-DownloadUrl -Release $release
$zipPath     = Join-Path $env:TEMP "androidy_${RepoName}_${latestClean}.zip"

$downloaded = Download-Zip -Url $downloadUrl -Destination $zipPath

if (-not $downloaded) {
    Write-UpdateInfo "Download fehlgeschlagen. Starte normal..." "Yellow"
    Write-Host ""
    exit 0
}

# --- Schritt 5: Entpacken ---
Write-UpdateInfo "Entpacke..." "Cyan"

$extracted = Expand-ZipToTemp -ZipPath $zipPath -OutDir $script:TempDir

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

if (-not $extracted) {
    Write-UpdateInfo "Entpacken fehlgeschlagen. Starte normal..." "Yellow"
    Write-Host ""
    exit 0
}

# --- Schritt 6: Backup anlegen ---
Write-UpdateInfo "Erstelle Backup..." "Cyan"

$backupPath = New-Backup -SourceDir $InstallDir

if ($null -eq $backupPath) {
    Write-UpdateInfo "Backup fehlgeschlagen. Starte normal..." "Yellow"
    Write-Host ""
    exit 0
}

Write-UpdateInfo "Backup: $backupPath" "Gray"

# --- Schritt 7: Helper-Bat erstellen und als versteckten Prozess starten ---
Write-UpdateInfo "Installiere Update..." "Cyan"

New-HelperBat `
    -SourceDir  $script:TempDir `
    -TargetDir  $InstallDir `
    -RestartBat $RestartBat `
    -HelperPath $script:HelperBat

# Als verstecktes Fenster starten — Benutzer sieht nichts
Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($script:HelperBat)`"" -WindowStyle Hidden

Write-Host ""
Write-UpdateInfo "Update wird installiert - Tool startet neu..." "Green"
Write-Host ""
Start-Sleep -Seconds 1

# --- Schritt 8: Exit 99 ---
# Signalisiert der .bat: Update laeuft, Hauptanwendung NICHT starten.
# Die .bat prueft diesen Exit-Code und beendet sich sofort.
exit 99
