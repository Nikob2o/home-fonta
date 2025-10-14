#!/bin/bash

# --- CONFIGURATION ---
SRC="/home/nocob/home-fonta/"
DEST="/var/www/html/"
USER="www-data"
GROUP="www-data"

echo "Déploiement du site en cours..."

# Synchronisation (copie tout le code vers /var/www/html)
sudo rsync -av --delete \
  --exclude '.git' \
  --exclude 'deploy.sh' \
  $SRC $DEST

# Ajuste les permissions pour Nginx
sudo chown -R $USER:$GROUP $DEST

echo "Déploiement terminé avec succès."

