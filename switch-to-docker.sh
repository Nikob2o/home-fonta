#!/bin/bash
# Bascule Nginx du serveur systemd vers Docker (zéro downtime)

set -e

echo "🔄 Bascule vers Docker"
echo "====================="
echo ""

# Vérifier que Docker tourne
if ! docker ps | grep -q "home-fonta-web"; then
    echo "❌ Le container Docker ne tourne pas"
    echo "   Lancez d'abord : docker-compose up -d"
    exit 1
fi

# Tester Docker
echo "🧪 Test du container Docker..."
if ! curl -s http://127.0.0.1:8001 > /dev/null; then
    echo "❌ Docker ne répond pas sur le port 8001"
    exit 1
fi
echo "   ✅ Docker fonctionne"

# Sauvegarder la config Nginx actuelle
echo ""
echo "💾 Sauvegarde de la config Nginx..."
sudo cp /etc/nginx/sites-available/home-fonta /etc/nginx/sites-available/home-fonta.backup
echo "   ✅ Sauvegardé"

# Modifier la config Nginx pour pointer vers le port 8001 (Docker)
echo ""
echo "📝 Modification de la config Nginx..."
sudo sed -i 's/proxy_pass http:\/\/127.0.0.1:8000;/proxy_pass http:\/\/127.0.0.1:8001;/g' /etc/nginx/sites-available/home-fonta
echo "   ✅ Config modifiée (8000 → 8001)"

# Tester la config Nginx
echo ""
echo "🧪 Test de la config Nginx..."
if sudo nginx -t; then
    echo "   ✅ Config valide"
else
    echo "   ❌ Config invalide, restauration..."
    sudo cp /etc/nginx/sites-available/home-fonta.backup /etc/nginx/sites-available/home-fonta
    exit 1
fi

# Recharger Nginx (sans interruption)
echo ""
echo "🔄 Rechargement de Nginx..."
sudo systemctl reload nginx
echo "   ✅ Nginx rechargé"

# Vérifier que le site fonctionne
echo ""
echo "🧪 Test du site en production..."
sleep 2
if curl -s https://home-fonta.fr > /dev/null; then
    echo "   ✅ Site accessible via Docker"
else
    echo "   ⚠️  Impossible de tester HTTPS (normal si pas de certificat local)"
fi

# Arrêter l'ancien service systemd
echo ""
echo "⏸️  Arrêt du service systemd..."
sudo systemctl stop home-fonta
sudo systemctl disable home-fonta
echo "   ✅ Service systemd arrêté et désactivé"

echo ""
echo "✨ Bascule terminée avec succès !"
echo "================================"
echo ""
echo "📊 État actuel :"
echo "   - Nginx pointe vers : http://127.0.0.1:8001 (Docker)"
echo "   - Service systemd : arrêté"
echo "   - Container Docker : actif"
echo ""
echo "🔙 Retour arrière si problème :"
echo "   ./rollback-to-systemd.sh"
echo ""
echo "📋 Logs Docker :"
echo "   docker-compose logs -f"
echo ""
