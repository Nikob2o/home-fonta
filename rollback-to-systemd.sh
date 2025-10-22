#!/bin/bash
# Retour arrière : bascule de Docker vers systemd

set -e

echo "🔙 Retour vers systemd"
echo "======================"
echo ""

# Restaurer la config Nginx
echo "📝 Restauration de la config Nginx..."
if [ -f "/etc/nginx/sites-available/home-fonta.fr.backup" ]; then
    sudo cp /etc/nginx/sites-available/home-fonta.fr.backup /etc/nginx/sites-available/home-fonta.fr
    echo "   ✅ Config restaurée"
else
    echo "   ⚠️  Pas de sauvegarde trouvée, modification manuelle..."
    sudo sed -i 's/proxy_pass http:\/\/127.0.0.1:8001;/proxy_pass http:\/\/127.0.0.1:8000;/g' /etc/nginx/sites-available/home-fonta.fr
fi

# Tester la config
echo ""
echo "🧪 Test de la config Nginx..."
sudo nginx -t
echo "   ✅ Config valide"

# Redémarrer systemd
echo ""
echo "▶️  Redémarrage du service systemd..."
sudo systemctl enable home-fonta
sudo systemctl start home-fonta
sleep 2

if systemctl is-active --quiet home-fonta; then
    echo "   ✅ Service systemd actif"
else
    echo "   ❌ Erreur de démarrage"
    sudo journalctl -u home-fonta -n 20 --no-pager
    exit 1
fi

# Recharger Nginx
echo ""
echo "🔄 Rechargement de Nginx..."
sudo systemctl reload nginx
echo "   ✅ Nginx rechargé"

# Arrêter Docker
echo ""
echo "⏸️  Arrêt de Docker..."
docker compose down
echo "   ✅ Docker arrêté"

echo ""
echo "✨ Retour arrière effectué !"
echo "==========================="
echo ""
echo "📊 État actuel :"
echo "   - Nginx pointe vers : http://127.0.0.1:8000 (systemd)"
echo "   - Service systemd : actif"
echo "   - Container Docker : arrêté"
echo ""
echo "📋 Vérifier :"
echo "   sudo systemctl status home-fonta"
echo "   curl https://home-fonta.fr"
echo ""
