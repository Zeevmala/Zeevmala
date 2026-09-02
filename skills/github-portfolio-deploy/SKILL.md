---
name: "github-portfolio-deploy"
description: "Pre-publish QA and GitHub Pages deployment for portfolio web projects. Triggers: GitHub Pages, deploy, publish, go live, portfolio site, branch protection, OG tags, social preview, pre-launch checklist, making a repo public, or the user's GitHub (zeevmala). Covers CI workflow, SEO/OG, a11y, performance budget, deploy anti-patterns."
---

# GitHub Portfolio Deploy

Pre-publish QA and Pages deployment. RTL/bilingual rules and map render thresholds →
`web-map-builder`; touch targets and frontend conventions → `apex-geoai-style`.

## Pre-Publish QA

Flag every failure to the user.

| Area | Checks |
|---|---|
| Function | No 404s or `localhost` refs; data loads (GeoJSON, endpoints reachable); filters/search/map controls work; console clean; placeholder content removed |
| Bilingual | Hebrew renders; mixed he/en bidi flows correctly; RTL control positions correct (rules → `web-map-builder`) |
| Responsive | Viewport meta present; layout holds at `[320, 375, 768, 1024, 1440]`px; no horizontal scroll; sidebar collapses or becomes a bottom sheet |
| SEO/social | `<title>` < 60 ch; `<meta name="description">` < 160 ch; OG tags complete; OG image 1200×630; `favicon.ico` present |
| Performance | HTML < 500 KB standalone (< 100 KB without data); images WebP/compressed; data files compressed; no unused deps |
| A11y | Contrast ≥ 4.5:1 (WCAG AA); keyboard navigable; ARIA labels on icon-only buttons; map has a text alternative |

```html
<meta property="og:title" content="Project Title" />
<meta property="og:description" content="Brief description" />
<meta property="og:image" content="https://<user>.github.io/<repo>/preview.png" />
<meta property="og:url" content="https://<user>.github.io/<repo>/" />
<meta property="og:type" content="website" />
```

Navigation deep links (Waze/Google/Apple): use `navigationLinks()` from `web-map-builder` — that is
the only copy, and it carries the `destination_place_id` and `daddr` correctness comments.

## Repository Setup

**Branch protection** (collaborative repos): Settings → Branches → rule on `main` —
require PR reviews (1), require status checks, require conversation resolution, no bypass.

**Pages — static:** Settings → Pages → Deploy from branch → `main`, `/` or `/docs`.

**Pages — with a build step:** `.github/workflows/deploy.yml`. Verify current action majors before
committing; the pins below were current when written, not verified now.

```yaml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]
permissions:
  contents: read
  pages: write
  id-token: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - name: Setup Pages
        uses: actions/configure-pages@v4
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: '.'
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

## README Skeleton

```markdown
# Project Name

One or two sentences.

🔗 **[Live Demo](https://<user>.github.io/<repo>/)**

## Features
## Tech Stack
## Screenshot
![Screenshot](preview.png)
## Data Sources
## License
MIT
```

## Post-Deploy Verification

1. Load `https://<user>.github.io/<repo>/` (Pages takes 1–2 min).
2. Test on a real mobile device or DevTools device mode.
3. Paste the URL into WhatsApp/Telegram — confirm the OG preview renders.
4. Test navigation deep links on mobile.
5. Repo "About": website URL and description set.

## Anti-Patterns to Flag

- **`console.log` left in** — clean before publish.
- **Absolute paths** — Pages serves from a subdirectory; use `./data.json`, not `/data.json`.
- **Expecting CORS headers** — Pages is static-only; co-locate data files or use a CORS-friendly API.
- **Large binaries in git** — Git LFS or external hosting; keep the repo under 100 MB.
- **No `.gitignore`** — exclude `node_modules/`, `.env`, `.DS_Store`.
- **A root `README.md` in a profile repo** (`<user>/<user>`) — it renders publicly on the GitHub
  profile page. Deliberate only.
