---
name: anki
description: Manage Anki flashcards via AnkiConnect. Create cards, search, get deck stats. Local mirror of the Noux MCP anki skill.
allowed-tools: Bash(curl *)
---

# /anki — AnkiConnect Card Management

Manage Anki flashcards via AnkiConnect (localhost:8765). Mirrors the Noux MCP `anki` skill for local CC and Claudian use.

## Arguments

`$ARGUMENTS` supports:
- **Empty** (default): show deck stats for deck "Claude"
- `add <deck>`: add cards to a deck (reads card data from conversation context)
- `search <query>`: search cards by AnkiConnect query (e.g., `search deck:Claude tag:testing`)
- `stats <deck>`: show review stats for a deck
- `create-deck <name>`: create a deck

## AnkiConnect Base

All operations use this pattern:

```bash
curl -sf http://localhost:8765 -X POST -d '<JSON>'
```

If the request fails, report: "AnkiConnect not available. Ensure Anki is running with the AnkiConnect plugin (port 8765)."

## Step 1: Parse Arguments

Parse `$ARGUMENTS` to determine the action:

| Input | Action | Default |
|-------|--------|---------|
| (empty) | `get_deck_stats` | deck = "Claude" |
| `add [deck]` | `add_notes` | deck = "Claude" |
| `search <query>` | `find_notes` | — |
| `stats [deck]` | `get_deck_stats` | deck = "Claude" |
| `create-deck <name>` | `create_deck` | — |

## Step 2: Health Check

```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"version","version":6}'
```

If this fails, stop and report the error message above.

## Step 3: Execute Action

### add_notes

Collect cards from the conversation context. Each card needs: front (question), back (answer), tags (optional).

1. Create deck if needed:
```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"createDeck","version":6,"params":{"deck":"DECK_NAME"}}'
```

2. Add notes (one per card):
```bash
curl -sf http://localhost:8765 -X POST -d '{
  "action":"addNotes","version":6,
  "params":{"notes":[
    {"deckName":"DECK_NAME","modelName":"Basic","fields":{"Front":"QUESTION","Back":"ANSWER"},"tags":["tag1","tag2"],"options":{"allowDuplicate":false,"duplicateScope":"deck"}}
  ]}
}'
```

Report: "Added X card(s) to deck 'NAME'. Y duplicate(s) skipped." (null in result array = duplicate)

### find_notes

```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"findNotes","version":6,"params":{"query":"QUERY"}}'
```

Then fetch info for the first 50 IDs:
```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"notesInfo","version":6,"params":{"notes":[ID1,ID2,...]}}'
```

Display: `- [noteId] front_text | tags: tag1, tag2`

### get_deck_stats

```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"getDeckStats","version":6,"params":{"decks":["DECK_NAME"]}}'
```

Display: `**DeckName** — N cards total\n  New: X | Learning: Y | Review: Z`

### create_deck

```bash
curl -sf http://localhost:8765 -X POST -d '{"action":"createDeck","version":6,"params":{"deck":"DECK_NAME"}}'
```

Display: `Deck "NAME" ready (id: ID).`

## Card Design Principles

When generating cards from conversation context (for `add` action):

- **Front**: Question + minimal context (pattern name, domain)
- **Back**: Answer + source reference (concept brief, book, session topic) + code path if applicable
- **Tags**: topic slug + gap category (e.g., `testing`, `architecture`, `domain-modeling`)
- **Granularity**: one concept per card — fine-grained over comprehensive
- **Language**: match the language of the source material (Portuguese for vault content, English for code concepts)
