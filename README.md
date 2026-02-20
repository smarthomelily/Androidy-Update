# Androidy Update

<p align="center">
  <img src="Androidy-Update.png" width="200">
</p>

[![GitHub](https://img.shields.io/badge/GitHub-smarthomelily-181717?logo=github)](https://github.com/smarthomelily/Androidy-Update)
![Version](https://img.shields.io/badge/Version-1.1-cyan)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue.svg)
![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)

**Update-Zentrale für Windows — WinGet, Microsoft Store und Windows Updates in einem Tool.**

Androidy Update ist Teil der [Androidy Toolsuite](https://github.com/smarthomelily) von *smarthomelily* — schlank, direkt, ohne Installation. Einfach entpacken und starten.

---

## Voraussetzungen

- **Windows 10** (Build 1809+) oder **Windows 11**
- **WinGet** — Teil des *App Installer* aus dem Microsoft Store → [Jetzt installieren](https://aka.ms/getwinget)
- **Administrator-Rechte** — für System-Updates und manche Programm-Updates erforderlich
- **PowerShell 5.1** — auf allen unterstützten Windows-Versionen vorinstalliert

---

## Installation

1. [Neueste Version herunterladen](https://github.com/smarthomelily/Androidy-Update/releases/latest)
2. Alle Dateien in einen Ordner entpacken
3. `Androidy-Update-v1.1.bat` per Doppelklick starten

### Desktop-Verknüpfung erstellen

**Automatisch:**
`Androidy-Update-v1.1-Verknuepfung.bat` ausführen — erstellt den Shortcut direkt auf dem Desktop.

**Manuell:**
1. Rechtsklick auf `Androidy-Update-v1.1.bat` → "Verknüpfung erstellen"
2. Verknüpfung auf Desktop verschieben
3. Rechtsklick auf Verknüpfung → "Eigenschaften"
4. "Anderes Symbol" → `Androidy-Update-v1.1.ico` auswählen
5. "Erweitert" → "Als Administrator ausführen" aktivieren

---

## Benutzung

```
==========================================
    ANDROIDY UPDATE v1.1
              Update-Zentrale
==========================================

  Quellen: WinGet, Store, Windows

  [1] Alles aktualisieren
      Alle Updates ohne Nachfrage

  [2] Updates anzeigen
      Verfuegbare Updates auflisten

  [3] Auswahl
      Bestimmte Updates ausschliessen

  ------------------------------------------
  [E] Einstellungen
  [L] Log-Datei oeffnen
  [0] Beenden
```

### [1] Alles aktualisieren
Ein Tastendruck startet alle Updates ohne weitere Nachfragen. WinGet, Store und Windows Updates werden nacheinander abgearbeitet.

### Fortschrittsanzeige
```
  [3/12] VLC Media Player (winget)
```

### Farbcodierung
Updates werden nach Quelle farblich markiert:
- **Cyan** = WinGet (Programme)
- **Magenta** = Microsoft Store
- **Gelb** = Windows Updates
- **DarkYellow** = Auto-Skip (z.B. Windows Terminal)
- **DarkGray** = Excluded

---

## Funktionen

### Drei Update-Quellen
- **WinGet** — Installierte Programme aus dem WinGet Repository
- **Microsoft Store** — Apps aus dem Microsoft Store
- **Windows Updates** — System-Updates von Microsoft

### Updates anzeigen
Listet alle verfügbaren Updates auf. Zeigt Quelle, aktuelle Version, neue Version. Excludierte Apps werden mit `[EXCLUDE]`, automatisch übersprungene mit `[AUTO-SKIP]` markiert.

### Alle Updates installieren
Automatische Installation aller Updates im Silent-Modus ohne Dialoge. Alle drei Quellen in einem Durchgang.

### Auswahl
Zeigt alle Updates mit Nummern an. Nummern der zu überspringenden Updates eingeben — der Rest wird automatisch installiert.

### Desktop-Icon Bereinigung
Erkennt neue Desktop-Icons die während eines Updates erstellt werden und löscht sie automatisch. Kann in den Einstellungen ein- und ausgeschaltet werden. Standard: **EIN**.

### Windows Terminal Handling
Erkennt wenn ein Windows Terminal Update verfügbar ist und zeigt einen Warnhinweis — das Terminal kann sich nicht selbst aktualisieren während es läuft. Das Update wird automatisch übersprungen.

### Exclude-Liste
Apps dauerhaft von automatischen Updates ausschließen. Verwaltung über das Einstellungsmenü oder direkt in der Datei `Androidy-Update-Exclude.txt`.

```
# Androidy Update - Exclude Liste
# Eine App-ID pro Zeile
Microsoft.Edge
Valve.Steam
```

### Quellen-Konfiguration
Jede der drei Quellen (WinGet, Store, Windows) kann einzeln aktiviert oder deaktiviert werden.

### Dry-Run Modus
Protokolliert was passieren *würde* — keine Datei wird verändert, kein Update installiert. Ideal zum Testen. Standard: **AUS**.

---

## Selfupdate

Androidy Update prüft beim Start automatisch ob eine neuere Version auf GitHub verfügbar ist.

**Ablauf:**
1. GitHub Releases API wird abgefragt (Timeout 3 Sekunden)
2. Neue Version gefunden → Rückfrage `[J/N]`
3. Bei `J`: ZIP wird heruntergeladen, Backup des aktuellen Ordners angelegt, Dateien ersetzt, Tool startet neu
4. Bei `N` oder kein Internet: Tool startet normal, kein Fehler

**Backup:** Vor jedem Update wird der aktuelle Ordner als `Androidy-Update_backup_YYYYMMDD_HHmmss` gesichert — im übergeordneten Verzeichnis.

---

## Enthaltene Dateien

| Datei | Beschreibung |
|---|---|
| `Androidy-Update-v1.1.bat` | Starter (Doppelklick) |
| `Androidy-Update-v1.1.ps1` | Hauptskript |
| `Androidy-Updater.ps1` | Selfupdate-Modul |
| `Androidy-Update-v1.1-Verknuepfung.bat` | Erstellt Desktop-Verknüpfung |
| `Androidy-Update-v1.1-Verknuepfung.ps1` | PowerShell-Skript für Verknüpfung |
| `Androidy-Update-v1.1.ico` | Icon für Verknüpfungen |

Laufzeit-Dateien (werden automatisch erstellt):

| Datei | Inhalt |
|---|---|
| `Androidy-Update.log` | Protokoll aller Aktionen |
| `Androidy-Update-Exclude.txt` | Exclude-Liste |

---

## Teil der Androidy-Familie

| Tool | Beschreibung |
|---|---|
| [Androidy Clean](https://github.com/smarthomelily/Androidy-Clean) | Windows Cleaning & Privacy Tool |
| [Androidy Install](https://github.com/smarthomelily/Androidy-Install) | WinGet Installer |
| [Androidy Update](https://github.com/smarthomelily/Androidy-Update) | Windows Update Tool |
| **Androidy Move** | PC-Migration & Datensicherung *(coming soon)* |

---

## Changelog

### v1.1 — 2026-02-19
- **NEU:** Selfupdate — automatische Versionsprüfung beim Start via GitHub Releases API
- **NEU:** `Androidy-Updater.ps1` — gemeinsames Selfupdate-Modul für alle Androidy-Tools, inkl. ZIP-Download, Backup und automatischem Neustart
- **NEU:** Backup vor jedem Selfupdate
- **Geändert:** `Androidy-Update.bat` — Versionsnummer und Hauptskript werden jetzt dynamisch ermittelt, keine hardcodierten Pfade mehr

### v1.0 — 2026-01-18
- Erstveröffentlichung
- WinGet, Microsoft Store und Windows Updates in einem Tool
- Exclude-Liste, Desktop-Icon-Bereinigung, Dry-Run Modus
- Windows Terminal Auto-Skip

---

## Lizenz

GPL v3 License — [https://www.gnu.org/licenses/gpl-3.0](https://www.gnu.org/licenses/gpl-3.0)

**Kurzfassung:** Du darfst das Tool frei nutzen, auch kommerziell. Wenn du es veränderst oder erweiterst, muss deine Version auch Open Source unter GPL v3 bleiben.

---

## Autor

**smarthomelily**

---

⭐ Wenn dir das Tool gefällt, gib dem Projekt einen Stern!
