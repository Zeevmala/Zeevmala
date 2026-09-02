# Context Audit — 2026-09-02

Audit, purge, compress, and restructure of account-level context: skills, routines, artifacts.

## Scope

| Asset | Found | Acted on |
|---|---|---|
| Skills — custom | 3 | **4** (3 rewritten, 1 authored) |
| Skills — Anthropic-managed | 7 | none — see *Out of scope* |
| Routines | 1 | archived, then deleted |
| Artifacts | 2 | reported only — see *Manual follow-ups* |
| Repo `zeevmala/zeevmala` | 0 commits | now holds this source of truth |

---

## Findings

### F1 — Dangling delegation (correctness, not bloat)

`apex-geoai-style` and `web-map-builder` both delegated all spatial technique — CRS, geometry
validity, spatial ops, GeoAI pipelines — to a skill named `geospatial-analysis` that **was not
installed**. Both also carried the rule "never restate a rule owned by another skill."

Net effect: the skill set instructed Claude to withhold spatial-correctness guidance and defer to
nothing. This was the highest-impact finding, and it made the context *smaller than useful* rather
than larger.

**Fixed:** authored `skills/geospatial-analysis/SKILL.md` as the canonical owner. `skills/audit.sh`
check 2 now fails the build on any dangling delegation.

### F2 — CSP-blocked CDN (silent runtime failure)

`web-map-builder` loaded Leaflet from `unpkg.com`. Claude Artifacts allow external scripts only from
cdnjs / jsdelivr / cdn.tailwindcss.com / code.jquery.com, and external stylesheets only from
fonts.googleapis.com. Every map that skill produced into an Artifact failed **silently** — blank
map, no user-visible error.

**Fixed:** switched to cdnjs, and added a delivery-target table making the Artifact vs. GitHub Pages
distinction explicit (in an Artifact, Leaflet's CSS must be inlined — cdnjs is allowed for scripts
only). `audit.sh` check 4 greps `src=`/`href=` attributes, so prose *about* blocked hosts is still
allowed.

### F3 — Duplication violating the skills' own contracts

`web-map-builder:139` declared its `navigationLinks()` block "the only copy;
`github-portfolio-deploy` defers to it." It did not defer — it carried a degraded duplicate
(`github-portfolio-deploy:117-126`) missing the correctness comments explaining that Google's
`destination_place_id` needs a real Place ID and that Apple's `daddr` (not `q`) drives the route.

Also duplicated across skills: OG tag blocks, RTL/bidi rules, the Hebrew font stack, touch-target
sizing, and GitHub Pages deploy steps.

**Fixed:** each block now lives in exactly one skill, with one-line pointers elsewhere.
`audit.sh` check 3 pins nine canonical markers to their owning skill.

### F4 — Internal contradictions

| Contradiction | Resolution |
|---|---|
| `apex-geoai-style:46` forbids encoding pinned versions as fact; `github-portfolio-deploy` pinned four GitHub Action majors and Leaflet 1.9.4 | Kept the workflow runnable, added an explicit "verify current majors — pins were current when written, not verified now" |
| `apex-geoai-style:61` requires touch targets ≥ 44px; `web-map-builder` styled Leaflet zoom controls at 40px | Raised to 44px, with a comment naming the owning rule |

### F5 — Deprecated / off-scope content

- `styled-components` (maintenance mode, no RSC path) — dropped; CSS Modules remains the escape hatch.
- `@rnmapbox/maps (React Native)` — dropped from a *web* map skill's library table.
- `zeevmala.github.io` hardcoded ×3 — replaced with `<user>.github.io`. The literal "zeevmala"
  stays in the skill *description*, where it is a useful trigger term.

### F6 — Routine: high recurring cost, failing

`world-population-globe — factory tick` (`trig_01U3Q48GFmFyVKWjTjnxpWvV`), cron `10 */6 * * *`,
~4,300-char prompt. ~1,100 tok × 4 fires/day ≈ **130k tokens/month** in prompt re-transmission.
Last run **FAILED** 2026-09-02T18:10Z.

**Deleted**, per your instruction. Its prompt and all operational invariants (Σ ≈ 8.03 B, 12,761
tiles, the four `npm run verify*` targets, the Chromium path, the never-push-to-`main` guardrail)
are archived verbatim in [`routines/world-population-globe.factory-tick.md`](routines/world-population-globe.factory-tick.md).
The archive was committed and pushed **before** deletion, since `delete_trigger` is irreversible.

