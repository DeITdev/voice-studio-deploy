#!/bin/sh
set -e

# Join any GPU device groups if present
for dev in /dev/kfd /dev/dri/render*; do
    [ -e "$dev" ] || continue
    gid=$(stat -c %g "$dev")
    grp=$(getent group "$gid" | cut -d: -f1)
    [ -n "$grp" ] || {
        grp="gpu$gid"
        groupadd -g "$gid" "$grp"
    }
    usermod -aG "$grp" voicebox
done

data=/app/data
gen=$data/generations
hf_cache=/home/voicebox/.cache/huggingface

mkdir -p "$data" "$gen" "$hf_cache" 2>/dev/null || true

# Adopt the host UID/GID of bind-mounted /app/data or /home/voicebox/.cache/huggingface
# so downloaded models and generated audio files on the DGX Spark host have clean ownership.
host_uid=$(stat -c %u "$data")
host_gid=$(stat -c %g "$data")
if [ "$host_uid" = 0 ] || [ "$host_uid" = "$(id -u voicebox)" ]; then
    host_uid=$(stat -c %u "$hf_cache")
    host_gid=$(stat -c %g "$hf_cache")
fi
if [ "$host_uid" != 0 ] && [ "$host_uid" != "$(id -u voicebox)" ]; then
    old_uid=$(id -u voicebox)
    getent group "$host_gid" >/dev/null || groupadd -g "$host_gid" hostdata
    usermod -u "$host_uid" -g "$host_gid" voicebox
    find /home/voicebox "$data" -uid "$old_uid" -exec chown "$host_uid:$host_gid" {} + 2>/dev/null || true
fi

# Ensure HuggingFace cache and data directories are owned and writable by voicebox
chown voicebox:voicebox /home/voicebox/.cache "$hf_cache" 2>/dev/null || true

for dir in "$data" "$data/cache" "$data/profiles" "$data/captures" "$gen" "$hf_cache"; do
    mkdir -p "$dir" 2>/dev/null || true
    [ "$(stat -c %u "$dir")" = 0 ] && chown voicebox:voicebox "$dir" 2>/dev/null || true
    gosu voicebox test -w "$dir" || {
        echo "error: $dir is not writable by the voicebox user (uid $(id -u voicebox))" >&2
        echo "hint: make the host dir mounted there writable by that uid" >&2
        exit 1
    }
done

exec gosu voicebox "$@"
