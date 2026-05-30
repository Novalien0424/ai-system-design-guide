# Deployment — ai-system-design-guide.novalien.com

A static **MkDocs Material** site that mirrors `ombharatiya/ai-system-design-guide`, self-hosted on the **HostHatch** box ("Avon-HostHatch") behind the shared `n8n-docker-caddy` Caddy, with a **weekly systemd timer** that auto-follows upstream. Mirrors the proven `novavms-manual` docs-site pattern: build → `rsync` → Caddy `file_server`. The deploy skill `deploy-ai-system-design-guide` automates the steps below.

> Connection facts (SSH, Caddy paths, DNS, guardrails) live in memory `infra-hosthatch-deploy`. Overlay rule: **never edit upstream content** — see `CLAUDE.md`.

## Two directories (don't confuse them)
- **Build source:** `/root/ai-system-design-guide-src` — the git clone of the fork (+ `upstream` remote). Builds happen here.
- **Served web root:** `/srv/ai-system-design-guide` — bind-mounted `:ro` into Caddy. The publish step rsyncs the built `site/` into here.

## Architecture
```
weekly systemd timer (on HostHatch)
  → git fetch upstream + merge (conflict-free; additive overlay)
  → deploy/build.sh  (copy 00-*…17-* + root guides → build/docs → mkdocs build → ./site)
  → healthcheck the fresh build
  → rsync -a --delete --delay-updates site/ → /srv/ai-system-design-guide/  (near-atomic; only if healthy)
        ↓ bind-mounted read-only
  Caddy (n8n-docker-caddy-caddy-1) serves /srv/ai-system-design-guide  (file_server)
        ↓
  ai-system-design-guide.novalien.com  (Cloudflare A → HostHatch public IP 151.242.74.12 → Caddy :443)
```
No Docker image build for the site itself, no registry, no container restart on deploy. Build uses the pinned `squidfunk/mkdocs-material:9.6.22` image; output is plain static files.

## Server (Avon-HostHatch)
- **Ops SSH (Tailscale):** `/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 '<single-quoted cmd>'` (Windows-native OpenSSH only). Legacy Hetzner `5.78.143.205` is **dead**.
- **Caddy:** container `n8n-docker-caddy-caddy-1`; stack `/root/n8n-docker-caddy/`; Caddyfile `/root/n8n-docker-caddy/caddy_config/Caddyfile`; compose `/root/n8n-docker-caddy/docker-compose.yml`.
- **Guardrail:** shared box (n8n, Supabase, NovaVMS, …). Touch only our build source, served root, vhost, and timer. **Never** `docker system prune` or broad cleanup.

## One-time bootstrap (P3 / P4)
1. **DNS (Cloudflare):** A record `ai-system-design-guide` → `151.242.74.12`, **Proxy = DNS only (grey cloud)** so Caddy can issue the cert. Confirm: `dig +short ai-system-design-guide.novalien.com @1.1.1.1`.
2. **Clone the fork on the box:**
   ```bash
   /c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'git clone https://github.com/Novalien0424/ai-system-design-guide.git /root/ai-system-design-guide-src \
     && cd /root/ai-system-design-guide-src \
     && git remote add upstream https://github.com/ombharatiya/ai-system-design-guide.git \
     && git fetch upstream \
     && mkdir -p /srv/ai-system-design-guide'
   ```
3. **First build + publish:** run the sync script (see "Routine deploy" below). It builds and rsyncs into `/srv/ai-system-design-guide`.
4. **Caddy mount:** add `- /srv/ai-system-design-guide:/srv/ai-system-design-guide:ro` to the `caddy` service `volumes` in `/root/n8n-docker-caddy/docker-compose.yml` (back it up first), then `cd /root/n8n-docker-caddy && docker compose up -d caddy`.
5. **Caddy vhost:** append `deploy/caddy/ai-system-design-guide.caddy` to the Caddyfile (back it up first), then validate + reload:
   ```bash
   docker exec n8n-docker-caddy-caddy-1 caddy validate --config /etc/caddy/Caddyfile \
     && docker exec n8n-docker-caddy-caddy-1 caddy reload --config /etc/caddy/Caddyfile
   ```
6. **Weekly timer:** install the units from `deploy/systemd/`:
   ```bash
   /c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'cp /root/ai-system-design-guide-src/deploy/systemd/ai-system-design-guide-sync.* /etc/systemd/system/ \
     && systemctl daemon-reload && systemctl enable --now ai-system-design-guide-sync.timer'
   ```

## Routine deploy (manual, on demand)
```bash
/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'cd /root/ai-system-design-guide-src && bash deploy/sync-and-deploy.sh'
```
`sync-and-deploy.sh` is idempotent and **fail-loud**: on any merge/build/healthcheck failure it logs and exits non-zero **without** publishing, leaving the last-good site live. The publish uses `rsync --delete --delay-updates`, which stages all files and batch-renames them into place at the end, so an interrupted transfer leaves the previous site intact. (A full directory swap is avoided because the served path is a Docker bind-mount — moving the directory would leave the container on the old inode.)

## Weekly auto-sync
The systemd timer runs `deploy/sync-and-deploy.sh` weekly (Mon 04:00). Inspect:
```bash
/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'systemctl status ai-system-design-guide-sync.timer --no-pager; journalctl -u ai-system-design-guide-sync.service --no-pager -n 50'
```

## Verify
```bash
# Live HTTPS + cert
curl -sI https://ai-system-design-guide.novalien.com | head -5
# Build artifact present on the box
/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'ls /srv/ai-system-design-guide/index.html && cat /srv/ai-system-design-guide/.version 2>/dev/null'
```
In-browser: sidebar navigates, search returns hits, a Mermaid diagram renders.

## Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| Cert not issued / TLS error | DNS not resolving, or Cloudflare proxied (orange) | Confirm the Cloudflare A record is **DNS-only (grey)**; wait ~2 min; re-hit the URL |
| 404 on all pages | Caddy mount missing or wrong root | Verify the `:ro` volume + vhost `root`; `caddy validate` then reload |
| Site didn't update after sync | build/healthcheck failed (last-good kept) | `journalctl -u ai-system-design-guide-sync.service` — fix the error, re-run the script |
| Merge conflict during sync | upstream added a file at an overlay path | Resolve manually; rename our overlay file to a non-colliding path; never auto-resolve |
| SSH refuses keys | Windows ssh-agent stopped | `Get-Service ssh-agent \| Start-Service` (elevated), retry |
| Mermaid not rendering | CDN blocked at view-time | Confirm internet to unpkg; if persistent, self-host mermaid via `extra_javascript` |
