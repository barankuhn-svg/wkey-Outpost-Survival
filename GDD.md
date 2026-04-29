# Wkey Take-Home V2 — Master Dokument
*Version 1.0 — 29.04.2026*
*Developer: Baran (b3lit)*

---

## 0) Was ist V2?

Erweiterte Version des WKey Take-Home Assignments.
Der Spieler überlebt so lange wie möglich gegen kontinuierlich stärker werdende Enemies.
Eigene Assets (Sloyd Rigs), eigene Animationen, Wasserpistole mit automatischem Wasserbeam.
Kein Wave-System. Kein Slime-Thema.

---

## 1) Stack

- **Sprache:** Luau (strict mode)
- **Workflow:** Rojo + Cursor
- **VCS:** GitHub (public, `wkey-outpost7-v2`)
- **Assets:** Sloyd Rigs (10 verschiedene), eigene Animationen
- **Waffe:** Wasserpistole (eigenes Modell), automatischer Wasserbeam
- **Lokalisierung:** en, de, tr, ru, fr, es, pt-BR, ko, ja (aus V1 übernommen)

---

## 2) Gameplay Loop

1. Spieler joint → Menü Screen (Stats + Coins sichtbar)
2. Stats upgraden (mit Coins)
3. "START" drücken → Runde beginnt
4. Spieler überlebt gegen Enemies mit Wasserpistole
5. Enemies werden mit der Zeit stärker (zeitbasierte Skalierung)
6. Spieler stirbt → Death Screen mit Stats → zurück zum Menü
7. Coins + Stats bleiben (Datastore)

---

## 3) Menü Screen

### Layout
- Hintergrundbild (neu generiert, passt zum neuen Thema)
- Mitte: Avatar Snapshot (ganzer Körper oder Kopf)
- Links der Avatar Anzeige: Stats Liste
- Rechts der Stats: Werte + Plus-Button

### Stats Anzeige
```
❤️  HP          50      [+]
⚔️  Schaden     20      [+]
💚  Regen       0.5/s   [+]
```

### Upgrade Kosten
- Linear steigend pro Upgrade
- Start: 1 Coin pro Upgrade
- Formel: `Kosten = 1 + (AnzahlUpgrades × 2)`
- Beispiel: 1. Upgrade = 1 Coin, 2. = 3 Coins, 3. = 5 Coins usw.
- Kein Cap

### Coins Anzeige
- Immer oben sichtbar im Menü
- Format: 🪙 `{coins}`

### Start Button
- Groß, mittig unten
- Text: "START" (lokalisiert)

---

## 4) Stats System

| Stat | Startwert | Pro Upgrade |
|------|-----------|-------------|
| HP | 50 | +10 |
| Schaden | 20 | +5 |
| Regen | 0.5/s | +0.5/s |

- Stats werden serverseitig gespeichert
- Im Spiel NICHT mehr änderbar
- Nach Tod → zurück ins Menü → dort upgraden

---

## 5) Arena

- **Größe:** 75x75 Studs
- **Material:** Eigenes Design (kein Standard Grau)
- **Unsichtbare Wände:** 4 Seiten, volle Höhe, CanCollide=true, Transparency=1
- **Baseplate:** entfernt
- **Außerhalb der Arena:** Void (sofortiger Tod)
- **SpawnLocation:** Mitte der Arena

---

## 6) Enemy System (aus V1 übernommen + erweitert)

### Custom Replication
- Identisch zu V1 (Server Lua Tabellen, 20Hz Batch, Client lokale Parts)

### Enemy Assets
- 10 verschiedene Sloyd Rigs
- Random bei Spawn ausgewählt (deterministisch via ID-Seed)

### Animationen (pro Rig)
- Idle
- Walk/Run
- Hit (wenn getroffen)
- Death (wenn HP = 0)

### Enemy Stats (zeitbasierte Skalierung)
```
Zeit  = Sekunden seit Rundenstart
Faktor = 1 + (Zeit / 60)  -- alle 60 Sek verdoppelt sich die Stärke

EnemyHP     = Basiswert × Faktor
EnemyDamage = Basiswert × Faktor
```

### Basis Enemy Stats
| Tier | HP | Schaden |
|------|----|---------|
| Schwach | 10 | 1 |
| Mittel | 100 | 15 |
| Stark | 500 | 50 |
| Boss | 1000 | 300 |

