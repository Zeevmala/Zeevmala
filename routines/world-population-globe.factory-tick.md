# Archived routine — `world-population-globe — factory tick`

Archived 2026-09-02 before deletion, at the account owner's request.

| Field | Value |
|---|---|
| Trigger ID | `trig_01U3Q48GFmFyVKWjTjnxpWvV` |
| Cron | `10 */6 * * *` (4 fires/day, UTC) |
| Created | 2026-08-30T20:10:31Z |
| Last fired | 2026-09-02T18:10:16Z |
| Last run status | **FAILED** (finished 18:12:19Z, session `cse_016V6BVjgeJLW79pYacZ2HJ5`) |
| Environment | `env_01KDQbamizheBm2Et6z2Sbcs` |
| Mode | fresh session per fire |
| Notifications | push: off, email: off |
| Target repo | `zeevmala/world-population-globe` |

## Why it was deleted

Cost ~1,100 tokens per fire × 4 fires/day ≈ **130k tokens/month** in prompt re-transmission alone,
and its most recent run failed. Deleted rather than compressed, per the owner's decision.

## Operational invariants worth preserving

These numbers and guardrails are the load-bearing part of the prompt. If the loop is ever
reinstated, or if the repo's `CLAUDE.md` drifts, these are the values it asserted:

- **Data integrity:** 12,761 tiles, Σ population ≈ 8.03 B, every file < 100 MB.
- **Verifiers:** `npm run verify` (eslint + `tsc -b` + vite build) must exit 0 before any commit;
  `npm run verify:live` hits the deployed site; `npm run verify:data` validates the tile set;
  `npm run qa:render` for render-path changes.
- **Render path** (triggers `qa:render`): `src/layers/**`, `src/lib/{lod,scales,density}.ts`,
  `src/components/Globe.tsx`, `src/data/**`.
- **Pipeline output:** `public/data/**` is generated — never hand-edited.
- **Chromium:** preinstalled at `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`; never run
  `playwright install`. Headless uses SwiftShader, so absolute frame times are not
  hardware-comparable — valid for regression/stall detection only.
- **Branch guardrail:** `main` auto-deploys to the live public site. The loop worked on
  `loop/auto` and never pushed to `main`.
- **Scope guardrail:** exactly one `- [ ]` item from `specs/TODO.md` per fire; no drive-by
  refactors; empty queue → stop rather than invent work.
- **Blocked protocol:** same failure twice in one run → append
  `BLOCKED: <item> — <what was tried and why it failed>` under `## Blocked` in `specs/TODO.md`,
  commit only that state change, push, stop.
- **Compare link** used when no GitHub tooling was available:
  `https://github.com/Zeevmala/world-population-globe/compare/main...loop/auto?expand=1`

## Full prompt (verbatim)

```text
Autonomous maintenance + build tick for the `zeevmala/world-population-globe` repo. You are starting fresh — read the repo first, trust it over anything you remember.

## 0. Orient (always, before anything else)
Read `CLAUDE.md` (operating rules + P0 invariants — binding), `specs/TODO.md` (the queue and the loop contract), `VISION.md`, and `docs/architecture.md`. Run `npm ci`.

## 1. Health first — a red deploy is P0
- If you have GitHub tooling available (see §4), check the latest CI and Pages-deploy runs on `main`. If either is red, diagnose from the failing job log and fix that before touching the queue.
- Run `npm run verify:live` (it hits the deployed site, no GitHub access needed). Any fetch/parse failure or Σ-population mismatch against the live CDN is P0 — fix it before anything else.
- If `specs/TODO.md` has a line starting `BLOCKED:`, attempt ONE fresh approach. If it fails again, leave it and stop.

## 2. One item, exactly
Take the FIRST unchecked `- [ ]` item in `specs/TODO.md`. Implement exactly that item to its stated Accept criteria. Nothing else — no drive-by refactors, no second item, no scope growth. If the queue is empty, say so in one line and stop; do not invent work.

## 3. Verify — no green, no commit
- `npm run verify` must exit 0 (eslint + tsc -b + vite build).
- Touched the render path (`src/layers/**`, `src/lib/{lod,scales,density}.ts`, `src/components/Globe.tsx`, `src/data/**`)? Also run `npm run qa:render` and report its real numbers. Chromium is preinstalled at `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`; do NOT run `playwright install`. Note that headless runs use SwiftShader, so absolute frame times are not hardware-comparable — use them for regressions and stalls, and say so.
- Touched `pipeline/**` or anything under `public/data/**`? Also run `npm run verify:data` (all 12,761 tiles, Σ ≈ 8.03 B, every file < 100 MB). `public/data/**` is pipeline output — never hand-edit it.
- Same failure twice in this run → add a line starting `BLOCKED: <item> — <what you tried and why it failed>` under `## Blocked` in `specs/TODO.md`, commit only that state change, push it, and stop.

## 4. Ship it on a branch — never push to main
`main` auto-deploys to the live public site, so this loop does not write to it.
- Work on the branch `loop/auto` (create it from the latest `origin/main` if it does not exist; if it exists and its PR was already merged, reset it to `origin/main` and start fresh rather than stacking on merged history).
- One conventional commit containing the code change AND the `- [x]` flip in `specs/TODO.md`. Do not put any model name or identifier in the commit message, PR title, PR body, or code comments.
- **`git push -u origin loop/auto` is the deliverable — it must succeed.** Retry up to 4 times with exponential backoff (2s, 4s, 8s, 16s) on network errors.
- Then open or update a PR against `main`, best-effort, using whatever GitHub tooling this session actually has: the GitHub MCP tools (`mcp__github__*`) if they are present, otherwise the `gh` CLI if it is installed. If a PR from `loop/auto` is already open, update it instead of opening a second one. Title it after the item; in the body state what changed, the Accept criteria, and the REAL verifier output you observed.
- **If no GitHub tooling is available in this session, do not fail and do not improvise credentials.** The push already landed. Say plainly that the PR was not opened, and print this one-click link for the human: https://github.com/Zeevmala/world-population-globe/compare/main...loop/auto?expand=1
- Add a sprint-level note to `PROJECT_STATE.md` only when the item closes something substantial.

## 5. Report honestly
Finish with a short summary: which item you took, what you changed, the actual verifier results, the PR link (or the compare link if you could not open one), and anything you could not verify and why. If you observed a number, quote it; if you did not, say so. Exit after one item regardless of outcome.
```
