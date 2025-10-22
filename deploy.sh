#!/bin/bash
set -e

# Configuration
SRC="/home/nocob/home-fonta/"
DEST="/var/www/html/home-fonta/"
BACKUP_DIR="/home/nocob/backups-www"
USER="www-data"
GROUP="www-data"
SERVICE_NAME="home-fonta"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="html-backup-$TIMESTAMP.tar.gz"

echo "🚀 Déploiement Home-Fonta.fr"
echo "============================"
echo ""

# Créer le dossier de sauvegarde
mkdir -p "$BACKUP_DIR"

# Sauvegarder l'ancien site
if [ -d "$DEST" ] && [ "$(ls -A $DEST)" ]; then
    echo "📦 Sauvegarde..."
    sudo tar -czf "$BACKUP_DIR/$BACKUP_NAME" -C "$DEST" .
    echo "   ✅ OK"
fi

# Arrêter le service
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "⏸️  Arrêt du service..."
    sudo systemctl stop "$SERVICE_NAME"
    echo "   ✅ OK"
fi

# Synchroniser les fichiers
echo "🔄 Copie des fichiers..."
sudo rsync -av --delete \
    --exclude '.git' \
    --exclude '.gitignore' \
    --exclude 'deploy.sh' \
    --exclude 'install-*.sh' \
    --exclude '*.backup' \
    --exclude '__pycache__' \
    --exclude 'README.md' \
    --exclude 'QUICK_START.md' \
    "$SRC" "$DEST"
echo "   ✅ OK"

# Permissions
echo "🔐 Permissions..."
sudo chown -R "$USER":"$GROUP" "$DEST"
sudo chmod -R 755 "$DEST"
sudo chmod 755 "$DEST/server.py"
echo "   ✅ OK"

# Redémarrer le service
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    echo "▶️  Démarrage du service..."
    sudo systemctl daemon-reload
    sudo systemctl start "$SERVICE_NAME"
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "   ✅ Service actif"
    else
        echo "   ❌ Erreur de démarrage !"
        sudo journalctl -u "$SERVICE_NAME" -n 10 --no-pager
        exit 1
    fi
else
    echo "⚠️  Service non installé"
    echo "   💡 Lancez : ./install-service.sh"
fi

# Recharger Nginx
if command -v nginx &> /dev/null; then
    echo "🔄 Rechargement Nginx..."
    sudo nginx -t && sudo systemctl reload nginx
    echo "   ✅ OK"
fi

# Nettoyage des sauvegardes (garde les 5 dernières)
cd "$BACKUP_DIR"
ls -tp | grep 'html-backup-' | tail -n +6 | xargs -I {} rm -f {} 2>/dev/null || true

echo ""
echo "✨ Déploiement terminé !"
echo "======================="
echo "💾 Sauvegarde : $BACKUP_NAME"
echo ""
