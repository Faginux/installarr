#!/bin/bash
# Script per creare una Live USB Debian KDE con persistenza
# Include: partizionamento, formattazione, copia ISO, configurazione persistenza, modifica bootloader

set -eu  # -e: esci a primo errore, -u: errore su variabili non definite

trap 'echo "Smontaggio di sicurezza..."; sudo umount /mnt/iso 2>/dev/null; sudo umount /mnt 2>/dev/null; sudo umount /mnt/persist 2>/dev/null' EXIT

echo "=== Creazione Live USB Debian persistente ==="

echo "Dispositivi disponibili:"
lsblk -dpno NAME,SIZE | grep -E '/dev/sd|/dev/nvme'

read -p "Inserisci il device USB (es: /dev/sdb o /dev/nvme0n1): " USB_DEV
if [ ! -b "$USB_DEV" ]; then
  echo "Errore: dispositivo non valido!" >&2
  exit 1
fi

echo "Usando dispositivo: $USB_DEV"

if [[ "$USB_DEV" == *"nvme"* ]]; then
    USB_PART1="${USB_DEV}p1"
    USB_PART2="${USB_DEV}p2"
else
    USB_PART1="${USB_DEV}1"
    USB_PART2="${USB_DEV}2"
fi

DEVICE_SIZE=$(lsblk -bnd -o SIZE "$USB_DEV")
REQUIRED_SIZE=$((70 * 1024 * 1024 * 1024))
if [ "$DEVICE_SIZE" -lt "$REQUIRED_SIZE" ]; then
    echo "Errore: il dispositivo deve avere almeno 70GB." >&2
    exit 1
fi

echo "==> Partizionamento di $USB_DEV"
sudo parted -s "$USB_DEV" mklabel gpt
sudo parted -s "$USB_DEV" mkpart primary fat32 1MiB 64GiB
sudo parted -s "$USB_DEV" mkpart primary ext4 64GiB 100%

echo "Partizioni create: $USB_PART1 (FAT32 Live), $USB_PART2 (EXT4 Persistence)"

echo "==> Formattazione partizioni"
sudo mkfs.vfat -F32 "$USB_PART1"
sudo mkfs.ext4 -L persistence "$USB_PART2"

echo "==> Download ISO Debian Live KDE completo amd64"
ISO_URL=$(wget -qO- https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/   | grep -oP 'href="\Kdebian-live-.*?amd64-kde\.iso(?=")' | head -n1)

if [ -z "$ISO_URL" ]; then
  echo "Errore: impossibile ottenere URL ISO KDE" >&2
  exit 1
fi

ISO_URL="https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/$ISO_URL"
ISO_FILE="$(basename "$ISO_URL")"

if [ ! -f "$ISO_FILE" ]; then
  wget "$ISO_URL"
fi
echo "ISO scaricata: $ISO_FILE"

echo "==> Copio contenuti ISO su partizione FAT32"
sudo mount "$USB_PART1" /mnt
sudo mount -o loop "$ISO_FILE" /mnt/iso
sudo rsync -a --exclude=live/filesystem.squashfs /mnt/iso/ /mnt/
sudo mkdir -p /mnt/live
sudo rsync -a /mnt/iso/live/filesystem.squashfs /mnt/live/
sudo umount /mnt/iso
sudo umount /mnt

echo "==> Configuro persistenza e directory utente"
sudo mkdir -p /mnt/persist
sudo mount "$USB_PART2" /mnt/persist

echo "/ union" | sudo tee /mnt/persist/persistence.conf > /dev/null

PERSIST_USER="user"
sudo mkdir -p /mnt/persist/home/$PERSIST_USER/Desktop/scripts

sudo bash -c "cat >> /mnt/persist/home/$PERSIST_USER/.bashrc <<EOF
# Aggiunta cartella scripts al PATH
export PATH=\"\$PATH:\$HOME/Desktop/scripts\"
EOF"

sudo chown -R 1000:1000 /mnt/persist/home/$PERSIST_USER

sudo umount /mnt/persist

echo "==> Modifica configurazione bootloader per abilitare 'persistence'"
sudo mount "$USB_PART1" /mnt

if [ -f /mnt/syslinux.cfg ]; then
  sudo sed -i 's/APPEND \(.*\)/APPEND \1 persistence/' /mnt/syslinux.cfg
  echo "Parametro 'persistence' aggiunto in syslinux.cfg"
fi

if [ -f /mnt/boot/grub/grub.cfg ]; then
  sudo sed -i '/linux /s/$/ persistence/' /mnt/boot/grub/grub.cfg
  echo "Parametro 'persistence' aggiunto in grub.cfg"
fi

sudo umount /mnt

echo "=== Live USB Debian KDE con persistenza creata ==="
echo "Puoi avviare selezionando 'Live (persistence)' al boot."
