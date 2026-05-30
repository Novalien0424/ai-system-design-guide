# AI System Design Guide (novalien.com site) — Progress (Claude)

<!-- Claude Code session-state snapshot. Update at clock-out. Design: docs/superpowers/specs/2026-05-30-novalien-mkdocs-site-design.md · Decisions: DECISIONS_Claude.md. -->

_Updated: 2026-05-30 · **✅ LIVE & AUTO-SYNCING.** `https://ai-system-design-guide.novalien.com` serves the MkDocs Material mirror (HTTP 200, valid LE cert via Cloudflare). Weekly upstream auto-sync timer enabled. Last published: `fc20db0`, 129 pages._

## In progress (WIP = 1)
- (none) — project delivered end-to-end and verified live.

## Done (P0–P5, all verified)
- **P0 Harness alignment** — `CLAUDE.md` (+ re-added Codex-review step), `PROGRESS_Claude.md`, `DECISIONS_Claude.md`, `DEPLOYMENT.md` re-aligned from NovaVMS.
- **P1 Site scaffold** — `mkdocs.yml`, `deploy/build.sh` (assembles `build/docs` from numbered folders + root guides; never edits upstream), `deploy/hooks/nav_titles.py` (prettified sidebar labels), `deploy/assets/mermaid-init.js` (reliable Mermaid render shim), `requirements.txt`, `.gitignore`, `.gitattributes` (LF).
- **P2 Fork + push** — public `Novalien0424/ai-system-design-guide` (`upstream` = ombharatiya). HEAD `fc20db0`.
- **P3 Server deploy** — cloned on box (`/root/ai-system-design-guide-src`), built via Docker `squidfunk/mkdocs-material:9.6.22`, published to `/srv/ai-system-design-guide`, Caddy mount + vhost added to the shared `n8n-docker-caddy` stack, LE cert issued through Cloudflare. Neighbor sites (novavms, novavms-manual, n8n) verified still 200.
- **P4 Weekly timer** — `ai-system-design-guide-sync.timer` installed + enabled (Mon 04:00 UTC; next 2026-06-01 04:03).
- **P5 E2E verify (live)** — 200 + valid cert; sidebar nav; search returns hits (1289-record index); **Mermaid diagrams render** (verified via browser + screenshot); a sync redeploy flowed `e9c06c5`→`fc20db0` through cleanly.
- **Deploy skill** — `.claude/skills/deploy-ai-system-design-guide/SKILL.md`.
- **Codex reviews** — 2 rounds on the deploy path; all findings fixed (DEPLOYMENT.md path/web-root consistency, `--delete-delay` last-good safety, pinned git identity for unattended merges).

## Blocked
- (none)

## Next steps / optional hardening
1. **Monitor the first auto-sync** (Mon 2026-06-01 04:03 UTC): `journalctl -u ai-system-design-guide-sync.service`.
2. **Optional: self-host Mermaid** to drop the CDN dependency entirely (currently Material loads it from its CDN; the shim makes rendering reliable, but a pinned local copy would remove the external dependency).
3. **Upstream broken links** (32 build warnings) are genuine upstream forward-references (unwritten chapters, missing CONTRIBUTING.md/LICENSE) — faithfully mirrored, not fixed.

## Notes / how-to
- Manual redeploy: `ssh root@100.70.175.62 'cd /root/ai-system-design-guide-src && bash deploy/sync-and-deploy.sh'` (or the deploy skill).
- Local preview: `export PATH="$PWD/.venv/Scripts:$PATH" && bash deploy/build.sh` then serve `site/`.
- Caddy/compose backups on the box: `/root/n8n-docker-caddy/*.bak-asdg-*` / `*.bak-net-*`.
