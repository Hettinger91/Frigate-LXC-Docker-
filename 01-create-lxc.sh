#!/usr/bin/env bash
#
# 01-create-lxc.sh
# Auf dem PROXMOX HOST ausführen (nicht im Container!)
#
# Erstellt einen privilegierten Debian-12-LXC mit Nesting, USB-Passthrough
# (für die Coral USB TPU) und einem Bind-Mount für eine externe Festplatte.
#
# Nutzung:
#   1. Variablen unten anpassen
#   2. chmod +x 01-create-lxc.sh
#   3. ./01-create-lxc.sh
#
set -euo pipefail

# ---------- Konfiguration ----------
CTID=200                          # Freie Container-ID auf deinem Host
HOSTNAME="frigate"
STORAGE="local-lvm"                # Proxmox-Storage fuer den Container selbst
DISK_SIZE="16"                     # GB fuer System-Disk des Containers
MEMORY="4096"                      # MB RAM
CORES="4"
BRIDGE="vmbr0"                     # Dein Netzwerk-Bridge-Name
TEMPLATE="local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"

# Muss auf dem Host bereits gemountet sein, z.B. per UUID in /etc/fstab!
EXTERNAL_DRIVE_HOST_PATH="/mnt/frigate-storage"
EXTERNAL_DRIVE_CT_PATH="/media/frigate"

# ---------- Vorbedingungen prüfen ----------
if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root auf dem Proxmox-Host ausfuehren." >&2
  exit 1
fi

if [[ ! -d "$EXTERNAL_DRIVE_HOST_PATH" ]]; then
  echo "FEHLER: $EXTERNAL_DRIVE_HOST_PATH existiert nicht." >&2
  echo "Bitte die externe Platte zuerst auf dem Host mounten (per UUID in /etc/fstab)." >&2
  exit 1
fi

if ! pveam list local 2>/dev/null | grep -q "debian-12-standard"; then
  echo "Debian-12-Template nicht gefunden, lade es herunter..."
  pveam update
  pveam download local debian-12-standard_12.7-1_amd64.tar.zst
fi

# ---------- Container erstellen ----------
echo "Erstelle LXC $CTID ($HOSTNAME)..."
pct create "$CTID" "$TEMPLATE" \
  --hostname "$HOSTNAME" \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap 512 \
  --rootfs "${STORAGE}:${DISK_SIZE}" \
  --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp" \
  --unprivileged 0 \
  --features nesting=1 \
  --onboot 1

CONF="/etc/pve/lxc/${CTID}.conf"

# ---------- USB-Passthrough fuer Coral (und generell USB-Geraete) ----------
echo "Aktiviere USB-Passthrough in ${CONF}..."
{
  echo ""
  echo "# USB-Passthrough (u.a. fuer Coral USB TPU)"
  echo "lxc.cgroup2.devices.allow: c 189:* rwm"
  echo "lxc.mount.entry: /dev/bus/usb dev/bus/usb none bind,optional,create=dir"
} >> "$CONF"

# ---------- Externe Festplatte als Bind-Mount ----------
echo "Binde externe Platte ein (mp0)..."
pct set "$CTID" -mp0 "${EXTERNAL_DRIVE_HOST_PATH},mp=${EXTERNAL_DRIVE_CT_PATH}"

# ---------- Optional: Intel Quicksync (GPU-Decoding) durchreichen ----------
if [[ -e /dev/dri/renderD128 ]]; then
  echo "Intel GPU gefunden, aktiviere Passthrough fuer Quicksync..."
  {
    echo ""
    echo "# Intel Quicksync GPU-Passthrough"
    echo "lxc.cgroup2.devices.allow: c 226:* rwm"
    echo "lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir"
  } >> "$CONF"
fi

# ---------- Container starten ----------
echo "Starte Container..."
pct start "$CTID"
sleep 5

echo ""
echo "=========================================================="
echo "LXC $CTID erstellt und gestartet."
echo "Weiter mit: pct enter $CTID"
echo "Dann Script 02-setup-docker-frigate.sh im Container ausfuehren."
echo "=========================================================="