### Enemy HP Bar
- Kleiner Balken über jedem Enemy (BillboardGui)
- Rot, zeigt aktuelles HP/MaxHP Verhältnis

### Coins beim Kill
- Schwach: +2 Coins
- Mittel: +5 Coins
- Stark: +15 Coins
- Boss: +50 Coins

---

## 7) Wasserpistole

- **Modell:** Eigenes Asset (Wasserpistole)
- **Mechanik:** Automatisch schießt auf nächsten Enemy in Range
- **Beam:** Visueller Wasserbeam (neon blau/cyan, Roblox Beam Instanz)
- **Reichweite:** Arena-weit
- **Schaden:** Basiert auf Spieler Schaden-Stat
- **Feuerrate:** 1 Schuss pro Sekunde (fix)
- **Kein manuelles Zielen** (Mobile-first)

---

## 8) In-Game UI

### Während der Runde (rechts)
- Spawn Rate Slider (/s) — aus V1
- Max Enemies Slider — aus V1
- Apply Button — aus V1
- KILL ALL Button — aus V1

### Oben mittig
- Timer: wie lange die Runde schon läuft (`00:00`)
- Schwierigkeitsgrad Skala: Easy → Medium → Hard → Extreme → ULTRA

### Oben links
- 🪙 Coins Anzeige (live aktualisiert)
- ❤️ HP Bar (aktuelles HP / MaxHP)

### Floating Text beim Kill
- `+5 🪙` erscheint kurz über dem getöteten Enemy

---

## 9) Death Screen

Erscheint wenn Spieler stirbt:

```
💀 YOU DIED

⏱️  Überlebt:     02:34
🪙  Coins:        127
💀  Kills:        43
📈  Schwierigkeit: HARD

[ZURÜCK INS MENÜ]
```

- Zurück ins Menü Button → Menü Screen (Stats upgraden)
- Kein direkter Restart — immer durch Menü

---

## 10) Coins System

### Verdienen
- Passiv: +1 Coin pro Sekunde (Rundenstart)
- Kill Schwach: +2 Coins
- Kill Mittel: +5 Coins
- Kill Stark: +15 Coins
- Kill Boss: +50 Coins

### Ausgeben
- Nur im Menü (Stats upgraden)
- Kosten steigen linear

### Datastore
- Coins werden gespeichert (ProfileService oder DataStoreService)
- Stats werden gespeichert
- Geht niemals verloren

---

## 11) Schwierigkeitsgrad Skala

Basiert auf Zeit seit Rundenstart:

| Zeit | Schwierigkeit | Farbe |
|------|--------------|-------|
| 0-60s | Easy | Grün |
| 60-120s | Medium | Gelb |
| 120-180s | Hard | Orange |
| 180-240s | Extreme | Rot |
| 240s+ | ULTRA | Lila/Neon |

- Skala oben mittig als Balken mit Label
- Enemy Faktor steigt mit Schwierigkeit

---

## 12) Lokalisierung

Aus V1 übernommen. Neue Keys:
- `ui.start_button` → "START"
- `ui.you_died` → bereits vorhanden
- `ui.back_to_menu` → "Back to Menu"
- `ui.coins` → "Coins"
- `ui.difficulty_easy` → "Easy"
- `ui.difficulty_medium` → "Medium"
- `ui.difficulty_hard` → "Hard"
- `ui.difficulty_extreme` → "Extreme"
- `ui.difficulty_ultra` → "ULTRA"
- `ui.survived` → "Survived"
- `ui.kills` → "Kills"
- `ui.hp` → "HP"
- `ui.damage` → "Damage"
- `ui.regen` → "Regen"
- `ui.timer` → "Time"

---

## 13) One-Script Hierarchy

- `src/server/Main.server.luau` — gesamte Server Logik
- `src/client/GameClient.client.luau` — gesamte Client Logik
- `src/shared/Localization.luau` — Lokalisierung
- `src/shared/Config.luau` — geteilte Konstanten

---

## 14) Dateistruktur

```
wkey-outpost7-v2/
├── .cursorrules
├── default.project.json
├── GDD.md (dieses Dokument)
├── SUBMISSION.md
├── README.md
└── src/
    ├── server/
    │   └── Main.server.luau
    ├── client/
    │   └── GameClient.client.luau
    └── shared/
        ├── Localization.luau
        └── Config.luau
```

