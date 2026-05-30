# Design — Publish `ai-system-design-guide` as an auto-syncing website on novalien.com

_Date: 2026-05-30 · Status: approved-pending-spec-review · Author: Claude (session)_

## 1. Overview

Turn the cloned `ombharatiya/ai-system-design-guide` — a pure-markdown "living book" (17 numbered chapter folders `00-*`…`17-*` plus root guides: `README`, `COURSES`, `GLOSSARY`, `PATTERNS`, `TRANSITION_GUIDE`, `ai_evals_comprehensive_study_guide`, `ai_evals_complete_guide_langwatch_langfuse`; heavy Mermaid) — into a deployed website at **`ai-system-design-guide.novalien.com`** that **automatically follows the upstream repo on a weekly cadence** with no human in the loop.

This repo's harness files (`CLAUDE.md`, `PROGRESS_Claude.md`, `DECISIONS_Claude.md`, `DEPLOYMENT.md`) were copied wholesale from the unrelated **NovaVMS** project and must be re-aligned to this project as the first work item.

## 2. Goals / Non-goals

**Goals**
- Static website with a left **sidebar nav**, **client-side search**, and rendered **Mermaid** diagrams.
- **Unattended weekly sync** from upstream — new chapters/edits appear automatically.
- Deploy on the existing **HostHatch** box behind the shared Caddy, mirroring the proven `novavms-manual` docs-site pattern.
- Re-align the harness to this project, **keeping all transferable engineering principles**.
- A reusable **deploy skill** for this site.

**Non-goals**
- No editing/rewriting of upstream content. No CMS, no auth, no server-side app. No content versioning (single "latest" mirror). No rebrand beyond a footer credit.

## 3. Locked decisions

| # | Decision | Choice |
|---|----------|--------|
| D1 | Site generator | **MkDocs Material** |
| D2 | Deploy host | **HostHatch "Avon-HostHatch"** behind shared `n8n-docker-caddy` Caddy |
| D3 | Auto-sync cadence | **Fully automatic, weekly** |
| D4 | Sync engine | **Server-side systemd timer** (self-contained; no GitHub Actions runner) |
| D5 | Domain | **`ai-system-design-guide.novalien.com`** |
| D6 | Overlay home | **`Novalien0424/ai-system-design-guide`** (public fork), `upstream` = `ombharatiya` |
| D7 | Branding | **Faithful mirror + footer credit** "Source: ombharatiya/ai-system-design-guide (MIT)"; LICENSE preserved |
| D8 | Build location | On the box, via official **`squidfunk/mkdocs-material`** Docker image |
| D9 | Deploy skill | Project skill `.claude/skills/deploy-ai-system-design-guide/SKILL.md` |

## 4. Core principle — additive overlay, never edit upstream

**The single rule everything depends on:** every file we add is a *new path* upstream does not have. We never modify upstream's content files. Therefore `git merge upstream/main` is always conflict-free, which is what makes unattended weekly sync safe.

Overlay paths (all new): `mkdocs.yml`, `overrides/`, `deploy/` (scripts, Caddy snippet, systemd unit), `requirements.txt`, `.claude/skills/deploy-ai-system-design-guide/`, the re-aligned harness files, and `docs/superpowers/` (process artifacts, excluded from the site build).

Minor residual risk: upstream could someday add a file at one of our overlay paths (e.g. `DEPLOYMENT.md`). The sync script surfaces any merge conflict loudly (no silent failure) and aborts the deploy, leaving the last-good site up — it never auto-resolves.

## 5. Architecture

### 5.1 Repo & remotes
- `origin` → `git@github.com:Novalien0424/ai-system-design-guide.git` (public fork; created in P2).
- `upstream` → `https://github.com/ombharatiya/ai-system-design-guide`.
- The box clones `origin` (public → no auth) and adds `upstream`.

### 5.2 Build (`deploy/build.sh`)
1. `rm -rf build && mkdir -p build/docs`.
2. Copy chapter folders `00-*`…`17-*` and the root content guides into `build/docs/` (README → `index.md`). Upstream files never move, so all relative `.md` cross-links keep resolving.
3. Run MkDocs (docs_dir = `build/docs`, output `site/`) via the pinned `squidfunk/mkdocs-material` Docker image.

