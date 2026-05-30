# AI System Design Guide — Site Overlay · Claude Code Guidelines
> Static docs site (**MkDocs Material**) that auto-mirrors `ombharatiya/ai-system-design-guide` → **ai-system-design-guide.novalien.com**, self-hosted on HostHatch behind the shared Caddy. Weekly unattended upstream sync.

## ⚠️ Hard Constraints (non-negotiable)
- **Never edit upstream content** — the numbered chapter folders (`00-*`…`17-*`) and the root content guides (`README`, `COURSES`, `GLOSSARY`, `PATTERNS`, `TRANSITION_GUIDE`, `ai_evals_*`). Our work is an **additive overlay only** — every change is a *new* path upstream doesn't have, so weekly `git merge upstream/main` stays conflict-free. **This is THE core rule** (the analog of a multi-tenant DB's tenant-key invariant). If a fix seems to need an upstream edit, stop and rethink — it belongs in `overrides/`, `mkdocs.yml`, or the build script.
- **No silent failures** — build/sync/deploy scripts fail loud (`set -euo pipefail`, `err: %w`-style context) and **keep the last-good site**; never `rsync`-swap a broken or unhealthy build.
- **Externalize config** — domain/paths live in `mkdocs.yml`, `deploy/`, and the Caddyfile; secrets are never committed. Ask the user on any access/credential issue.
- **Touch only our own paths on the shared box** — `/root/ai-system-design-guide`, our Caddy vhost block, our systemd unit. The box co-hosts n8n, Supabase, NovaVMS, castwise, etc. **NEVER** `docker system prune` or any broad cleanup. (→ memory `infra-hosthatch-deploy`)
- **Kill by PID, never by name** — NEVER `taskkill /IM node.exe` (kills Claude Code) or `/IM python.exe`.
- **WIP = 1** — finish and verify one phase before starting the next.
- **Ops SSH = Windows-native OpenSSH over Tailscale** — `/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 '<single-quoted cmd>'`. Git Bash ssh can't reach the Windows agent. Legacy Hetzner `5.78.143.205` is **DEAD**.

## How to Use This File
Entry point — load other docs only when the task needs them; never speculatively.

| Task | Load |
|------|------|
| Overall design / locked decisions | `docs/superpowers/specs/2026-05-30-novalien-mkdocs-site-design.md` · `DECISIONS_Claude.md` |
| Session state (clock-in/out) | `PROGRESS_Claude.md` |
| Deploy / ops / server | `DEPLOYMENT.md` · `.claude/skills/deploy-ai-system-design-guide/SKILL.md` · memory `infra-hosthatch-deploy` |
| Site config / build | `mkdocs.yml` · `overrides/` · `deploy/build.sh` · `deploy/sync-and-deploy.sh` |
| Editing the harness (CLAUDE.md/skills) | this file + the spec |

## Core Principles
1. **Additive overlay** — every change is a new path; never mutate upstream content (D-overlay).
2. **Simplicity first** — minimal, surgical changes; every changed line traces to the request; match existing style.
3. **Fix root causes, not symptoms.**
4. **Verification before completion** — "done" = behavior verified (build → local preview → live URL), not code written.
5. **Validate early** — fail at the script boundary with a clear message, not deep in a deploy.
6. **Think before coding** — state assumptions; present options, don't pick silently; push back when a simpler path exists.
7. **TypeScript/JS (if any tooling): `unknown` + type guards, never `any`.**

## Development Workflow
1. **RCA** — reproduce / identify the failing signal before editing.
2. **Plan** — non-trivial scope: brainstorm → write/confirm a plan (→ `brainstorming`, `writing-plans`).
3. **Propose** — surface the approach before large edits.
4. **Implement** — surgical, additive changes.
5. **Codex review** — run `codex review` (codex-cli) on the diff with Bash `timeout: 600000` + `run_in_background: true` (NOT the Opus reviewer subagent); address findings before deploying.
6. **Verify E2E** — build green → local `mkdocs serve` → live URL (see Definition of Done).

## Session Protocol (continuity)
- **Clock-in:** read `PROGRESS_Claude.md` → confirm build + local preview are green → resume from "Next steps".
- **Clock-out:** update `PROGRESS_Claude.md` (done / in-progress / blocked / next + last-verified commit) → commit **when the user asks**.
- Decisions: design/architecture/ops → `DECISIONS_Claude.md`. Session state → `PROGRESS_Claude.md`.

## Definition of Done (no skipping layers)
1. **Build** — `deploy/build.sh` exits 0; `site/index.html` and a sampled chapter page exist.
2. **Local** — `mkdocs serve` renders every chapter, the sidebar navigates, search returns hits, a Mermaid diagram renders.
3. **E2E** — `https://ai-system-design-guide.novalien.com` returns 200 over HTTPS (valid cert); search + Mermaid work in-browser; an upstream change flows through after a sync run. **Mandatory for any deploy/sync change.**

## Commands
```bash
# Local preview (Docker)   docker run --rm -p 8000:8000 -v "${PWD}:/docs" squidfunk/mkdocs-material   # http://127.0.0.1:8000
# Local preview (venv)     pip install -r requirements.txt && mkdocs serve              # :8000
# Build static site        bash deploy/build.sh                                          # → ./site
# Weekly sync + deploy      bash deploy/sync-and-deploy.sh                                # run on the box (systemd timer)
# Deploy from this PC       /c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 '<cmd>'  # see DEPLOYMENT.md / deploy skill
# Reload Caddy (on box)     docker exec n8n-docker-caddy-caddy-1 caddy reload --config /etc/caddy/Caddyfile
```
Ports — local MkDocs dev server **:8000**. Server details → `DEPLOYMENT.md` / memory `infra-hosthatch-deploy`.

## Quality Gates
- **Before commit:** build passes · local preview OK · config externalized · no upstream content edited · `PROGRESS_Claude.md` updated.
- **Before deploy:** never edit upstream · last-good site preserved on any failure · touch only our paths · cert/DNS resolves.
