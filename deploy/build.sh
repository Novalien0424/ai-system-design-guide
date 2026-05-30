#!/usr/bin/env bash
# Build the static site from upstream markdown WITHOUT modifying upstream content.
#
# Additive overlay: assemble build/docs from the numbered chapter folders (00-*..99-*)
# plus the root content guides, then run MkDocs Material. Upstream files are COPIED,
# never moved or edited, so relative cross-links keep resolving and `git merge
# upstream/main` stays conflict-free. Runs on the box (Docker) or locally (mkdocs on
# PATH). See CLAUDE.md / DEPLOYMENT.md.
set -euo pipefail

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ROOT="$(pwd)"
DOCS="$ROOT/build/docs"

# Overlay/harness files that must NEVER become site pages.
DENY="CLAUDE.md PROGRESS_Claude.md DECISIONS_Claude.md DEPLOYMENT.md"

echo "==> assembling build/docs (no upstream file is modified)"
rm -rf "$ROOT/build"
mkdir -p "$DOCS"

# Numbered chapter folders: 00-* .. 99-*
for d in "$ROOT"/[0-9][0-9]-*/ ; do
  [ -d "$d" ] || continue
  cp -R "$d" "$DOCS/"
done

# Root markdown content guides, excluding overlay/harness files.
for f in "$ROOT"/*.md ; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  case " $DENY " in *" $base "*) continue ;; esac
  cp "$f" "$DOCS/"
done

# Make the upstream LICENSE reachable as a static file (MIT attribution) so the
# README's `](LICENSE)` link resolves on the site.
[ -f "$ROOT/LICENSE" ] && cp "$ROOT/LICENSE" "$DOCS/LICENSE"

# Home page: leave README.md in place — MkDocs renders it as the site index (/),
# and keeping the filename means the many `../README.md` cross-links keep resolving.

echo "==> building site/ with MkDocs Material"
# Not --strict on purpose: upstream link/anchor quirks must not break unattended
# publishing. The sync healthcheck (index + sample page) is the real gate.
if command -v mkdocs >/dev/null 2>&1 ; then
  mkdocs build --clean
else
  IMAGE="${MKDOCS_IMAGE:-squidfunk/mkdocs-material:9.6.22}"
  docker run --rm -v "$ROOT:/docs" -w /docs "$IMAGE" build --clean
fi

echo "==> done: $ROOT/site ($(find "$ROOT/site" -name '*.html' 2>/dev/null | wc -l | tr -d ' ') html pages)"
