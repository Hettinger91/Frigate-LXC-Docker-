# Frigate im Proxmox LXC (ohne Community-Skript)

Eigenes, transparentes Setup: privilegierter Debian-12-LXC, Docker,
USB-Coral-TPU, externe Festplatte als Speicher, Updates rein über Docker.

## Voraussetzungen

- Proxmox VE Host mit freier Container-ID
- Externe Festplatte bereits am Host per **UUID** in `/etc/fstab` gemountet
  (nicht per `/dev/sdX`, die Bezeichnung kann sich ändern), z. B. unter
  `/mnt/frigate-storage`
- Coral USB TPU (wird erst beim Setup gesteckt oder ist schon dran)
- Debian-12-Template in Proxmox verfügbar (Script lädt es bei Bedarf nach)

## Ablauf

### 1. Auf dem Proxmox-Host

Variablen in `01-create-lxc.sh` anpassen (CTID, Bridge, Pfade), dann:

```bash
chmod +x 01-create-lxc.sh
./01-create-lxc.sh
```

Das Script:
- erstellt einen **privilegierten** LXC (nötig für USB-Device-Zugriff)
- aktiviert **Nesting** (damit Docker im Container läuft)
- reicht `/dev/bus/usb` durch (für die Coral)
- bindet die externe Platte per Mountpoint ein (`mp0`)
- reicht `/dev/dri` durch, falls eine Intel-GPU für Quicksync gefunden wird

### 2. Im Container

```bash
pct enter <CTID>
```

Dann `02-setup-docker-frigate.sh` in den Container kopieren (z. B. per
`pct push <CTID> 02-setup-docker-frigate.sh /root/`) und ausführen:

```bash
chmod +x 02-setup-docker-frigate.sh
./02-setup-docker-frigate.sh
```

Installiert Docker, legt `/opt/frigate/docker-compose.yml` und eine
Platzhalter-`config.yml` an.

### 3. Config anpassen

Vor dem ersten Start unbedingt `/opt/frigate/config/config.yml` mit echten
Kameras und ggf. MQTT-Zugang (deine HAOS-Instanz) füllen.

### 4. Starten

```bash
cd /opt/frigate
docker compose up -d
docker logs -f frigate
```

Prüfen, ob die Coral erkannt wurde:

```bash
docker logs frigate | grep -i edgetpu
```

### 5. Updates

```bash
./03-update-frigate.sh
```

oder manuell:

```bash
cd /opt/frigate
docker compose pull
docker compose up -d
```

Config und Aufnahmen bleiben erhalten, da sie als Volumes außerhalb des
Containers liegen.

## Sicherheit

- Container ist privilegiert (nötig für USB) – daher:
  - kein Passwort-SSH-Login in den Container, wenn vermeidbar
  - Proxmox-Firewall auf dem Container aktivieren, nur Ports 5000, 8554,
    8555 freigeben
  - Frigate-Weboberfläche nicht direkt ins Internet exponieren, nur über
    lokales Netz / HAOS erreichbar lassen
- Regelmäßige Snapshots/Backups des LXC (`pct snapshot` bzw. `vzdump`)

## Troubleshooting: Coral wird nicht gefunden

Die Coral USB TPU meldet sich **vor** dem Laden der Firmware mit einer
anderen USB-ID (`1a6e:089a`, Global Unichip) als **danach**
(`18d1:9302`, Google). Falls `docker logs frigate` keine TPU findet:

```bash
lsusb   # vor und nach einem Container-Neustart vergleichen
```

Wechselt die ID nicht sauber durch, hilft es oft, das Gerät kurz ab- und
wieder anzustecken, nachdem der Container bereits läuft, oder den ganzen
USB-Controller/Hub (statt nur des einzelnen Geräts) durchzureichen.
