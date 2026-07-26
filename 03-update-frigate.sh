#!/usr/bin/env bash
#
# 03-update-frigate.sh
# IM CONTAINER ausfuehren.
#
# Holt das neueste Frigate-Image und startet den Container neu.
# Config und Aufnahmen bleiben unberuehrt (liegen als Volumes ausserhalb).
#
set -euo pipefail

FRIGATE_DIR="/opt/frigate"

cd "$FRIGATE_DIR"

echo "Ziehe neues Frigate-Image..."
docker compose pull

echo "Starte Container mit neuem Image neu..."
docker compose up -d

echo "Entferne alte, ungenutzte Images..."
docker image prune -f

echo ""
echo "Fertig. Aktuelle Version pruefen mit:"
echo "  docker inspect frigate --format='{{.Config.Image}}'"
echo ""
echo "Tipp: Vor grösseren Updates einen Proxmox-Snapshot des LXC anlegen:"
echo "  pct snapshot <CTID> vor-update-\$(date +%Y%m%d)"
