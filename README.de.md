<div align="center">

# Haustelefon

**Selbst gehostetes Softphone & Telefonanlage für Zuhause und kleine Büros.**
Flutter-App für Android, iOS und Windows + Asterisk-Server aus einer einzigen YAML-Datei.

[English](README.md) · [Architektur](docs/ARCHITEKTUR.md) · [Changelog](CHANGELOG.md)

</div>

<p align="center">
  <img src="docs/screenshots/desktop.png" width="720" alt="Haustelefon unter Windows: Kontakte und Wählfeld nebeneinander">
</p>

---

Macht aus den Rufnummern deines Routers (gebaut für den Telekom **Speedport**,
das Prinzip passt aber zu jedem Router, an dem sich IP-Telefone anmelden) eine
kleine Telefonanlage: Jedes Familienmitglied bzw. jeder Mitarbeiter bekommt eine
App auf Handy oder PC, eine eigene Durchwahl, und die richtigen Anrufe klingeln
auf den richtigen Geräten.

## Funktionen

- **Mehrere Rufnummern** – jede Nummer klingelt bei den Geräten/Gruppen deiner
  Wahl; ausgehende Nummer pro Anruf wählbar (mit Standard pro Gerät).
- **Interne Durchwahlen & Rufgruppen** – `10`, `11`, `20` … rufen sich kostenlos an.
- **Eine Konfigurationsdatei** – `haustelefon.yaml` → komplette Asterisk-Konfiguration,
  mit verständlichen Fehlermeldungen geprüft.
- **Einrichtungscodes** – der Server erzeugt pro Gerät einen Code; in die App
  einfügen, fertig.
- **App** – animiertes Wählfeld, Gesprächsansicht mit Live-Pegel, Anrufliste,
  Kontakte & Favoriten, Team-Verzeichnis, Deutsch & Englisch.
- **Android** – bleibt im Hintergrund erreichbar, Klingel-Benachrichtigungen.
- **Windows** – läuft im Infobereich weiter (erreichbar, auch wenn das Fenster
  zu ist), optional Start mit Windows, Tastatursteuerung, Geräteauswahl,
  Mikrofontest, Klingeltöne, blinkende Taskleiste, Installation per Doppelklick.

## So funktioniert es

```
 Handys & PCs (Haustelefon-App, WebRTC)
        │  SIP über WebSocket + verschlüsseltes Audio (LAN oder VPN)
        ▼
 Haustelefon-Server (Asterisk in Docker, z. B. Raspberry Pi)
        │  eine SIP-Anmeldung pro Rufnummer, unverschlüsseltes RTP
        ▼
 Router mit Telefonanlage (Speedport, …) ──▶ Festnetz / Internettelefonie
```

**Warum ein Server?** Wie jeder WebRTC-Client schickt die App Audio immer
verschlüsselt (DTLS-SRTP). Router-Telefonanlagen können nur unverschlüsseltes
RTP. Asterisk verbindet beide Welten und ergänzt, was der Router nicht kann:
Durchwahlen, Gruppen und Rufnummern-Zuordnung pro Gerät.

## Schnellstart

### 1. Router: ein IP-Telefon pro Rufnummer

Speedport: *Telefonie → Telefoniegeräte → IP-Telefon anlegen*. **Pro Rufnummer
ein IP-Telefon**: ankommend nur diese Nummer, abgehend dieselbe Nummer.
Nutzerkennung, Authentifizierungsname und Passwort jeweils notieren.

### 2. Server (Raspberry Pi oder jedes Linux mit Docker)

```bash
git clone https://github.com/<du>/haustelefon.git
cd haustelefon/server
cp haustelefon.example.yaml haustelefon.yaml
nano haustelefon.yaml        # Nummern, Router-Zugangsdaten, Geräte, Gruppen
./setup.sh                   # installiert ggf. Docker, erzeugt alles, startet Asterisk
./setup.sh codes             # Einrichtungscode für jedes Gerät
./setup.sh status            # Anmeldungen & verbundene Geräte
```

Alle Optionen (Büro-Modus, Gruppen, erlaubte Leitungen pro Gerät) stehen
kommentiert in [`server/haustelefon.example.yaml`](server/haustelefon.example.yaml).

### 3. App

App installieren, im Einrichtungs-Assistenten **Einrichtungscode einfügen**
wählen und den Code des Geräts einfügen. Für unterwegs ein VPN (z. B. WireGuard)
nutzen – es müssen keine Ports ins Internet geöffnet werden.

**Fertige Downloads** gibt es auf der Seite [Releases](../../releases):

| Download | Installation |
|---|---|
| `Haustelefon-<version>-android.apk` | Auf dem Handy öffnen, „Unbekannte Apps installieren“ erlauben |
| `Haustelefon-<version>-windows-x64.zip` | Entpacken, `Install.cmd` doppelklicken – keine Adminrechte nötig |
| `Haustelefon-<version>-server.zip` | Auf dem Raspberry Pi / Server entpacken, weiter mit Schritt 2 (`cd haustelefon-server`) |

**Selbst bauen:**

| Plattform | Bauen | Hinweis |
|---|---|---|
| Android | `flutter build apk --release` | Hintergrunddienst hält die App erreichbar |
| Windows | `Haustelefon-installieren.bat` doppelklicken | Baut, installiert, legt Verknüpfungen an; kein Entwicklermodus nötig |
| iOS | `flutter build ios` auf einem Mac | Erreichbar, solange geöffnet |

Android-Release-Signatur: `storeFile`, `storePassword`, `keyAlias` und
`keyPassword` in `android/key.properties` eintragen (git-ignoriert). Ohne die
Datei wird der Release-Build mit dem Debug-Schlüssel signiert.

## Einschränkungen

- **SMS** über Festnetznummern geht nicht: Telekom und Vodafone haben
  Festnetz-SMS im März 2023 abgeschaltet.
- **iOS im Hintergrund**: iOS trennt Netzwerkverbindungen von Hintergrund-Apps.
  Klingeln bei geschlossener App bräuchte PushKit/CallKit plus Push-Dienst.
- Getestet mit dem Telekom Speedport Smart 4. Andere Router mit eingebautem
  SIP-Registrar sollten genauso funktionieren, sind aber ungetestet.

## Fehlersuche

| Symptom | Lösung |
|---|---|
| Rot: „Keine Antwort von …“ | VPN aus, falsche `server_host`-Adresse oder Port 8088/TCP blockiert |
| „Benutzername oder Passwort abgelehnt“ | Einrichtungscode neu einfügen; `./setup.sh codes` prüfen |
| Anruf verbindet, aber kein Ton | UDP 10000–10200 zum Server blockiert (Firewall / VPN-`AllowedIPs`) |
| Leitung `Rejected` in `./setup.sh status` | Router-Zugangsdaten falsch; manche Speedports wollen den Auth-Namen ohne `@speedport.ip` |
| Asterisk-Live-Log | `docker exec -it haustelefon-asterisk asterisk -rvvv` |

## Lizenz

[MIT](LICENSE). Asterisk läuft als separater Container unter seiner eigenen GPL-Lizenz.
