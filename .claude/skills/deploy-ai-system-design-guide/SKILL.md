---
name: deploy-ai-system-design-guide
description: Deploy / update the AI System Design Guide static site (MkDocs Material) to ai-system-design-guide.novalien.com on the HostHatch server ("Avon-HostHatch", 100.70.175.62) behind the shared Caddy. Use whenever the user mentions deploying this guide/site, publishing to novalien.com, redeploying, "push the guide live", updating the mirror, rebuilding the site, checking the site, or setting up the weekly upstream sync. Mirrors the novavms-manual docs-site deploy pattern (build -> rsync -> Caddy file_server).
---

# Deploy: ai-system-design-guide.novalien.com

A static MkDocs Material mirror of `ombharatiya/ai-system-design-guide`, served on the
HostHatch box behind the shared `n8n-docker-caddy` Caddy. A weekly systemd timer
auto-follows upstream. **Overlay is additive-only — never edit upstream content.**

## Infrastructure (memory: `infra-hosthatch-deploy`)
- **Ops SSH:** `/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 '<single-quoted cmd>'`
  (Windows-native OpenSSH over Tailscale; Git Bash ssh can't reach the agent). Legacy
  Hetzner `5.78.143.205` is **dead**. Public IP `151.242.74.12` serves HTTP only.
- **Build source:** `/root/ai-system-design-guide-src` (clone of the fork + `upstream` remote)
- **Web root (served):** `/srv/ai-system-design-guide` (mounted `:ro` into Caddy)
- **Caddy:** container `n8n-docker-caddy-caddy-1`; Caddyfile `/root/n8n-docker-caddy/caddy_config/Caddyfile`;
  compose `/root/n8n-docker-caddy/docker-compose.yml`; reload:
  `docker exec n8n-docker-caddy-caddy-1 caddy reload --config /etc/caddy/Caddyfile`
- **Build:** `deploy/build.sh` auto-uses the pinned `squidfunk/mkdocs-material:9.6.22`
  Docker image on the box (no Python installed there).
- **⚠️ Shared box** (n8n, Supabase, NovaVMS, castwise, …). Touch ONLY `/srv/ai-system-design-guide`,
  our Caddy vhost block, and our systemd unit. **NEVER** `docker system prune` or broad cleanup.

## One-time bootstrap
DNS (Cloudflare A record `ai-system-design-guide` → `151.242.74.12`, **DNS-only/grey**) is a
user step — confirm it resolves first: `dig +short ai-system-design-guide.novalien.com @1.1.1.1`.

1. **Clone the fork + add upstream:**
   ```bash
   /c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'git clone https://github.com/Novalien0424/ai-system-design-guide.git /root/ai-system-design-guide-src && cd /root/ai-system-design-guide-src && git remote add upstream https://github.com/ombharatiya/ai-system-design-guide.git && git fetch upstream && mkdir -p /srv/ai-system-design-guide'
   ```
2. **First build + publish** (build via Docker, then rsync into the web root):
   ```bash
   /c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'cd /root/ai-system-design-guide-src && bash deploy/sync-and-deploy.sh'
   ```
3. **Mount the web root into Caddy** — add one line to the `caddy` service `volumes` in
   `/root/n8n-docker-caddy/docker-compose.yml` (back it up first):
   `- /srv/ai-system-design-guide:/srv/ai-system-design-guide:ro`, then
   `cd /root/n8n-docker-caddy && docker compose up -d caddy`.
4. **Add the vhost** — append `deploy/caddy/ai-system-design-guide.caddy` to the Caddyfile
   (back it up first), validate, reload:
   ```bash
   /c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'docker exec n8n-docker-caddy-caddy-1 caddy validate --config /etc/caddy/Caddyfile && docker exec n8n-docker-caddy-caddy-1 caddy reload --config /etc/caddy/Caddyfile'
   ```
5. **Install the weekly timer:**
   ```bash
   /c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'cp /root/ai-system-design-guide-src/deploy/systemd/ai-system-design-guide-sync.* /etc/systemd/system/ && systemctl daemon-reload && systemctl enable --now ai-system-design-guide-sync.timer && systemctl list-timers ai-system-design-guide-sync.timer --no-pager'
   ```

## Routine redeploy (manual, on demand)
```bash
/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'cd /root/ai-system-design-guide-src && bash deploy/sync-and-deploy.sh'
```
`sync-and-deploy.sh` is idempotent + fail-loud: on any merge/build/healthcheck failure it
logs and exits non-zero WITHOUT swapping, leaving the last-good site live.

## Verify
```bash
curl -sI https://ai-system-design-guide.novalien.com | head -5            # 200 + valid cert
/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'cat /srv/ai-system-design-guide/.version'
/c/Windows/System32/OpenSSH/ssh.exe root@100.70.175.62 'systemctl status ai-system-design-guide-sync.timer --no-pager; journalctl -u ai-system-design-guide-sync.service --no-pager -n 30'
```
In-browser: sidebar navigates, search returns hits, a Mermaid diagram renders.

## Troubleshooting
| Symptom | Cause | Fix |
|---|---|---|
| Cert/TLS error | DNS not resolving or proxied (orange) | Confirm Cloudflare A record is **DNS-only**; wait ~2 min |
| 404 on all pages | Caddy mount/vhost missing | Check `:ro` volume + vhost `root`; `caddy validate` then reload |
| Site didn't update | build/healthcheck failed (last-good kept) | `journalctl -u ai-system-design-guide-sync.service`; fix; re-run script |
| Merge conflict on sync | upstream added a file at an overlay path | Resolve manually; rename our overlay file; never auto-resolve |
| SSH refuses keys | Windows ssh-agent stopped | `Get-Service ssh-agent \| Start-Service` (elevated), retry |
| Mermaid not rendering | CDN blocked at view-time | Confirm internet to unpkg; if persistent, self-host mermaid via `extra_javascript` |
