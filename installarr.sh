#!/bin/bash
# =============================================================================================
# installarr.sh - Versione 1.4
# Script completo per installare Radarr, Sonarr, Lidarr, Prowlarr, qBittorrent, Notifiarr,
# Plex Media Server + Portainer + generazione di template (Watchtower, Overseerr, Immich, Flaresolverr).
# =============================================================================================
#
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
else
    echo "Plex non trovato."
    read -p "Vuoi installare Plex Media Server? (y/N): " ans
fi

if [[ "$ans" =~ ^[Yy]$ ]]; then
    echo "[INFO] Scarico l'ultima versione stabile di Plex Media Server..."

    # Usa l'API di Plex per trovare l'ultima versione stabile per Debian (non beta)
    URL=$(curl -fsSL https://plex.tv/api/downloads/5.json | jq -r '
        .computer.Linux.releases[]
        | select(.build == "linux-x86_64" and .distro == "debian" and (.isBeta == false))
        | .url' | head -n1
    )

    # Se non trova nessun link valido, usa un link di fallback
    if [[ -z "$URL" ]]; then
        echo "[AVVISO] Nessun link valido trovato dall'API di Plex. Procedo con il link di fallback specifico..."
        URL="https://downloads.plex.tv/plex-media-server-new/1.41.6.9685-d301f511a/debian/plexmediaserver_1.41.6.9685-d301f511a_amd64.deb"
        echo "[INFO] Userò il link di fallback: $URL"
    else
        echo "[INFO] Trovato link per Plex Media Server stabile: $URL"
    fi

    echo "[INFO] Scarico Plex Media Server..."
    wget -q "$URL" -O /tmp/plex.deb

    if [[ $? -ne 0 ]]; then
        echo "[ERRORE] Download fallito! Controlla la connessione o il link e riprova."
        exit 1
    fi

    echo "[INFO] Installo Plex Media Server..."
    apt-get install -y /tmp/plex.deb

    if [[ $? -eq 0 ]]; then
        echo "[OK] Plex Media Server installato correttamente."
    else
        echo "[ERRORE] Installazione fallita! Controlla eventuali errori sopra."
    fi

    # Pulizia file temporanei
    rm /tmp/plex.deb
fi

# =============================================================================================
# 2️⃣ Sezione opzionale: Installazione di Portainer con gestione Docker
# =============================================================================================

echo -e "\n*** Portainer (gestione container Docker) ***"
read -p "Vuoi installare Portainer per gestire facilmente i container? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then

    # Verifica se Docker è installato
    if ! command -v docker >/dev/null 2>&1; then
        echo "[ERRORE] Docker non risulta installato."
        read -p "Vuoi installare Docker adesso? (y/N): " install_docker
        if [[ "$install_docker" =~ ^[Yy]$ ]]; then
            echo "[INFO] Procedo con l'installazione di Docker..."

            apt-get update
            apt-get install -y ca-certificates curl gnupg lsb-release

            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

            echo "[OK] Docker installato."
        else
            echo "[INFO] Installazione Docker annullata. Non posso procedere con Portainer."
            exit 0
        fi
    fi

    echo "[INFO] Docker è presente. Procedo con Portainer..."
    docker volume create portainer_data
    docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data portainer/portainer-ce:lts

    if [[ $? -eq 0 ]]; then
        echo "[OK] Portainer avviato. Visita https://localhost:9443 per accedere."
    else
        echo "[ERRORE] Problema durante l'avvio di Portainer."
    fi
else
    echo "Installazione di Portainer saltata."
fi

# =============================================================================================
# 3️⃣ Sezione opzionale: Creazione dei Template Docker Compose
# =============================================================================================