`mkdocs.yml` highlights:
- `theme: material` with `navigation`, `toc.integrate`/sidebar, `search` (built-in), dark/light toggle.
- **No hand-maintained `nav:`** — MkDocs auto-builds the sidebar from the folder tree; numbered prefixes (`00-`,`01-`,…) give correct ordering, so new upstream chapters appear automatically.
- Mermaid via `markdown_extensions: pymdownx.superfences` custom fence (`name: mermaid`, Material's mermaid integration).
- `overrides/` (custom_dir) adds the footer credit line.
- `site_url: https://ai-system-design-guide.novalien.com`.

### 5.3 Deploy (mirrors `novavms-manual`)
- `rsync -a --delete site/ /root/ai-system-design-guide/` (idempotent; removed pages disappear).
- Caddy mounts `/root/ai-system-design-guide` as `/srv/ai-system-design-guide:ro` (one line added to `/root/n8n-docker-caddy/docker-compose.yml`).
- Caddy vhost appended to `/root/n8n-docker-caddy/caddy_config/Caddyfile`:
  ```caddy
  ai-system-design-guide.novalien.com {
      root * /srv/ai-system-design-guide
      file_server
      try_files {path} {path}.html {path}/index.html
      header {
          X-Content-Type-Options "nosniff"
          X-Frame-Options "DENY"
          Referrer-Policy "strict-origin-when-cross-origin"
      }
      @hashed path_regexp ^/assets/.+$
      header @hashed Cache-Control "public, max-age=31536000, immutable"
      @html path *.html */
      header @html Cache-Control "public, max-age=300, must-revalidate"
      log { output file /var/log/caddy/ai-system-design-guide.log; format json }
      encode gzip zstd
  }
  ```
- Reload: `docker exec n8n-docker-caddy-caddy-1 caddy reload --config /etc/caddy/Caddyfile`.
- DNS: Namecheap A record `ai-system-design-guide` → HostHatch public IP (same IP `novavms.novalien.com` uses). Caddy auto-issues the cert.

### 5.4 Weekly sync (`deploy/sync-and-deploy.sh` + systemd timer)
A weekly systemd timer (e.g. Mon 04:00) runs on the box:
1. `git fetch origin && git checkout -B main origin/main` (latest overlay).
2. `git fetch upstream && git merge --no-edit upstream/main` — abort loudly on conflict (keep last-good site, exit non-zero).
3. `deploy/build.sh` → `site/` in a temp/working tree.
4. **Healthcheck** the freshly built `site/` (index + a known string present; `mkdocs build` exit 0).
5. Only if healthy: `rsync -a --delete` into the web root (atomic-enough swap).
6. Log to journal. **Fail-loud, keep last-good:** any failed step leaves the current site untouched.

Server-side because the box is Tailscale-only for SSH (public only for HTTP) and self-containment is the lowest-maintenance path — no runner registration, no secrets, public fork fetched with no auth.

## 6. Harness alignment (work item P0)

Rewrite the four NovaVMS-copied files for this project. **Keep** every transferable principle; **drop** only the VMS-specific.

- **Keep:** No silent failures · Simplicity-first / surgical changes · Verification-before-completion ("done" = behavior verified) · WIP=1 · Test-first *where it applies* (build succeeds, link check, healthcheck before swap) · Session clock-in/out protocol · Kill-by-PID-not-name (Windows safety) · Externalize config.
- **Drop:** org_id composite keys · Cloud-owns-AI · SFU/UDP testing · Go/React/ports · gateway/RTSP/streaming · all `docs/prd-*`, `arch-*`, `tasks/*.json` references.
- **New hard constraint (the org_id analog):** **Never edit upstream content — additive overlay only.**
- **New commands:** local preview `mkdocs serve` (:8000, via Docker or venv), `deploy/build.sh`, `deploy/sync-and-deploy.sh`, deploy skill.
- `PROGRESS_Claude.md` and `DECISIONS_Claude.md` reset to this project (decisions = D1–D9 + the additive-overlay principle). `DEPLOYMENT.md` rewritten for MkDocs + Caddy + weekly sync on HostHatch.

## 7. Phasing & dependencies

- **P0 — Harness alignment.** Rewrite `CLAUDE.md`, `PROGRESS_Claude.md`, `DECISIONS_Claude.md`, `DEPLOYMENT.md`. *No external deps.*
- **P1 — Site scaffold + local preview.** `mkdocs.yml`, `overrides/` (footer credit), `deploy/build.sh`, `requirements.txt`. Verify all chapters render + sidebar + search + Mermaid locally (Docker or venv). *No external deps.*
- **P2 — Fork + remotes + push.** Create public `Novalien0424/ai-system-design-guide` (gh CLI if authed, else user creates), set `origin`/`upstream`, push overlay. *Needs: GitHub auth (SSH present; `gh` for repo creation TBD).*
- **P3 — Server deploy.** Clone on box, add Caddy mount+vhost, Namecheap DNS A record, first build+rsync, verify live HTTPS. *Needs: Tailscale SSH to box (Windows-native OpenSSH); Namecheap DNS access.*
- **P4 — Weekly systemd timer.** Install `sync-and-deploy.sh` + `.service`/`.timer`, dry-run once. *Depends on P3.*
- **P5 — End-to-end verify.** Live URL 200 + search works + Mermaid renders + a forced upstream change flows through after a manual timer run.

Plus a deploy skill (`.claude/skills/deploy-ai-system-design-guide/`) authored alongside P3/P4.

## 8. Verification (Definition of Done)

1. **Static/build:** `deploy/build.sh` exits 0; `site/index.html` and a sampled chapter page exist.
2. **Local:** `mkdocs serve` renders every chapter, sidebar navigates, search returns hits, a Mermaid diagram renders.
3. **E2E (live):** `https://ai-system-design-guide.novalien.com` returns 200 over HTTPS with a valid cert; search + Mermaid work in-browser; a deliberately-introduced upstream commit appears after running the sync script manually.

## 9. Risks & mitigations

- **Overlay/upstream path collision** → sync aborts loudly, keeps last-good (§4).
- **Relative links break under MkDocs** → mitigated by preserving the exact folder structure in `build/docs` (§5.2); validated in P1/P5.
- **Shared box blast radius** → touch only `/root/ai-system-design-guide`, our Caddy vhost, and our timer; never broad Docker prunes ([[infra-hosthatch-deploy]]).
- **Mermaid not rendering** → confirm the superfences config in P1 before deploy.

## 10. References
- Memory: `infra-hosthatch-deploy`, `project-novalien-guide-site`.
- Pattern source: NovaVMS `novavms-cloud-deploy` skill + `novavms-web-manual-authoring` astro-starlight deploy conventions (user-authorized cross-project read).
