---
name: md2html
description: Convert a markdown doc into a self-contained HTML brief — one-shot, high-density, shareable artifact. Use for PO validation briefs, investigation reports, executive summaries, design decks — anything the reader consumes once and shouldn't have to edit. NOT for living specs, references, or docs reviewed in GitHub.
allowed-tools: Read, Glob, Grep, Bash(realpath *), Bash(date *), Bash(ls *), Bash(pwd), Bash(*/render-html.sh *), Write, Edit
---

# /md2html — Markdown → Standalone HTML Brief

Renders a source markdown doc into a single self-contained `.html` (CSS+SVG inline, zero deps) optimized for **one-shot visual consumption** — sharing with stakeholders before a meeting, posting a report alongside its source, archiving a snapshot at a decision point.

The skill embeds a consistent design system (dark theme, named tokens, reusable components) so multiple briefs generated over time share a visual language. The HTML never replaces the markdown — markdown stays the source of truth; HTML is a derived snapshot.

## When to use

| Case | HTML serves? |
|---|---|
| Pre-meeting validation brief for PO/stakeholder | ✅ ideal |
| Investigation report snapshot at conclusion | ✅ ideal |
| Executive summary / one-pager for leadership | ✅ ideal |
| Design deck with diagrams and decision options | ✅ ideal |
| Living spec evolved across many commits | ❌ use markdown — HTML diffs are noisy |
| Reference doc consumed by Claude in context | ❌ markdown is indexable |
| Daily/weekly minutes posted in GitHub issues | ❌ GitHub renders markdown natively |
| ADRs / decision logs reviewed in PRs | ❌ markdown wins for review |

## Arguments

`$ARGUMENTS` = path to the source markdown. Examples:

- `docs/planning/demands/perfil-clientes/spec.md` — render the spec as a brief
- `docs/explanations/investigations/2026-05-12-org-multiple-cli-non-ota.md` — render an investigation snapshot
- `(empty)` — ask the user which markdown to render

Optional flags after the path:
- `--out <path>` — explicit output path. Default: same dir as source, with `.html` extension. If source is `foo.md`, output is `foo.html` unless the source name implies a date prefix (e.g., `2026-05-12-investigation.md` → keep prefix in output).
- `--name <slug>` — alternate basename (e.g., `--name preview-16-05` for a brief tied to a meeting date)
- `--no-render` — skip the auto-screenshot step (default: render desktop PNG to `/tmp/`)

## Workflow

### 1. Read source + cross-references

Read the source markdown completely. Then scan for relative links and read any cross-referenced docs that the brief will need to summarize (e.g., the source links to `evidence.md` and `decisions.md` — read those too if the rendered brief should embed numbers/options from them).

Do NOT read every doc in the project. Only follow links that the rendered HTML needs to materialize content from.

### 2. Identify the doc type and component set

Match the source to a doc type and select components:

| Doc type | Signals in source | Components to use |
|---|---|---|
| **Validation brief** | Status table, open decisions, deadline, "for review by X" | Header pills, TL;DR card, funnel viz, tabs mockup, decision cards with options, deferred grid, footer |
| **Investigation report** | Hypothesis/Validation/Conclusion structure, queries, data tables | Header with status (closed/open), TL;DR card, numbered sections, code blocks, data tables, callout notes, conclusion list, references footer |
| **Executive summary** | Bullet-heavy, short, leadership audience | Header, big-number tiles, simple table, footer |
| **Design deck** | Multiple options, trade-offs, recommendation | Option cards (with "Recommended" badge), trade-off tables, decision section |

If unsure, ask the user in one sentence what doc type best describes the source. Don't over-engineer.

### 3. Compose the HTML

Use the **design system** below. The HTML must be:

