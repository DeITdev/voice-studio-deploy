#!/bin/sh
set -e

# Strip any trailing slash from DGX_BACKEND_URL so nginx proxy_pass "${DGX_BACKEND_URL}/"
# never produces a double slash.
DGX_BACKEND_URL=$(printf '%s' "${DGX_BACKEND_URL:-http://127.0.0.1:17493}" | sed 's:/*$::')
export DGX_BACKEND_URL

# Render Nginx configuration with sanitized DGX_BACKEND_URL
envsubst '${DGX_BACKEND_URL}' < /etc/nginx/voicebox.conf.template > /etc/nginx/conf.d/default.conf

SERVER_URL="${FRONTEND_SERVER_URL:-/api}"

cat > /usr/share/nginx/html/config.js <<EOF
window.__VOICEBOX_CONFIG__ = {
  serverUrl: "${SERVER_URL}"
};
EOF

echo "[voicebox-web] Frontend configured with serverUrl=${SERVER_URL} -> proxying /api/ to ${DGX_BACKEND_URL}"
