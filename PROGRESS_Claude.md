# AI System Design Guide (novalien.com site) — Progress (Claude)

<!-- Claude Code session-state snapshot. Update at clock-out. Design: docs/superpowers/specs/2026-05-30-novalien-mkdocs-site-design.md · Decisions: DECISIONS_Claude.md. -->

_Updated: 2026-05-30 · Building `ai-system-design-guide.novalien.com` (MkDocs Material · HostHatch+Caddy · weekly auto-sync). P0+P1 done & locally verified; deploy scripts + skill written; fork repo created; **codex review running**, then push (P2) + server deploy (P3/P4)._

## In progress (WIP = 1)
- **Codex review** of the overlay (`codex review --uncommitted`, background) → address findings → then P2 push + P3 deploy.

## Done
- **P0 — Harness alignment:** `CLAUDE.md` (incl. re-added Codex-review step), `PROGRESS_Claude.md`, `DECISIONS_Claude.md`, `DEPLOYMENT.md` re-aligned from NovaVMS to this project. Memories saved: `infra-hosthatch-deploy`, `project-novalien-guide-site`, `feedback-codex-review-and-autonomy`.
- **P1 — Site scaffold + LOCAL VERIFY (green):** `mkdocs.yml`, `deploy/build.sh` (assembles `build/docs` from numbered folders + root guides; never touches upstream), `deploy/hooks/nav_titles.py` (prettifies sidebar section labels), `requirements.txt` (`mkdocs-material==9.6.22`), `.gitignore`. Built **129 pages** (128 content + 404), search index 1289 records, sidebar + chapters + emoji render in-browser. **32 build warnings = all genuine upstream broken/forward links** (CONTRIBUTING.md + unwritten chapters), faithfully mirrored, not fixed. **Mermaid:** config correct (superfences) but loads from a CDN → only verifiable on the live site (P5).
- **Deploy artifacts written:** `deploy/sync-and-deploy.sh` (fail-loud weekly sync, keep last-good), `deploy/systemd/*.service|*.timer` (Mon 04:00), `deploy/caddy/ai-system-design-guide.caddy` (vhost), `.claude/skills/deploy-ai-system-design-guide/SKILL.md`.
- **Infra recon (authorized):** HostHatch `root@100.70.175.62`, public IP `151.242.74.12`, Caddy `n8n-docker-caddy-caddy-1`, web roots `/srv/<name>:ro`. `gh` authed as Novalien0424. **DNS:** user wired `ai-system-design-guide.novalien.com` on Cloudflare (must be DNS-only/grey).
- **Fork created:** `https://github.com/Novalien0424/ai-system-design-guide` (public, empty — push pending after review).

## Blocked
- (none)

## Next steps
1. **Address codex findings**, then **P2:** `origin`→`upstream`, add fork as `origin`, commit overlay, `git push -u origin main`.
2. **P3 — Server deploy** (via the deploy skill): clone on box, `sync-and-deploy.sh` first run, Caddy mount + vhost + reload, verify live HTTPS.
3. **P4 — Weekly timer:** install + enable `ai-system-design-guide-sync.timer`; dry-run.
4. **P5 — E2E verify on live:** 200 + valid cert + search + **Mermaid renders** + a forced upstream change flows through.

## Notes
- Upstream baseline commit: `2173b9d`. Build is non-strict on purpose (upstream link quirks must not break unattended publishing; healthcheck is the gate).
- Local preview: `export PATH="$PWD/.venv/Scripts:$PATH" && bash deploy/build.sh` then serve `site/` (Docker fallback in build.sh is for the box; on Windows always use the venv to avoid Git-Bash docker path mangling).