- **Single file**: all CSS in `<style>`, all SVGs inline, no external assets or scripts
- **Dark theme by default** (matches preview-16-05.html convention)
- **Responsive**: grids collapse below 800px (`@media (max-width: 800px)`)
- **Print-friendly**: avoid fixed positioning, allow tables to break naturally
- **Portuguese with diacritics** if source is in Portuguese (CLAUDE.md rule)
- **No emojis** unless source uses them as status markers (✅ 🟡 etc. are fine; decorative emojis are not)
- **No fabricated data**: every number, name, date in the HTML must trace back to the source markdown or a doc it explicitly references. If the source has a TODO/pending value, the HTML must say "pendente" — never invent.

### 4. Save to disk

Save the HTML to the resolved output path (see `--out` and `--name` flags). Default: `<source-dir>/<source-basename>.html`.

### 5. Auto-render preview (default)

After saving, run `~/.claude/scripts/render-html.sh <output.html> desktop` (unless `--no-render`) to produce a PNG screenshot in `/tmp/render-<basename>-desktop.png`. Then `Read` the PNG to verify it rendered correctly (no broken layouts, no overflow disasters). If the PNG reveals visual issues, fix the HTML and re-render once. Don't loop more than 2 iterations — escalate to the user.

### 6. Chat output (strict)

**The chat output of this skill is the saved path(s) and nothing else.** Do NOT echo the HTML content, the rendered screenshot, or a content summary. The user opens the file (or rendered PNG) themselves.

Allowed chat output:
- One line confirming the source + doc type identified
- The saved HTML path (and PNG path if auto-rendered)
- Iteration count if the auto-render found issues that were fixed
- A pointer to next steps (e.g., "Open in browser: `xdg-open <path>`")

Forbidden:
- Echoing the HTML in a fenced code block
- Re-stating the TL;DR or section headings
- Inline screenshots in chat (the user can `xdg-open` the PNG themselves)

Why: this skill produces an artifact for visual consumption. Reprinting it in chat duplicates context and signals the skill doesn't trust its own file output (same rationale as `/prompt2next`).

---

## Design system reference

### Color tokens (CSS custom properties)

```css
:root {
  --bg: #0f1419;            /* page background */
  --panel: #1a1f26;         /* card background */
  --panel-2: #232a33;       /* secondary surface, table head */
  --border: #2c3540;
  --text: #e8eaed;
  --text-dim: #9aa3ad;
  --accent: #d62828;        /* Toledo red — primary accent */
  --accent-soft: #ef4444;
  --good: #10b981;
  --warn: #f59e0b;
  --info: #3b82f6;
  /* Tiers / categorical */
  --tier-s: #dc2626;
  --tier-a: #ea580c;
  --tier-b: #ca8a04;
  --tier-c: #525252;
  /* Routes / channels (use semantically) */
  --route-sap-int: #3b82f6;
  --route-sap-nint: #06b6d4;
  --route-ota: #a855f7;
}
```

Replace `--accent` if the doc isn't Toledo-related. Keep the rest stable across briefs for visual continuity.

### Typography

