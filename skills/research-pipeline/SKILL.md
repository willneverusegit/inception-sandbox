---
name: research-pipeline
description: Token-optimierte Research-Pipeline via Perplexity → NotebookLM → Claude. Spart ~95% Claude-Tokens bei Web-Recherche.
triggers:
  - "research"
  - "recherchiere"
  - "find sources"
  - "quellen suchen"
  - "web research"
  - "deep research"
  - "recherche starten"
---

# Research Pipeline Skill

Token-optimierte Recherche durch Auslagerung an spezialisierte Tools.

## Architektur

```
┌─────────────────────────────────────────────────────────┐
│  Phase 1: SUCHE (Perplexity)                  GRATIS*   │
│  ─────────────────────────────────────────────           │
│  → Browser oeffnen → Perplexity Suchanfrage             │
│  → Links + Zusammenfassung extrahieren                  │
│  → Lokal speichern: research/<topic>-<date>.md          │
├─────────────────────────────────────────────────────────┤
│  Phase 2: INGEST (NotebookLM)                 GRATIS    │
│  ─────────────────────────────────────────────           │
│  → Links aus Phase 1 in NotebookLM Notebook laden       │
│  → Notebook benennen nach Thema                         │
│  → Gemini indexiert automatisch alle Quellen             │
├─────────────────────────────────────────────────────────┤
│  Phase 3: ANALYSE (NotebookLM RAG)            GRATIS    │
│  ─────────────────────────────────────────────           │
│  → Gezielte Fragen an NotebookLM stellen                │
│  → Antworten extrahieren und lokal speichern             │
│  → Optional: Studio-Output (Mindmap, Bericht, etc.)     │
├─────────────────────────────────────────────────────────┤
│  Phase 4: INTEGRATION (Claude)                ~3K Tok   │
│  ─────────────────────────────────────────────           │
│  → Gespeicherte Ergebnisse lesen (lokale Dateien)       │
│  → In Projekt integrieren (Code, Docs, Architektur)     │
│  → Entscheidungen treffen basierend auf Research         │
└─────────────────────────────────────────────────────────┘
  * Perplexity Pro = Flatrate, Free Tier = 5 Pro Searches/Tag
```

## Token-Ersparnis

| Schritt | Nur Claude | Mit Pipeline |
|---------|-----------|--------------|
| Web-Suche | ~10-20K Tokens | 0 (Perplexity) |
| Quellen lesen | ~50-100K Tokens | 0 (NotebookLM) |
| Synthese | ~5K Tokens | 0 (NotebookLM RAG) |
| Ergebnis lesen | — | ~2-3K Tokens |
| **Gesamt** | **~70-125K** | **~3K** |

**Ersparnis: ~95%**

## Ablauf im Detail

### Phase 1: Perplexity-Suche

1. Browser oeffnen → `https://www.perplexity.ai`
2. Suchanfrage formulieren (spezifisch, mit Kontext)
3. Antwort abwarten
4. Text + Links extrahieren via `browser_evaluate`
5. Speichern nach `research/<topic>-<YYYY-MM-DD>.md`

**Prompt-Template fuer Perplexity:**
```
<Thema> - Focus on:
1) Real-world implementations and GitHub repos
2) Best practices and common patterns
3) Cost/performance tradeoffs
4) Security considerations
```

### Phase 2: NotebookLM Ingest

1. Notebook erstellen: `notebooklm create "Research: <topic>"`
2. Notebook-ID merken (aus JSON-Output)
3. Links aus Phase 1 als Quellen hinzufuegen: `notebooklm source add "<url>" --json`
4. Auf Indexierung warten: `notebooklm source wait <source_id> -n <notebook_id>`

### Phase 3: NotebookLM Analyse

1. Gezielte Fragen stellen via CLI:
   ```bash
   notebooklm ask "Was sind die konkreten Use Cases fuer X?" --json
   notebooklm ask "Vergleiche Ansatz A vs B" --json
   notebooklm ask "Welche Risiken und Einschraenkungen gibt es?" --json
   ```
2. Antworten aus JSON-Output extrahieren und lokal speichern
3. Optional: Studio-Outputs generieren (`notebooklm generate report --format briefing-doc`)

### Phase 4: Claude Integration

1. Lokale Research-Dateien lesen (Read Tool)
2. Erkenntnisse in Projektcode/-docs integrieren
3. Architektur-Entscheidungen dokumentieren

## Wann diese Pipeline nutzen

**JA — Pipeline nutzen wenn:**
- Web-Recherche zu einem neuen Thema noetig
- Mehrere Quellen verglichen werden muessen
- Tiefenanalyse ueber 5+ Dokumente/Artikel
- Wiederkehrende Research-Fragen zu einem Themengebiet

**NEIN — Direkt Claude nutzen wenn:**
- Antwort ist im Projekt-Code/Docs vorhanden
- Einfache API-Doku-Frage (→ context7 MCP)
- Frage kann aus Kontext beantwortet werden

## Dateisystem-Konvention

```
research/
├── <topic>-<YYYY-MM-DD>.md          # Perplexity-Ergebnis (roh)
├── <topic>-analysis-<YYYY-MM-DD>.md # NotebookLM-Analyse
└── <topic>-links.md                 # Extrahierte Links fuer NotebookLM
```

## Voraussetzungen

- Perplexity-Account (Free oder Pro)
- Google-Account fuer NotebookLM
- `notebooklm-py` CLI installiert (`pip install notebooklm-py`)
- Authentifiziert via `notebooklm login`
