# Androidy Update v1.0

<p align="center">
  <img src="Androidy-Update-v1.0.png" width="200">
</p>

Ein umfassendes Windows Update Tool fuer Windows 10/11.
Aktualisiert WinGet-Programme, Microsoft Store Apps und Windows Updates.

[![GitHub](https://img.shields.io/badge/GitHub-smarthomelily-181717?logo=github)](https://github.com/smarthomelily/Androidy-Update)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue.svg)
![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)

## Features

### Drei Update-Quellen
- **WinGet** - Installierte Programme aus dem WinGet Repository
- **Microsoft Store** - Apps aus dem Microsoft Store
- **Windows Updates** - System-Updates von Microsoft

### Updates anzeigen
- Listet alle verfuegbaren Updates auf
- Zeigt aktuelle und neue Version
- Markiert excludierte Apps mit [EXCLUDE]
- Markiert Auto-Skip Apps mit [AUTO-SKIP]

### Alle Updates installieren
- Automatische Installation aller Updates
- Silent-Modus (keine Dialoge)
- Alle drei Quellen in einem Durchgang

### Interaktiver Modus
- Jedes Update einzeln bestaetigen
- Direkt zur Exclude-Liste hinzufuegen
- Ueberspringen einzelner Updates

### Alle ausser Auswahl
- Liste aller Updates anzeigen
- Nummern eingeben die uebersprungen werden sollen
- Rest wird automatisch installiert

### Nur Windows Updates
- Dedizierte Option fuer System-Updates
- Optional: PSWindowsUpdate Modul Installation
- Neustart-Hinweis wenn erforderlich

### Desktop-Icon Bereinigung
- Erkennt neue Desktop-Icons nach Updates
- Loescht automatisch neu erstellte Verknuepfungen
- Kann im Menue ein-/ausgeschaltet werden

### Windows Terminal Handling
- Erkennt wenn Windows Terminal Update verfuegbar
- Zeigt Warnhinweis (kann sich nicht selbst updaten)
- Ueberspringt automatisch, empfiehlt Microsoft Store

### Exclude-Liste
- Apps von automatischen Updates ausschliessen
- Einfache Verwaltung ueber Menue
- Wird als Textdatei gespeichert

### Quellen-Konfiguration
- Jede Quelle einzeln aktivierbar/deaktivierbar
- Schnelle Umschaltung im Menue

## Installation

1. [Neueste Version herunterladen](https://github.com/smarthomelily/Androidy-Update/releases/latest)
2. Alle Dateien in einen Ordner entpacken
3. `Androidy-Update-v1.0.bat` per Doppelklick starten

### Voraussetzung: WinGet

WinGet ist bei Windows 11 vorinstalliert. Bei Windows 10:
1. Microsoft Store oeffnen
2. "App Installer" suchen und installieren

### Desktop-Verknuepfung erstellen

**Automatisch:**
- `Androidy-Update-v1.0-Verknuepfung.bat` ausfuehren

**Manuell:**
1. Rechtsklick auf `Androidy-Update-v1.0.bat` -> "Verknuepfung erstellen"
2. Verknuepfung auf Desktop verschieben
3. Rechtsklick auf Verknuepfung -> "Eigenschaften"
4. "Anderes Symbol" -> `Androidy-Update-v1.0.ico` auswaehlen
5. Optional: "Erweitert" -> "Als Administrator ausfuehren" aktivieren

## Benutzung

```
==========================================
    ANDROIDY UPDATE v1.0
              Update-Zentrale
==========================================

  Quellen: WinGet, Store, Windows

  [1] Updates anzeigen
      Verfuegbare Updates auflisten

  [2] Alle Updates installieren
      Mit Bestaetigung

  [A] Alles sofort
      Ohne Nachfrage durchlaufen

  [3] Interaktiv aktualisieren
      Updates einzeln bestaetigen

  [4] Alle ausser Auswahl
      Bestimmte Updates ueberspringen

  [5] Nur Windows Updates
      System-Updates von Microsoft

  ------------------------------------------
  [Q] Quellen konfigurieren
  [E] Exclude-Liste verwalten
  [I] Desktop-Icons loeschen: EIN
  [D] Dry-Run Modus: AUS
  [L] Log-Datei oeffnen
  [0] Beenden
```

### [A] Alles sofort

Fuer den schnellen Durchlauf: Ein Tastendruck startet alle Updates ohne weitere Nachfragen.

### Fortschrittsanzeige

Bei der Installation wird angezeigt:
```
  [3/12] VLC Media Player (winget)
```

### Farbcodierung

Updates werden nach Quelle farblich markiert:
- **Cyan** = WinGet (Programme)
- **Magenta** = Microsoft Store
- **Gelb** = Windows Updates

### Dry-Run Modus

Mit `[D]` kann der Dry-Run Modus aktiviert werden. Dabei wird **nichts installiert**, sondern nur angezeigt was passieren wuerde. Ideal zum Testen.

### Exclude-Liste

Apps die nicht automatisch aktualisiert werden sollen:

1. `[E]` im Hauptmenue druecken
2. `[A]` fuer neue App
3. App-ID eingeben (z.B. `Microsoft.Edge`)

Oder direkt die Datei `Androidy-Update-Exclude.txt` bearbeiten.

## Anforderungen

- Windows 10 oder Windows 11
- PowerShell 5.1 oder hoeher
- WinGet (App Installer)
- Administrator-Rechte (empfohlen)

## Hinweise

- Ohne Admin-Rechte koennen manche Updates fehlschlagen
- Die Exclude-Liste wird im Skript-Ordner gespeichert
- Log-Datei wird im Skript-Ordner erstellt

## Enthaltene Dateien

| Datei | Beschreibung |
|-------|--------------|
| `Androidy-Update-v1.0.bat` | Starter (Doppelklick) |
| `Androidy-Update-v1.0.ps1` | Hauptskript |
| `Androidy-Update-v1.0.png` | Logo (fuer README/Dokumentation) |
| `Androidy-Update-v1.0.ico` | Icon fuer Verknuepfungen |
| `Androidy-Update-v1.0-Verknuepfung.bat` | Erstellt Desktop-Verknuepfung |
| `Androidy-Update-v1.0-Verknuepfung.ps1` | PowerShell-Skript fuer Verknuepfung |

## Teil der Androidy-Familie

| Tool | Beschreibung |
| :--- | :--- |
| [Androidy Clean](https://github.com/smarthomelily/Androidy-Clean) | Windows Cleaning & Privacy Tool |
| [Androidy Install](https://github.com/smarthomelily/Androidy-Install) | WinGet Installer |
| [Androidy Update](https://github.com/smarthomelily/Androidy-Update) | Windows Update Tool |
| **Androidy Move** | PC-Migration & Datensicherung (coming soon) |

## Lizenz

GPL v3 License - siehe [LICENSE](LICENSE)

**Kurzfassung:** Du darfst das Tool frei nutzen, auch kommerziell. Wenn du es veraenderst oder erweiterst, muss deine Version auch Open Source unter GPL v3 bleiben.

## Autor

**smarthomelily**

---

Siehe auch: [Androidy Clean](https://github.com/smarthomelily/Androidy-Clean) - Windows Cleaning & Privacy Tool

---

:star: Wenn dir das Tool gefaellt, gib dem Projekt einen Stern!
