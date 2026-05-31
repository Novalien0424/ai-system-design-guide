# AI System Design Guide (novalien.com site) — Decisions (Claude)

<!-- Claude Code session/working decision log: what, why, when. Append newest at top.
     Full design rationale: docs/superpowers/specs/2026-05-30-novalien-mkdocs-site-design.md -->

## 2026-05-31 — Frontend restyle: "Slash / Midnight Ledger" design system

- **Applied `docs/DESIGN.md` as a CSS-only additive overlay (`deploy/assets/slash.css` + `extra_css`), not template overrides.** Why: preserves the merge-safe overlay invariant — one stylesheet remaps the Slash tokens onto Material's `--md-*` custom properties; no Material templates or upstream content touched. Rejected: `overrides/` template hacking (unnecessary for colour/spacing/fonts; more surface to maintain on upstream/theme bumps).
- **Dark-only — dropped the light/dark toggle (`palette: {scheme: slate}`).** Why: the spec is explicitly dark-only ("don't introduce light-mode components"); colours are remapped onto the slate scheme. Tradeoff: no light reading mode (user chose faithful over docs-accessibility). Rejected: dual light+dark (more work, diverges from spec).
- **Inter (body/UI) + Playfair Display (display headings h1/h2).** Why: Playfair is the spec's named substitute for the commercial Ivy Presto, giving the Inter↔serif contrast. Loaded from Google Fonts via `@import` inside `slash.css` with `theme.font: false` (single loading path, no double-load). Rejected: self-hosting woff2 (more setup; user chose CDN) and Inter-only (loses the serif display contrast).
- **Looser reading line-height (1.72) than the spec's 1.38; kept tight letter-spacing.** Why: the source spec targets a marketing site — long-form docs need a comfortable measure. Retained the spec's near-black layered surfaces, gold (`#cc9166`) links/accents, pill controls, 10px card radius, shadow-free elevation (hairlines, not drop shadows).
- **Content max-width set to 1216px in px, not rem.** Why: Material's root font-size is 20px (not 16px), so the spec's `76rem` would have rendered 1520px — too wide a reading measure. Pinning `.md-grid { max-width: 1216px }` matches the spec exactly (verified live: content column ≈866px between the two rails).
- **Section-rail labels use Silver (`#acafb9`), not Stone (`#777a88`).** Why: WCAG AA contrast on the near-black nav rail; the spec's tertiary-text intent is preserved by size/weight/uppercase, not by a sub-AA colour.
- **Cache-bust fix (codex P2): scope Caddy `immutable` to fingerprinted assets only.** Why: the old `@hashed path_regexp ^/assets/.+$` applied `max-age=31536000, immutable` to *every* `/assets/*` — including our unhashed overlay files (`slash.css`, `mermaid-init.js`), which would pin a year-long cache and block future CSS fixes. Now `@fingerprinted \.[0-9a-f]{8,}\.` gets `immutable`; everything else (HTML + unhashed overlays) gets `max-age=300, must-revalidate`. (codex review caught this; the only finding.)
- **Mermaid left to Material's palette-sync (shim untouched).** Why: forcing the slate scheme makes Material theme the diagrams dark automatically — verified live (full flowchart renders: dark subgraph cards, gold-outlined nodes, legible white labels, gold connectors); no need to change the render shim.

