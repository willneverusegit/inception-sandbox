---
name: inception
description: Run a task in an isolated Docker sandbox via tmux orchestration
triggers:
  - "run in sandbox"
  - "inception"
  - "isoliert ausfuehren"
  - "docker sandbox"
---

# Inception Sandbox Skill

Fuehre eine Aufgabe in einem isolierten Docker-Container aus.

## Ablauf

1. Starte einen frischen Container (`docker compose up -d --build`)
2. Sende den Task via `tmux send-keys` an den Container-Claude
3. Warte auf Ergebnis via `tmux capture-pane` polling
4. Extrahiere Ergebnisse aus `/output/`
5. Zerstoere den Container (Amnesie)

## Verwendung

```bash
# Via Orchestrator-Skript
./scripts/orchestrator.sh --prompt "Refactore main.py zu async"

# Via Task-Datei
./scripts/orchestrator.sh tasks/refactor-main.md

# Einzelne Schritte
./scripts/send-prompt.sh "Schreibe Tests fuer utils.py"
./scripts/read-output.sh --wait
```

## Voraussetzungen

- **Docker** muss installiert und der Daemon gestartet sein (`docker info` zum Pruefen)
- Der ausfuehrende User braucht Docker-Rechte (Mitglied der `docker`-Gruppe oder `sudo`)
- **Internetverbindung** fuer den initialen Image-Pull (danach cached)
- **tmux** muss auf dem Host installiert sein (Orchestrator nutzt es fuer Session-Management)
- Mindestens 2 GB freier RAM fuer den Container (4 GB empfohlen)

## Sicherheitshinweise

- Der Container hat `--dangerously-skip-permissions` — das ist beabsichtigt
- Host-Dateisystem ist NICHT gemountet (ausser explizit konfiguriert)
- Container wird nach jedem Run zerstoert
- Ergebnisse muessen vom Host-Agent reviewed werden bevor sie uebernommen werden

### Warum `--dangerously-skip-permissions`?

Das Flag deaktiviert Claudes eingebautes Permission-System (Datei-Schreiben, Shell-Ausfuehrung etc.).
Das ist hier **ausschliesslich deshalb sicher**, weil Docker die Isolationsgrenze bildet — nicht
Claudes Permission-System. Der Container hat:

- Kein gemountetes Host-Dateisystem (ausser `/output/` als explizites Volume)
- Einen eigenen Netzwerk-Namespace (kein Zugriff auf Host-Services)
- Begrenzte Ressourcen (CPU, RAM, kein privileged mode)

Die innere Claude-Instanz kann also beliebig im Container agieren, ohne den Host zu
beeinflussen. Das Permission-System waere im Container nur hinderlich, weil jede
Dateioperation eine Bestaetigung erfordern wuerde — ohne dass ein Mensch sie sieht.

**Wichtig:** Dieses Pattern ist NUR mit Container-Isolation sicher. Niemals
`--dangerously-skip-permissions` auf dem Host oder in nicht-isolierten Umgebungen verwenden.

## Fehlerbehandlung

| Fehler | Ursache | Loesung |
|--------|---------|---------|
| `Cannot connect to the Docker daemon` | Docker nicht installiert oder Daemon gestoppt | `sudo systemctl start docker` oder Docker Desktop starten. Installation: https://docs.docker.com/engine/install/ |
| `Error response from daemon: pull access denied` / Timeout beim Pull | Image kann nicht heruntergeladen werden (Netzwerk, Registry down) | Automatischer Retry (1x). Bei erneutem Fehlschlag: Image manuell pullen (`docker pull <image>`) oder offline ein gespeichertes Image laden (`docker load -i image.tar`) |
| `Container exceeded timeout` | Task dauert laenger als erlaubt (Default: 10 min) | Timeout erhoehen: `./scripts/orchestrator.sh --timeout 1800 --prompt "..."` (Wert in Sekunden). Fuer langwierige Tasks 30 min empfohlen. |
| `Container killed (OOM)` | Container hat das Speicherlimit ueberschritten | Speicherlimit in `docker-compose.yml` erhoehen: `mem_limit: 4g` (Default ist 2 GB). Alternativ den Task in kleinere Teile zerlegen. |

## Einschraenkungen

- **Kein GPU-Zugriff** — der Container laeuft CPU-only (kein `--gpus` Flag gesetzt)
- **Kein Host-Dateisystem** — nur `/output/` ist als Volume gemountet, alle anderen Dateien muessen explizit in den Container kopiert werden
- **Netzwerk-Isolation** — im Default-Modus hat der Container keinen Zugriff auf lokale Host-Services (localhost). Fuer API-Zugriffe `--network host` setzen (reduziert Isolation)
- **Keine Persistenz** — der Container wird nach jedem Run zerstoert (Amnesie-Prinzip). Ergebnisse nur ueber `/output/` extrahierbar
- **Kein interaktiver Modus** — der Orchestrator pollt via `tmux capture-pane`, menschliche Interaktion mit dem Container-Claude ist nicht vorgesehen
- **Plattform-Abhaengigkeit** — getestet auf Linux und WSL2. Natives Windows (ohne WSL) wird nicht unterstuetzt wegen tmux-Abhaengigkeit
