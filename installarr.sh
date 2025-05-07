#!/bin/bash
# =============================================================================================
# install_arr_stack.sh - Versione 1.8.2
# Script completo per installare e aggiornare Radarr, Sonarr, Lidarr, Prowlarr, qBittorrent, Notifiarr, Plex Media Server
# Commenti dettagliati e spiegazioni per ogni comando e funzione
# =============================================================================================

set -euo pipefail  # Garantisce che lo script termini in caso di errore o variabili non definite

# === Verifica privilegi root ===
# Se non è root, riavvia lo script con sudo per garantire i permessi necessari
if [ "$(id -u)" -ne 0 ]; then
    echo "[INFO] Lo script richiede privilegi root. Esecuzione con sudo..."
    exec sudo -E bash "$0" "$@"
fi

# === Configura log sul Desktop ===
# Identifica la home dell'utente che ha avviato lo script e crea un file di log dettagliato
if [ -n "${SUDO_USER:-}" ]; then
    USER_HOME="/home/$SUDO_USER"
else
    USER_HOME="$HOME"
fi
LOGFILE="$USER_HOME/Desktop/install_arr_stack.log"
mkdir -p "$(dirname "$LOGFILE")"
touch "$LOGFILE"
echo "[INFO] Scrivendo log dettagliato in: $LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# === Funzione generica per gestire i servizi ===
# Parametri:
#   $1 - Nome servizio
#   $2 - Comando per verificare se è installato
#   $3 - Comando di installazione
#   $4 - Comando di aggiornamento
manage_service() {
    local name="$1" check_cmd="$2" install_cmd="$3" update_cmd="$4"
    echo -e "\n*** Gestione $name ***"

    if eval "$check_cmd"; then
        echo "$name risulta già installato."
        read -p "Vuoi aggiornare $name? (y/N): " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            echo "[INFO] Avvio aggiornamento di $name..."
            eval "$update_cmd"
            echo "[OK] $name aggiornato correttamente."
        else
            echo "$name non aggiornato."
        fi
    else
        echo "$name non è installato."
        read -p "Vuoi installare $name? (y/N): " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            echo "[INFO] Avvio installazione di $name..."
            eval "$install_cmd"
            echo "[OK] $name installato correttamente."
        else
            echo "$name non installato."
        fi
    fi
}

# === Aggiornamento pacchetti base ===
# Installa strumenti essenziali per l'esecuzione dei comandi
apt-get update -y
apt-get install -y curl wget ca-certificates

# === Radarr ===
manage_service "Radarr" \
    "systemctl list-unit-files | grep -Fq 'radarr.service'" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Radarr/Radarr/develop/distribution/debian/install.sh)" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Radarr/Radarr/develop/distribution/debian/install.sh)"

# === Sonarr ===
manage_service "Sonarr" \
    "systemctl list-unit-files | grep -Fq 'sonarr.service'" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Sonarr/Sonarr/develop/distribution/debian/install.sh)" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Sonarr/Sonarr/develop/distribution/debian/install.sh)"

# === Lidarr ===
manage_service "Lidarr" \
    "systemctl list-unit-files | grep -Fq 'lidarr.service'" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Lidarr/Lidarr/develop/distribution/debian/install.sh)" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Lidarr/Lidarr/develop/distribution/debian/install.sh)"

# === Prowlarr ===
manage_service "Prowlarr" \
    "systemctl list-unit-files | grep -Fq 'prowlarr.service'" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/distribution/debian/install.sh)" \
    "bash <(wget -qO- https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/distribution/debian/install.sh)"

# === qBittorrent (gestione speciale: GUI o nox) ===
echo -e "\n*** Gestione qBittorrent ***"
# Verifica se è installato qbittorrent o qbittorrent-nox
if dpkg -s qbittorrent-nox >/dev/null 2>&1; then
    QBIT_PACKAGE="qbittorrent-nox"
elif dpkg -s qbittorrent >/dev/null 2>&1; then
    QBIT_PACKAGE="qbittorrent"
else
    QBIT_PACKAGE=""
fi

if [ -n "$QBIT_PACKAGE" ]; then
    echo "qBittorrent ($QBIT_PACKAGE) risulta già installato."
    read -p "Vuoi aggiornare qBittorrent? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        apt-get install -y "$QBIT_PACKAGE"
        echo "[OK] qBittorrent aggiornato."
    else
        echo "qBittorrent non aggiornato."
    fi
else
    echo "qBittorrent non è installato."
    read -p "Vuoi installarlo? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "Scegli quale versione installare [GUI/nox]: " choice
            case "${choice,,}" in
                gui ) QBIT_PACKAGE="qbittorrent"; break;;
                nox ) QBIT_PACKAGE="qbittorrent-nox"; break;;
                * ) echo "[!] Scelta non valida. Inserisci 'GUI' o 'nox'.";;
            esac
        done
        apt-get install -y "$QBIT_PACKAGE"
        echo "[OK] qBittorrent ($QBIT_PACKAGE) installato."
    else
        echo "qBittorrent non installato."
    fi
fi

# === Notifiarr ===
manage_service "Notifiarr" \
    "dpkg -s notifiarr >/dev/null 2>&1" \
    "bash <(curl -s https://golift.io/repo.sh) -s - notifiarr" \
    "apt-get install -y notifiarr"

# === Plex Media Server ===
echo -e "\n*** Gestione Plex Media Server ***"
if dpkg -s plexmediaserver >/dev/null 2>&1; then
    echo "Plex Media Server è già installato."
    read -p "Vuoi aggiornarlo? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        URL=$(curl -fsSL https://plex.tv/api/downloads/5.json | grep -Eo 'https:[^"'\''"]+plexmediaserver_[^"'\''"]*amd64.deb' | head -n1)
        [ -z "$URL" ] && { echo "[ERRORE] Impossibile ottenere l'URL di Plex."; exit 1; }
        wget -q "$URL" -O /tmp/plex.deb
        apt-get install -y /tmp/plex.deb
        rm /tmp/plex.deb
        echo "[OK] Plex aggiornato."
    else
        echo "Plex non aggiornato."
    fi
else
    echo "Plex Media Server non è installato."
    read -p "Vuoi installarlo? (y/N): " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        URL=$(curl -fsSL https://plex.tv/api/downloads/5.json | grep -Eo 'https:[^"'\''"]+plexmediaserver_[^"'\''"]*amd64.deb' | head -n1)
        [ -z "$URL" ] && { echo "[ERRORE] Impossibile ottenere l'URL di Plex."; exit 1; }
        wget -q "$URL" -O /tmp/plex.deb
        apt-get install -y /tmp/plex.deb
        rm /tmp/plex.deb
        echo "[OK] Plex installato."
    else
        echo "Plex non installato."
    fi
fi

echo -e "\n=== Tutte le operazioni sono state completate con successo! ==="
