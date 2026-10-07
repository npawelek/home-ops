#!/bin/sh
# Fetch the free 3-day HDHomeRun XMLTV guide into Dispatcharr's EPG watch dir.
# Run by a Dispatcharr Connect "Custom Script" subscribed to m3u_refresh.
# Do not subscribe to epg_refresh: each write re-imports the file and loops.
set -eu

# Connect strips the container env, so re-export the proxy settings (Flux substitution)
export http_proxy="${HTTP_PROXY}"
export https_proxy="${HTTPS_PROXY}"
export no_proxy="${NO_PROXY}"

HDHR=http://hdhomerun.network.svc.cluster.local
OUT=/data/epgs/hdhomerun.xml

# DeviceAuth rotates every 16-24h, so read it fresh on every run
AUTH=$(curl -fsS -m 3 "$HDHR/discover.json" | sed -n 's/.*"DeviceAuth":"\([^"]*\)".*/\1/p')
[ -n "$AUTH" ] || { echo "no DeviceAuth from $HDHR" >&2; exit 1; }

# Write to a non-.xml temp name so the watcher never sees a partial file
curl -fsS -m 6 --compressed -o "$OUT.tmp" "https://api.hdhomerun.com/api/xmltv?DeviceAuth=$AUTH"
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT ($(grep -c '<programme' "$OUT") programmes)"
