#!/usr/bin/env bash
#
# 02-setup-docker-frigate.sh
# IM CONTAINER ausfuehren (nach "pct enter <CTID>")
#
# Installiert Docker, legt Verzeichnisstruktur und docker-compose.yml
# fuer Frigate mit USB-Coral-TPU an.
#
set -euo pipefail

FRIGATE_DIR="/opt/frigate"
STORAGE_PATH="/media/frigate"   # muss dem mp0-Mount aus Script 1 entsprechen

if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root im Container ausfuehren." >&2
  exit 1
fi

if [[ ! -d "$STORAGE_PATH" ]]; then
  echo "WARNUNG: $STORAGE_PATH nicht gefunden. Ist der Bind-Mount (mp0) korrekt?" >&2
fi

echo "Aktualisiere Paketliste..."
apt-get update -y

echo "Installiere Docker..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com | sh
else
  echo "Docker bereits installiert, uebersprungen."
fi

echo "Installiere docker-compose-plugin (falls nicht vorhanden)..."
apt-get install -y docker-compose-plugin

echo "Lege Verzeichnisstruktur unter ${FRIGATE_DIR} an..."
mkdir -p "${FRIGATE_DIR}/config"

# ---------- docker-compose.yml ----------
cat > "${FRIGATE_DIR}/docker-compose.yml" <<'EOF'
services:
  frigate:
    container_name: frigate
    image: ghcr.io/blakeblackshear/frigate:stable
    restart: unless-stopped
    shm_size: "256mb"
    privileged: false
    devices:
      - /dev/bus/usb:/dev/bus/usb          # Coral USB TPU
      # - /dev/dri/renderD128:/dev/dri/renderD128  # einkommentieren, wenn Quicksync vorhanden
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./config:/config
      - /media/frigate:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    ports:
      - "5000:5000"
      - "8554:8554"
      - "8555:8555/tcp"
      - "8555:8555/udp"
EOF

# ---------- Minimal-config.yml (Platzhalter, muss angepasst werden) ----------
if [[ ! -f "${FRIGATE_DIR}/config/config.yml" ]]; then
cat > "${FRIGATE_DIR}/config/config.yml" <<'EOF'
mqtt:
  enabled: false
  # host: <IP deiner HAOS-Instanz>

detectors:
  coral:
    type: edgetpu
    device: usb

# Beispiel-Kamera - bitte durch echte RTSP-Streams ersetzen!
cameras:
  beispiel_kamera:
    ffmpeg:
      inputs:
        - path: rtsp://user:pass@192.168.1.50:554/stream1
          roles:
            - detect
    detect:
      width: 1280
      height: 720
      fps: 5
EOF
  echo "Platzhalter-config.yml angelegt: ${FRIGATE_DIR}/config/config.yml"
  echo "WICHTIG: Bitte Kameras und ggf. MQTT vor dem Start anpassen."
fi

echo ""
echo "=========================================================="
echo "Setup abgeschlossen."
echo ""
echo "Frigate starten mit:"
echo "  cd ${FRIGATE_DIR} && docker compose up -d"
echo ""
echo "Logs prüfen mit:"
echo "  docker logs -f frigate"
echo ""
echo "Coral-Erkennung prüfen mit:"
echo "  docker logs frigate | grep -i edgetpu"
echo "=========================================================="
