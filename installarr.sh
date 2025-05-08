#!/bin/bash
# =============================================================================================
# installarr.sh - Versione 1.2
# Script per installare e aggiornare Radarr, Sonarr, Lidarr, Prowlarr, qBittorrent, Notifiarr e Plex Media Server.
# Utilizza lo script ufficiale Servarr per la gestione interattiva delle applicazioni ARR.
# =============================================================================================

set -euo pipefail

# Verifica privilegi di root
if [ "$(id -u)" -ne 0 ]; then
    echo "[INFO] Lo script richiede privilegi root. Riavvio con sudo..."
    exec sudo -E bash "$0" "$@"
fi

# Configura log
USER_HOME="${SUDO_USER:+/home/$SUDO_USER}"
USER_HOME="${USER_HOME:-$HOME}"
LOGFILE="$USER_HOME/Desktop/installarr.log"
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# Aggiorna apt e installa utilità di base
apt-get update -y
apt-get install -y curl wget ca-certificates jq

# Scarica ed esegue lo script ufficiale Servarr per installare Radarr, Sonarr, Lidarr, Prowlarr in modo interattivo
echo -e "\n=== Installazione Servarr Apps (Radarr, Sonarr, Lidarr, Prowlarr) ==="
echo "Scaricamento dello script ufficiale Servarr..."
curl -o servarr-install-script.sh https://raw.githubusercontent.com/Servarr/Wiki/master/servarr/servarr-install-script.sh
chmod +x servarr-install-script.sh
echo "Avvio dello script Servarr: segui le istruzioni interattive per installare le app desiderate."
sudo bash servarr-install-script.sh

# qBittorrent
echo -e "\n*** qBittorrent ***"
if dpkg -s qbittorrent-nox >/dev/null 2>&1; then
    QBIT_PACKAGE="qbittorrent-nox"
elif dpkg -s qbittorrent >/dev/null 2>&1; then
    QBIT_PACKAGE="qbittorrent"
else
    QBIT_PACKAGE=""
fi

if [ -n "$QBIT_PACKAGE" ]; then
    echo "qBittorrent ($QBIT_PACKAGE) già presente."
    read -p "Aggiornare? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        apt-get install -y "$QBIT_PACKAGE"
        echo "[OK] qBittorrent aggiornato."
    fi
else
    echo "qBittorrent non trovato."
    read -p "Installare? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "Scegli versione [GUI/nox]: " choice
            case "${choice,,}" in
                gui ) QBIT_PACKAGE="qbittorrent"; break;;
                nox ) QBIT_PACKAGE="qbittorrent-nox"; break;;
                * ) echo "Scelta non valida.";; esac
        done
        apt-get install -y "$QBIT_PACKAGE"
        echo "[OK] qBittorrent ($QBIT_PACKAGE) installato."
    fi
fi

# Notifiarr
echo -e "\n*** Notifiarr ***"
if dpkg -s notifiarr >/dev/null 2>&1; then
    echo "Notifiarr è già installato."
    read -p "Vuoi aggiornare Notifiarr? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        apt-get install -y notifiarr
        echo "[OK] Notifiarr aggiornato."
    fi
else
    echo "Notifiarr non trovato."
    read -p "Vuoi installare Notifiarr? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        bash <(curl -s https://golift.io/repo.sh) -s - notifiarr
        echo "[OK] Notifiarr installato."
    fi
fi

# Plex Media Server
echo -e "\n*** Plex Media Server ***"
if dpkg -s plexmediaserver >/dev/null 2>&1; then
    echo "Plex è già installato."
    read -p "Vuoi aggiornare Plex Media Server? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        URL=$(curl -fsSL https://plex.tv/api/downloads/5.json | grep -Eo 'https:[^"'\'' ]+plexmediaserver_[^"'\'' ]*amd64.deb' | head -n1)
        wget -q "$URL" -O /tmp/plex.deb
        apt-get install -y /tmp/plex.deb
        rm /tmp/plex.deb
        echo "[OK] Plex aggiornato."
    fi
else
    echo "Plex non trovato."
    read -p "Vuoi installare Plex Media Server? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
    echo "[INFO] Scarico l'ultima versione stabile di Plex Media Server..."
    URL=$(curl -fsSL https://plex.tv/api/downloads/5.json | jq -r '
        .computer.Linux.releases[] 
        | select(.build == "linux-x86_64" and .distro == "debian" and (.isBeta == false)) 
        | .url' | head -n1
    )

    if [[ -z "$URL" ]]; then
        echo "[ERRORE] Nessun link valido trovato per Plex Media Server stabile su Debian!"
        exit 1
    fi

    wget -q "$URL" -O /tmp/plex.deb
    apt-get install -y /tmp/plex.deb
    rm /tmp/plex.deb
    echo "[OK] Plex Media Server installato correttamente."
fi
fi

echo -e "\n=== Script completato con successo ==="
