#!/bin/bash
set -e  # Arrête le script si une commande échoue

# --- CONFIGURATION ---
SRC="/home/nocob/home-fonta/"
DEST="/var/www/html/home-fonta/"
BACKUP_DIR="/home/nocob/backups-www"
USER="www-data"
GROUP="www-data"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="html-backup-$TIMESTAMP.tar.gz"

echo "🚀 Déploiement du site en cours..."
echo "Dossier source : $SRC"
echo "Destination    : $DEST"
echo "Sauvegarde     : $BACKUP_DIR/$BACKUP_NAME"
echo ""

# --- ÉTAPE 1 : créer le dossier de sauvegarde ---
mkdir -p "$BACKUP_DIR"

# --- ÉTAPE 2 : sauvegarder l'ancien site ---
if [ -d "$DEST" ] && [ "$(ls -A $DEST)" ]; then
	    echo "📦 Sauvegarde du site actuel..."
	        sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME" -C "$DEST" .
		else
			    echo "ℹ️ Aucun contenu à sauvegarder (dossier vide)."
			    fi

# --- ÉTAPE 3 : synchroniser le nouveau code ---
echo "🔄 Copie du nouveau contenu..."
sudo rsync -av --delete \
  --exclude '.git' \
    --exclude 'deploy.sh' \
      "$SRC" "$DEST"

# --- ÉTAPE 4 : corriger les permissions ---
sudo chown -R "$USER":"$GROUP" "$DEST"

# --- ÉTAPE 5 : nettoyage optionnel des vieilles sauvegardes (garde 5 dernières) ---
cd "$BACKUP_DIR"
sudo ls -tp | grep 'html-backup-' | tail -n +6 | xargs -I {} sudo rm -- {}

echo ""
echo "✅ Déploiement terminé avec succès."
echo "📁 Sauvegarde stockée dans : $BACKUP_DIR/$BACKUP_NAME"