---

## Footprint — measured

Only skill *descriptions* enter every session's system prompt; SKILL.md bodies load on trigger.

**Descriptions — the always-loaded surface:**

| Skill | Before | After | Δ |
|---|---|---|---|
| web-map-builder | 707 | 386 | −45% |
| github-portfolio-deploy | 687 | 333 | −52% |
| apex-geoai-style | 494 | 389 | −21% |
| geospatial-analysis | — | 424 | new |
| **Total** | **1,888 ch / ~472 tok** | **1,532 ch / ~383 tok** | **−19%** |

Down 19% *while adding a fourth skill*. Per surviving skill, −38%.

**Bodies — loaded on trigger:**

| Skill | Before | After | Δ |
|---|---|---|---|
| web-map-builder | 10,488 | 8,657 | −17% |
| github-portfolio-deploy | 6,100 | 4,166 | −32% |
| apex-geoai-style | 4,855 | 3,766 | −22% |
| *Subtotal, like-for-like* | *21,443 / ~5,361 tok* | *16,589 / ~4,147 tok* | *−23%* |
| geospatial-analysis | — | 9,822 | new |
| **Total, 4 skills** | 21,443 | 26,411 | **+23%** |

**Routine:** ~130k tok/month → 0.

### Where the plan's estimates were wrong

The approved plan predicted −39% on descriptions and −47% on the `web-map-builder` body. Actual:
−19% and −17%. Two reasons, both worth recording:

1. **Body filler was thinner than estimated.** After removing the duplicated sections, what remained
   was tables and complete code blocks. `apex-geoai-style` forbids `...` truncation, so the examples
   could not be shortened without breaking that contract. Further cuts would have removed technique,
   not filler.
2. **`web-map-builder` gained content** — the delivery-target CDN table (F2) is new and load-bearing.

The description layer — the one that costs on *every* session — did deliver. Total context is up
23% in on-trigger bytes; that is the deliberate price of F1, which you approved.

---

## Files

```
skills/geospatial-analysis/SKILL.md      new — canonical spatial-technique owner
skills/web-map-builder/SKILL.md          rewritten
skills/apex-geoai-style/SKILL.md         rewritten
skills/github-portfolio-deploy/SKILL.md  rewritten
skills/audit.sh                          regression harness, exits non-zero on violation
routines/world-population-globe.factory-tick.md   archived before deletion
```

`skills/audit.sh` is the durable part. It encodes the four failure classes above as assertions, so
the next edit that reintroduces a dangling delegation, a duplicate canonical block, or a blocked CDN
fails loudly instead of silently.

Verified by deliberately reintroducing all three regressions into a scratch copy; each was caught.
The two Python blocks in `geospatial-analysis` were executed under Shapely 2.1.2 — the `buffer(0)`
anti-pattern claim is backed by a measured result (bowtie: `make_valid` → area 2.0, `buffer(0)` →
area 1.0).

---

## Manual follow-ups

These cannot be done from a Claude Code session:

1. **Re-upload the four skills to claude.ai.** `/root/.claude/skills/synced/` is a one-way,
   ephemeral mirror — edits there never propagate back, and the container is reclaimed after
   inactivity. This repo is the source of truth; upload via claude.ai skill settings or the
   `skill-creator` skill.
2. **Delete two stale artifacts.** The Artifact tool has no delete action. Both are one-off morning
   briefs with no reuse value:
   - `Monday, August 10 2026` — https://claude.ai/code/artifact/a2152182-e85a-401c-a6d0-e73d19e618b5
   - `Wednesday · August 5` — https://claude.ai/code/artifact/b6a93e67-dbf8-411d-a9cd-ec3a65653514

   Remove them at https://claude.ai/code/artifacts.
3. **Optional — measure trigger accuracy.** Description compression trades against trigger recall.
   The installed `skill-creator` skill ships an eval harness (`scripts/run_eval.py`) that can
   confirm the shortened descriptions still fire on their keywords. Worth running rather than
   assuming.

## Out of scope

Seven skills (`docx`, `pptx`, `xlsx`, `pdf`, `skill-creator`, `morning`, `import-memory`, ~3.4 MB,
mostly OOXML schemas) are Anthropic-managed and overwritten on every sync. Editing them is wasted
work. Their descriptions cost ~1,036 always-loaded tokens and are not reducible from here — the only
lever is removing a skill you do not use from your account.
