# AI System Design Guide (novalien.com site) — Decisions (Claude)

<!-- Claude Code session/working decision log: what, why, when. Append newest at top.
     Full design rationale: docs/superpowers/specs/2026-05-30-novalien-mkdocs-site-design.md -->

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
