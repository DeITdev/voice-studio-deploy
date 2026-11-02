#!/bin/sh
set -e

# Strip any trailing slash from DGX_BACKEND_URL so nginx proxy_pass "${DGX_BACKEND_URL}/"
# never produces a double slash.
DGX_BACKEND_URL=$(printf '%s' "${DGX_BACKEND_URL:-http://127.0.0.1:3900}" | sed 's:/*$::')
export DGX_BACKEND_URL

# Render Nginx configuration with sanitized DGX_BACKEND_URL
envsubst '${DGX_BACKEND_URL}' < /etc/nginx/voicestudio.conf.template > /etc/nginx/conf.d/default.conf

API_BASE=$(printf '%s' "${FRONTEND_API_BASE:-/api}" | sed 's:/*$::')

# Inject window.__OMNIVOICE_API_BASE__ into index.html along with its exact SHA-256 CSP hash
# (matching VoiceStudio's backend/core/spa_inject.py contract).
SCRIPT="window.__OMNIVOICE_API_BASE__=\"${API_BASE}\";"
DIGEST=$(printf '%s' "$SCRIPT" | openssl dgst -sha256 -binary | openssl base64 -A)

CONNECT_EXTRA=""
case "$API_BASE" in
  http://*|https://*)
    HTTP_ORIGIN=$(printf '%s' "$API_BASE" | sed -E 's#^(https?://[^/]+).*#\1#')
    WS_ORIGIN=$(printf '%s' "$HTTP_ORIGIN" | sed -E 's#^https:#wss:#; s#^http:#ws:#')
    CONNECT_EXTRA=" ${HTTP_ORIGIN} ${WS_ORIGIN}"
    ;;
esac

sed \
  -e "s|script-src 'self'|script-src 'self' 'sha256-${DIGEST}'|" \
  -e "s|connect-src 'self'|connect-src 'self'${CONNECT_EXTRA}|" \
  -e "s|<head>|<head><script>${SCRIPT}</script>|" \
  /usr/share/nginx/html/index.html.orig > /usr/share/nginx/html/index.html

echo "[voicestudio-web] Frontend configured with __OMNIVOICE_API_BASE__=${API_BASE} -> proxying /api/ to ${DGX_BACKEND_URL}"
