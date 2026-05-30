#!/usr/bin/env bash
# Weekly unattended sync + publish, run on HostHatch by a systemd timer.
#
# Pull our overlay (origin) + upstream content, rebuild, healthcheck, then swap the
# served directory. FAIL-LOUD, KEEP LAST-GOOD: on any merge/build/healthcheck
# failure it logs and exits non-zero WITHOUT touching the live site. The overlay is
# additive-only, so the upstream merge must be conflict-free — a conflict means an
# overlay/upstream path collision and is surfaced loudly, never auto-resolved.
# See CLAUDE.md / DEPLOYMENT.md.
set -euo pipefail

SRC="${ASDG_SRC:-/root/ai-system-design-guide-src}"   # git clone of the fork (+ upstream remote)
WEB="${ASDG_WEB:-/srv/ai-system-design-guide}"         # Caddy-served web root
LOCK="/tmp/asdg-sync.lock"

log() { echo "[asdg-sync $(date -Iseconds)] $*"; }

# Single instance (weekly timer + a manual run must not overlap).
exec 9>"$LOCK"
if ! flock -n 9 ; then log "another sync is running; abort"; exit 0; fi

cd "$SRC"

# A dedicated deploy clone: pin a git identity so an unattended merge commit can be
# created even on a fresh root checkout with no global user.name/user.email.
git config user.name  "asdg-sync"
git config user.email "deploy@ai-system-design-guide.novalien.com"

log "fetch origin (overlay) + upstream (content)"
git fetch --quiet origin
git fetch --quiet upstream

log "reset to latest overlay (origin/main)"
git checkout --quiet -B main origin/main

log "merge upstream content (must be conflict-free)"
if ! git merge --no-edit upstream/main ; then
  git merge --abort || true
  log "ERROR: upstream merge conflict (overlay/upstream path collision). Keeping last-good site."
  exit 1
fi

log "build"
bash deploy/build.sh

# ---- healthcheck the fresh build BEFORE swapping ----
if [ ! -s site/index.html ] || [ ! -s site/search/search_index.json ]; then
  log "ERROR: healthcheck failed (missing index.html or search index). Keeping last-good site."
  exit 1
fi
PAGES="$(find site -name '*.html' | wc -l | tr -d ' ')"
if [ "${PAGES:-0}" -lt 100 ]; then
  log "ERROR: only ${PAGES} pages built (<100), refusing to publish. Keeping last-good site."
  exit 1
fi

log "publish ${PAGES} pages -> ${WEB}"
mkdir -p "$WEB"
# Near-atomic publish that preserves last-good if interrupted:
#   --delay-updates : transfer updated files to temp names, batch-rename them all at the end
#   --delete-delay  : compute deletions during transfer, but APPLY them only after it succeeds
# So an interrupted/failed transfer leaves the previous site fully intact (no delete-during).
# A full directory swap is avoided on purpose: the served path is a Docker bind-mount, so
# `mv`-ing the directory would leave Caddy serving the old inode. `site/` is already a
# complete, health-checked build (it is effectively the staging dir).
rsync -a --delete-delay --delay-updates site/ "$WEB/"
echo "$(git rev-parse --short HEAD) @ $(date -Iseconds) (${PAGES} pages)" > "$WEB/.version"

# No Caddy reload needed: file_server serves the directory live; only Caddyfile
# changes require a reload (done once at bootstrap).
log "OK ($(cat "$WEB/.version"))"
