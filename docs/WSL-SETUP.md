# WSL2 + tmux Setup (fuer spaeter)

Aktuell laeuft der Orchestrator Windows-native (sequenzielle CLI-Aufrufe).
Mit WSL2 + tmux koennen Claude und Codex **parallel** in separaten Panes laufen.

## Installation

### 1. WSL2 installieren
```powershell
# Als Administrator in PowerShell:
wsl --install
```
- Neustart erforderlich
- Standard-Distribution: Ubuntu
- Beim ersten Start: Username + Passwort setzen

### 2. tmux installieren (in WSL)
```bash
sudo apt update && sudo apt install -y tmux
```

### 3. Claude CLI in WSL verfuegbar machen
Option A — npm in WSL installieren:
```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g @anthropic-ai/claude-code
claude login
```

Option B — Windows-Claude aus WSL aufrufen:
```bash
# In ~/.bashrc hinzufuegen:
alias claude='/mnt/c/Users/domes/AppData/Roaming/npm/claude.cmd'
```

### 4. Codex CLI in WSL verfuegbar machen
```bash
npm install -g @openai/codex
codex login
```
Oder analog Windows-Binary:
```bash
alias codex='/mnt/c/Users/domes/AppData/Roaming/npm/codex.cmd'
```

### 5. Verifizieren
```bash
tmux -V        # tmux 3.x
claude --version  # 2.x
codex --version   # 0.x
```

## Was WSL + tmux bringt

| Feature | Windows-native (jetzt) | WSL + tmux (spaeter) |
|---------|----------------------|---------------------|
| Claude + Codex parallel | ❌ Sequenziell | ✅ Echte Parallelitaet |
| Live-Output beobachten | ❌ Nur nach Abschluss | ✅ tmux attach jederzeit |
| Session fortsetzen | ❌ Nicht moeglich | ✅ tmux detach/attach |
| Mehrere Agenten gleichzeitig | ❌ Max 1 | ✅ Beliebig viele Panes |
| Scripting | ✅ Einfach | ✅ + tmux send-keys/capture-pane |

## Orchestrator umstellen

Wenn WSL + tmux verfuegbar sind, den Orchestrator auf tmux-Modus umstellen:
1. Skripte aus `scripts/` in WSL ausfuehren
2. `send_and_wait()` Funktion nutzt dann tmux send-keys statt direkte CLI-Aufrufe
3. Beide Agenten laufen parallel — Codex implementiert waehrend Claude reviewed

## Prioritaet

**Niedrig** — der Windows-native Modus funktioniert gut fuer den aktuellen Workflow.
WSL lohnt sich erst wenn:
- Dual-Mode regelmaessig genutzt wird (Parallelitaet spart Zeit)
- Mehr als 2 Agenten gleichzeitig gebraucht werden
- Live-Monitoring der Agenten gewuenscht ist