## 2026-05-30 — Deploy session (site went LIVE)
- **Cloudflare stays PROXIED (orange) — do NOT force grey.** Why: all existing novalien.com sites on this box are CF-proxied with plain Caddy vhosts (no `tls` directive); Caddy completes the LE HTTP-01 challenge *through* the proxy and gets a real cert. Confirmed live (cert obtained for our host). Rejected: switching to DNS-only (would diverge from the box convention; proxy gives caching/DDoS/origin-hiding).
- **Declared the shared Caddy network `external: true`.** Why: `n8n-docker-caddy_default` predates compose's labels (empty `com.docker.compose.network`), so `docker compose up` refused to recreate the caddy container to pick up the new mount. Declaring the existing network external lets compose recreate without relabelling. Safe (all services already use it); validated with `docker compose config` before recreate; neighbor sites verified 200 after. Rejected: recreating the network (would disconnect every service).
- **Publish with `rsync --delete-delay --delay-updates`, not a dir swap.** Why: the served path is a Docker bind-mount, so `mv`-ing the directory leaves Caddy on the old inode; `--delete-delay` applies deletions only after a successful transfer, so an interrupted publish keeps last-good. (codex P1.)
- **Pin a git identity inside `sync-and-deploy.sh`.** Why: the first non-fast-forward upstream merge on the root checkout would otherwise fail "Committer identity unknown" and stop the weekly sync. (codex P2.)
- **Mermaid render shim (`deploy/assets/mermaid-init.js`).** Why: Material loads mermaid from its CDN but its auto-render misses the first paint (race with `navigation.instant`); the shim issues an idempotent `mermaid.run()` on load + each instant-nav swap. Verified rendering live. Rejected: removing `navigation.instant` (unproven fix; loses the snappy nav).
- **Build location = the box (Docker `squidfunk/mkdocs-material:9.6.22`).** Why: reproducible, nothing installed on the host. Windows local preview uses the venv (Git-Bash + Docker mangles the `-v` path).

## 2026-05-30 — Project kickoff: publish the guide as an auto-syncing website

- **D-overlay (core): additive overlay — never edit upstream content.** Why: every overlay file is a new path upstream doesn't have, so `git merge upstream/main` is always conflict-free, which is what makes unattended weekly sync safe. Rejected: editing/restructuring upstream markdown (would conflict on every sync), forking the content (defeats "follow the latest").
- **D1: site generator = MkDocs Material.** Why: purpose-built for markdown docs; left sidebar auto-generated from the numbered folder prefixes (new chapters appear automatically), built-in client-side search, native Mermaid; renders the existing folders with minimal transformation. Rejected: Astro Starlight (needs a content-mapping step; chosen for `novavms-manual` but heavier here), Docusaurus/VitePress (more config for the existing layout).
- **D2: deploy host = HostHatch "Avon-HostHatch" behind the shared `n8n-docker-caddy` Caddy.** Why: reuses the exact proven `novavms-manual` docs-site pattern on a box the user already runs. Rejected: Cloudflare/GitHub Pages (moves hosting off-box; user wants it on novalien.com infra).
- **D3 + D4: fully-automatic weekly sync via a server-side systemd timer.** Why: self-contained — the box keeps itself current with no GitHub Actions runner to register/maintain, no secrets, and a public fork it can fetch with no auth. The box is Tailscale-only for SSH, so a server-resident job is the natural fit. Rejected: self-hosted GitHub Actions runner (more observable but more setup/maintenance), daily (unnecessary churn), review-gate PRs (user wants hands-off).
- **D5: domain = `ai-system-design-guide.novalien.com`.** Why: user choice; dedicated subdomain, clean Caddy vhost, keeps the apex free.
- **D6: overlay home = public fork `Novalien0424/ai-system-design-guide`, `upstream` = ombharatiya.** Why: version-controlled overlay the user controls; public is natural for MIT content and lets the box fetch with zero auth. Rejected: server-local-only (no off-box backup), private (needs a deploy key for no real benefit).
- **D7: faithful mirror + footer credit, LICENSE preserved.** Why: MIT requires attribution; simplest to maintain; no per-page rebrand churn. Rejected: light novalien chrome (more upkeep for little gain now).
- **D8: build on the box via the official `squidfunk/mkdocs-material` Docker image.** Why: reproducible, nothing installed on the host. Build script copies `00-*`…`17-*` + root guides into a generated `build/docs/` (docs_dir) so upstream files never move and relative links keep resolving.
- **D9: deploy skill = project skill `.claude/skills/deploy-ai-system-design-guide/`.** Why: version-controlled in the fork, travels with the project; modeled on `novavms-cloud-deploy`.

## Out of scope (this project)
- NovaVMS code/harness, content versioning, auth/CMS, rebrand beyond the footer credit.

<!-- Template:
## YYYY-MM-DD — <topic>
- **<decision>.** Why: <rationale>. Rejected: <alternative>. -->
