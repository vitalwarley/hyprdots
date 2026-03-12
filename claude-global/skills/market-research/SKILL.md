---
name: market-research
description: Initial market research producing a structured artifact for domain expert follow-up. Adaptive depth via arguments.
allowed-tools: Read, Glob, Grep, WebSearch, WebFetch, Write, AskUserQuestion, Bash(git *)
---

# /market-research — Market Research for Domain Expert Handoff

Perform initial market research for a product or project, producing a structured markdown artifact that a domain specialist can review and expand. The output prioritizes breadth of landscape coverage and explicit "gaps for expert" callouts over deep analysis.

## Arguments

`$ARGUMENTS` format:

```
/market-research <product description or project name> [depth]
```

**Depth levels** (parsed from last word of arguments):
- **quick** (default) — 1-2 searches per section, surface scan. Best for initial orientation.
- **deep** — 3-5 searches per section, cross-referencing sources, detailed competitor profiles.
- **comprehensive** — exhaustive search, multiple angles per competitor, trend data, pricing teardowns, community/forum analysis.

**Examples**:
```
/market-research "esoteric angel chatbot"              # quick (default)
/market-research "esoteric angel chatbot" deep
/market-research "AI-powered tarot reading app" comprehensive
/market-research #42 deep                              # reads issue for context
```

## Workflow

### Step 1: Scope the Research

**Parse arguments**:
- If `$ARGUMENTS` contains a `#number`, fetch the GitHub issue for context:
  ```bash
  gh issue view <number> --json title,body
  ```
- Extract the product description (everything except the depth keyword).
- Identify depth level: check if last word is `quick`, `deep`, or `comprehensive`. Default to `quick`.

**Gather project context**:
- Read the project's `CLAUDE.md` to understand what the product does.
- Read `README.md` or equivalent if it exists.
- Check `docs/` for any existing market research or competitive analysis.

**Ask clarifying questions** via AskUserQuestion (max 2 questions):
- Target audience / geographic focus (if not obvious from project context)
- Known competitors or adjacent products (saves search time)

### Step 2: Research by Section

Execute web searches scaled by depth level. For every search, record the query used and URLs found.

#### Depth Scaling Table

| Section | Quick | Deep | Comprehensive |
|---------|-------|------|---------------|
| Market Overview | 1 search | 3 searches | 5+ searches, include market size reports |
| Competitors | Identify top 3 | Top 5-8, feature comparison | 10+, feature matrix, pricing teardown |
| Audience | 1 search | 2-3 searches, include forums | Surveys, reviews, community discussions |
| Monetization | 1 search | 2 searches with examples | Case studies, pricing benchmarks, revenue data |

#### Research Execution

For each section below, perform the appropriate number of WebSearch calls based on depth:

**Market Overview**:
- Search: `"<product category> market size trends 2025 2026"`
- Deep+: add searches for growth projections, regional breakdowns
- Comprehensive+: add industry reports, analyst coverage

**Competitor Analysis**:
- Search: `"<product category> apps competitors"`
- For each competitor found: note name, URL, positioning, pricing model, key features
- Deep+: visit competitor websites via WebFetch for pricing and feature details
- Comprehensive+: search for reviews, user complaints, feature gaps

**Audience Segments**:
- Search: `"who uses <product category> demographics"`
- Deep+: search Reddit, forums, app store reviews for user personas
- Comprehensive+: search for survey data, user research reports

**Monetization Models**:
- Search: `"<product category> business model pricing"`
- Deep+: compare freemium vs subscription vs one-time across competitors
- Comprehensive+: search for revenue benchmarks, conversion rates

### Step 3: Synthesize Artifact

Write the research artifact to `docs/market-research.md` in the project directory.

**Template**:

```markdown
# Market Research: <Product Name>

**Date**: YYYY-MM-DD
**Depth**: quick | deep | comprehensive
**Project**: <project name or issue reference>

## Executive Summary

- [3-5 bullet points: market size, key competitors, main opportunity, biggest risk]

## Market Overview

[Market description, size estimates if available, growth trends, key drivers]

**Sources**: [inline citations]

## Competitor Analysis

| Name | URL | Positioning | Pricing | Strengths | Weaknesses |
|------|-----|-------------|---------|-----------|------------|
| ... | ... | ... | ... | ... | ... |

[Narrative analysis of competitive landscape: who dominates, where are gaps]

## Audience Segments

| Segment | Description | Pain Points | Current Solutions |
|---------|-------------|-------------|-------------------|
| ... | ... | ... | ... |

[Key insight about underserved segments]

## Positioning Opportunities

- [Gaps in market that this product could fill]
- [Differentiators vs existing solutions]
- [Timing/trend advantages]

## Monetization Models

| Model | Used By | Pros | Cons |
|-------|---------|------|------|
| ... | ... | ... | ... |

[Recommendation or considerations for this product]

## Gaps for Domain Expert

> These areas require specialist knowledge to validate or expand.

- [ ] [Specific question about market dynamics]
- [ ] [Validation needed for audience assumption]
- [ ] [Competitor detail that needs insider perspective]
- [ ] [Regulatory or compliance considerations]
- [ ] [Cultural or community nuances]

## Sources

| # | URL | Used In | Query |
|---|-----|---------|-------|
| 1 | ... | Market Overview | "query used" |
| 2 | ... | Competitors | "query used" |
```

### Step 4: Review with User

Present a summary of findings (not the full document — the user can read the file). Highlight:
- Most surprising finding
- Biggest gap that needs expert input
- Recommended next steps

Ask if they want to iterate on any section before handing off to their domain expert.

## Design Principles

- **Expert handoff, not final analysis**: The artifact is a starting point. Flag uncertainty, don't hide it.
- **Sources are mandatory**: Every claim must link to a source. Unsourced claims go in "Gaps for Domain Expert".
- **Depth is honest**: If `quick`, don't pretend to be thorough. State limitations explicitly.
- **Project-aware**: Read the codebase to understand what the product actually does — don't research in a vacuum.
- **Iterative**: Ask before researching, present before finishing. Don't monologue.

## Anti-Patterns

- Don't fabricate market data or competitor details — if a search returns nothing, say so
- Don't skip the "Gaps for Domain Expert" section — this is the most valuable part for handoff
- Don't produce a 2000-line document on `quick` depth — match output volume to depth level
- Don't research without understanding the product first (Step 1 before Step 2)
- Don't present the full artifact inline — write to file, present summary