- Body: system stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`), 15px, line-height 1.55
- H1: 26px, line-height 1.2
- H2: 20px, with `border-bottom: 1px solid var(--border)`
- H3: 16px
- Mono inline: `ui-monospace, "SF Mono", Menlo` — use for `<code class="inline">` and SQL/DAX in blocks
- Tabular figures: `font-variant-numeric: tabular-nums` on number columns
- Small / captions: 12.5px, `color: var(--text-dim)`

### Component recipes

**Header (top)**: flex row with title on left + meta pills on right. Pills carry status/owner/deadline. Variants: `.pill.danger`, `.pill.good`, `.pill.warn`, `.pill.info`. Below the row: 1px `--border` bottom, then content.

**TL;DR card**: full-width gradient panel (`linear-gradient(135deg, rgba(214,40,40,0.08), rgba(59,130,246,0.05))`) with left accent border. Contains H2 (no border under it inside the card) and 3-6 bullets. Use for: "what we're validating", "what this report shows", "what's open".

**Funnel viz**: vertical stack of `.funnel-step` rows. Each row = label + bar (proportional gradient) + value. Use for: universe filtering (111K → 6.216), conversion chains, scope narrowing. Make bar widths proportional to actual values.

**Tabs mockup**: `.tabs-mock > .tabs-bar > .tab.active` + `.tab-body`. Use for: showing UI/dashboard layouts described in the source. Not interactive — purely visual mockup. Body can contain filter chips + a representative table.

**Table**: clean rows with `--border` bottoms. TH uppercase 12px, `--text-dim`. Number columns: `.num` class for right-align + tabular nums. Use for: data results, comparisons, status matrices.

**Tier / category cards**: grid of 4 cards with colored top borders. Big letter (28px, 700) + meta line (percentile / cardinality) + example. Use for: ranking tiers, segmentation categories, severity levels.

**Decision card**: `.decision` block with header (code badge + title + owner pill) + body (context + `.options` grid). Each `.option` has tag (a/b/c), name, description. `.option.recommended` gets green left border and "Recomendado" badge after the name. Use for: open questions awaiting decision, ADR-style choices.

**SVG flowchart**: use viewBox-based inline `<svg>` with `<rect>`/`<text>`/`<path>` + a single `<marker id="arr">` for arrowheads. Use named color tokens (`stroke="#3b82f6"`). Keep the SVG ~width 980, height variable. Use for: routes/channels with semantic differences, dataflow lineage, dependency graphs. Avoid mermaid — inline SVG keeps the file self-contained.

**Legend strip**: below an SVG. `.legend > span` with a 12px `.sw` swatch + label. Match swatch colors to the SVG strokes/fills.

**Code block**: `.score-eq` for short formulas (mono, dark surface), or generic `<pre><code>` for SQL/DAX. Highlight key names with `<b style="color: #93c5fd;">`.

**Note callout**: `.note` with left blue border + tinted background. Use for: implications, "what this means", warnings. Keep to 2-3 sentences.

**Grid of cards**: `.grid.grid-3` for deferral lists, parking-lot items, sub-topics. Each `.card.accent-warn` shows H3 + small paragraph. Mobile collapses to 1 column.

**Footer**: `<footer>` with source links list. Each link points back to the markdown source-of-truth. End with date + author + disclaimer: *"Em caso de divergência com os Markdowns acima, prevalece o Markdown."*

### Reference implementation

See `docs/planning/demands/perfil-clientes/preview-16-05.html` in the TDB Version Dashboard project (Toledo) for a full example using all components above. ~720 lines, self-contained.

---

## Design principles

- **Source markdown is canonical** — HTML is a snapshot. Always include source links in the footer. State the disclaimer explicitly.
- **Visual continuity** — same design system across briefs in a project. Don't reinvent colors or layouts per doc.
- **Density over scrolling** — pack information visually (grids, tables, SVG) so the reader sees structure on first scroll, not after page 5.
- **One-shot consumption** — the reader opens this once before/after a meeting. No interactive widgets, no JS, no expand/collapse needing clicks.
- **Trace every claim** — if a number appears in the HTML, it must trace back to a section/table in the source markdown. Add inline source references (e.g., "(Q3, evidence.md)") where useful.

## Anti-patterns

- Don't add JavaScript. The HTML must work file-opened in any browser, with no network or runtime.
- Don't link to external CSS or fonts. System font stack is fine.
- Don't use `<iframe>`, `<script>`, or anything that depends on a server.
- Don't fabricate numbers, names, or dates. If the source is missing a value, write "pendente" or "a confirmar".
- Don't translate the source content's language. Keep Portuguese as Portuguese (with diacritics), English as English.
- Don't add a "generated by Claude" footer — the disclaimer about Markdown prevailing is enough.
- Don't re-render after every edit. Run render-html.sh once after the full HTML is written, then read the PNG. Iterate at most once.

## Related skills

- `/prompt2next` — same chat-output discipline (path only, no content reprint)
- `~/.claude/scripts/render-html.sh` — used by step 5; can be run standalone for any HTML file