---

## 15) Baureihenfolge

### Phase 0 — Setup (30 Min)
- [ ] GitHub Repo `wkey-outpost7-v2` erstellen
- [ ] Rojo Projekt aufsetzen (aus V1 kopieren + anpassen)
- [ ] `.cursorrules` + `GDD.md` rein
- [ ] Erster Commit

### Phase 1 — Assets vorbereiten (45 Min)
- [ ] 10 Rigs von Sloyd runterladen
- [ ] Animationen erstellen/runterladen: Idle, Walk, Hit, Death
- [ ] Wasserpistolen Modell vorbereiten
- [ ] Alle Assets in Studio importieren → Asset IDs notieren

### Phase 2 — Map & Arena (20 Min)
- [ ] 75x75 Platform bauen
- [ ] Unsichtbare Wände (4 Seiten)
- [ ] Baseplate entfernen
- [ ] SpawnLocation mittig
- [ ] Commit: `feat: arena setup`

### Phase 3 — Datastore & Config (30 Min)
- [ ] `Config.luau` mit allen Konstanten
- [ ] DataStore für Coins + Stats aufsetzen
- [ ] Spieler Stats laden/speichern
- [ ] Commit: `feat: datastore and config`

### Phase 4 — Menü Screen (45 Min)
- [ ] Hintergrundbild generieren + hochladen
- [ ] Avatar Snapshot
- [ ] Stats Anzeige (HP, Schaden, Regen) mit Plus-Button
- [ ] Coins Anzeige
- [ ] START Button
- [ ] Upgrade Logik (Coins abziehen, Stats erhöhen)
- [ ] Commit: `feat: menu screen`

### Phase 5 — Enemy System (60 Min)
- [ ] Custom Replication aus V1 übernehmen
- [ ] 10 Rigs einbauen (deterministisch random)
- [ ] Animationen einbauen (Walk, Hit, Death)
- [ ] Enemy HP Bar (BillboardGui)
- [ ] Zeitbasierte Skalierung
- [ ] Coin Drop beim Kill + Floating Text
- [ ] Commit: `feat: enemy system`

### Phase 6 — Wasserpistole & Beam (45 Min)
- [ ] Wasserpistolen Modell am Spieler befestigen
- [ ] Auto-Aim auf nächsten Enemy
- [ ] Wasserbeam (Roblox Beam Instanz, cyan)
- [ ] Schaden basierend auf Schaden-Stat
- [ ] Feuerrate 1/s
- [ ] Commit: `feat: water gun and beam`

### Phase 7 — In-Game UI (45 Min)
- [ ] Timer oben mittig
- [ ] Schwierigkeitsgrad Skala
- [ ] Coins + HP Bar oben links
- [ ] Spawn Rate / Max Enemies / Kill All (aus V1)
- [ ] Floating Coin Text beim Kill
- [ ] Commit: `feat: ingame UI`

### Phase 8 — Death Screen (20 Min)
- [ ] Death Screen mit Stats (Zeit, Coins, Kills, Schwierigkeit)
- [ ] Zurück ins Menü Button
- [ ] Commit: `feat: death screen`

### Phase 9 — Regen System (15 Min)
- [ ] HP Regeneration basierend auf Regen-Stat
- [ ] Passive Coin Generierung (+1/s)
- [ ] Commit: `feat: regen and passive coins`

### Phase 10 — Polish & Lokalisierung (30 Min)
- [ ] Neue Lokalisierungs-Keys in alle 9 Sprachen
- [ ] Selene + Stylua
- [ ] Finaler Test
- [ ] Commit: `feat: localization and polish`

### Phase 11 — Submission (20 Min)
- [ ] Roblox veröffentlichen
- [ ] SUBMISSION.md schreiben
- [ ] GitHub pushen
- [ ] An @byrned_ schicken

---

## Goldene Regeln

1. Vorgaben bleiben erfüllt — Custom Replication bleibt der Kern
2. Kein Scope Creep — nur was im GDD steht
3. Mobile-first — alles relativ skaliert
4. Keine Tool-Namen in Commits oder Code
5. Incremental Commits — nach jeder Phase