echo -e "\n*** Creazione di Template Docker Compose ***"
read -p "Vuoi creare template per container Docker (Watchtower, Immich, Overseerr, Flaresolverr)? (y/N): " create_templates
if [[ "$create_templates" =~ ^[Yy]$ ]]; then

    echo "Quale template vuoi creare?"
    echo "1) Watchtower"
    echo "2) Overseerr"
    echo "3) Immich"
    echo "4) Flaresolverr"
    echo "5) Tutti"
    read -p "Seleziona un'opzione (1-5): " template_choice

    # === Funzione: Watchtower ===
    create_watchtower_template() {
        echo -e "\n[INFO] Creazione del template per Watchtower..."

        echo "
Watchtower è un container leggero che controlla automaticamente l'aggiornamento degli altri container Docker.
Funzioni principali:
- Monitora le nuove versioni delle immagini dei container in esecuzione.
- Riavvia automaticamente i container aggiornati.
Utile per mantenere aggiornato l'ambiente Docker senza interventi manuali."

        echo
        read -p "Premi Invio per procedere alla creazione del file..."

        cat > watchtower.yaml <<EOF
version: "3"
services:
  watchtower:
    image: containrrr/watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

        echo "[OK] File 'watchtower.yaml' creato nella cartella corrente."
    }

    # === Funzione: Overseerr ===
    create_overseerr_template() {
        echo -e "\n[INFO] Creazione del template per Overseerr..."

        echo "
Overseerr è un'interfaccia web per gestire richieste di film e serie TV
per utenti Plex o Jellyfin. Si integra perfettamente con Radarr e Sonarr.
Funzioni principali:
- Richieste contenuti da interfaccia web.
- Notifiche e gestione automatica/manuale."

        echo
        read -p "Premi Invio per procedere alla creazione del file..."

        cat > overseerr.yaml <<EOF
version: '3'
services:
  overseerr:
    image: sctx/overseerr:latest
    container_name: overseerr
    environment:
      - LOG_LEVEL=info
      - TZ=Europe/Rome
    ports:
      - 5055:5055
    volumes:
      - /srv/docker/overseerr:/app/config
    restart: unless-stopped
EOF

        echo "[OK] File 'overseerr.yaml' creato nella cartella corrente."
    }

    # === Funzione: Immich ===
    create_immich_template() {
        echo -e "\n[INFO] Creazione del template per Immich..."

        echo "
Immich è una soluzione self-hosted simile a Google Photos.
Funzioni principali:
- Upload automatico da mobile
- Riconoscimento immagini e metadati
- Privacy garantita (auto-ospitato)

[INFO] Credenziali iniziali:
- Utente: admin@immich.app
- Password: admin"

        echo
        read -p "Premi Invio per procedere alla creazione del file..."

        cat > immich.yaml <<EOF
version: '3.8'

services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    depends_on:
      - immich-db
    environment:
      DB_HOST: immich-db
      DB_PORT: 5432
      DB_USERNAME: immich
      DB_PASSWORD: immichpassword
      DB_DATABASE_NAME: immich
      NODE_ENV: production
    ports:
      - "2283:3001"
    volumes:
      - /srv/docker/immich/library:/usr/src/app/upload
    restart: unless-stopped

  immich-db:
    image: postgres:14
    container_name: immich-db
    environment:
      POSTGRES_PASSWORD: immichpassword
      POSTGRES_USER: immich
      POSTGRES_DB: immich
    volumes:
      - /srv/docker/immich/postgres:/var/lib/postgresql/data
    restart: unless-stopped
EOF

        echo "[OK] File 'immich.yaml' creato nella cartella corrente."
    }

    # === Funzione: Flaresolverr ===
    create_flaresolverr_template() {
        echo -e "\n[INFO] Creazione del template per Flaresolverr..."

        echo "
Flaresolverr è un proxy che aiuta a bypassare Cloudflare e simili protezioni
per fonti di contenuti usate da Prowlarr e altri.
Funzioni principali:
- Gestisce CAPTCHA e challenge
- Espone API locale per integrazione."

        echo
        read -p "Premi Invio per procedere alla creazione del file..."

        cat > flaresolverr.yaml <<EOF
version: "2.1"
services:
  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    environment:
      - LOG_LEVEL=info
      - LOG_HTML=false
      - CAPTCHA_SOLVER=none
      - TZ=Europe/Rome
    ports:
      - "8191:8191"
    restart: unless-stopped
EOF

        echo "[OK] File 'flaresolverr.yaml' creato nella cartella corrente."
    }

    # === Gestione scelta utente ===
    case $template_choice in
        1)
            create_watchtower_template
            ;;
        2)
            create_overseerr_template
            ;;
        3)
            create_immich_template
            ;;
        4)
            create_flaresolverr_template
            ;;
        5)
            create_watchtower_template
            create_overseerr_template
            create_immich_template
            create_flaresolverr_template
            ;;
        *)
            echo "[INFO] Opzione non valida o non gestita."
            ;;
    esac
else
    echo "Creazione dei template saltata."
fi

echo -e "\n=== Script completato con successo ==="
