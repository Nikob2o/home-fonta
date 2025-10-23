#!/bin/bash
# Bascule Nginx vers Flask (port 8002)

set -e

echo "🔄 Bascule vers Flask"
echo "===================="
echo ""

# Vérifier que Flask tourne
if ! docker ps | grep -q "home-fonta-flask"; then
    echo "❌ Le container Flask ne tourne pas"
    echo "   Lancez d'abord : ./setup-flask.sh"
    exit 1
fi

# Tester Flask
echo "🧪 Test de Flask..."
if ! curl -s http://127.0.0.1:8002/health | grep -q "ok"; then
    echo "❌ Flask ne répond pas correctement"
    exit 1
fi
echo "   ✅ Flask fonctionne"

# Sauvegarder la config Nginx
echo ""
echo "💾 Sauvegarde de la config Nginx..."
sudo cp /etc/nginx/sites-available/home-fonta /etc/nginx/sites-available/home-fonta.flask-backup
echo "   ✅ Sauvegardé"

# Modifier la config Nginx (8001 → 8002)
echo ""
echo "📝 Modification de la config Nginx..."
sudo sed -i 's/proxy_pass http:\/\/127.0.0.1:8001;/proxy_pass http:\/\/127.0.0.1:8002;/g' /etc/nginx/sites-available/home-fonta
echo "   ✅ Config modifiée (8001 → 8002)"

# Tester la config
echo ""
echo "🧪 Test de la config Nginx..."
if sudo nginx -t; then
    echo "   ✅ Config valide"
else
    echo "   ❌ Config invalide, restauration..."
    sudo cp /etc/nginx/sites-available/home-fonta.flask-backup /etc/nginx/sites-available/home-fonta
    exit 1
fi

# Recharger Nginx
echo ""
echo "🔄 Rechargement de Nginx..."
sudo systemctl reload nginx
echo "   ✅ Nginx rechargé"

# Vérifier le site
echo ""
echo "🧪 Test du site en production..."
sleep 2
if curl -s https://home-fonta.fr > /dev/null; then
    echo "   ✅ Site accessible via Flask"
else
    echo "   ⚠️  Test HTTPS non concluant (vérifiez manuellement)"
fi

echo ""
echo "✨ Bascule vers Flask terminée !"
echo "================================"
echo ""
echo "📊 État actuel :"
echo "   - Nginx pointe vers : http://127.0.0.1:8002 (Flask)"
echo "   - Container actif : home-fonta-flask"
echo ""
echo "📋 Logs Flask :"
echo "   docker-compose logs -f"
echo ""
echo "🎯 Avantages Flask :"
echo "   - Performance optimale avec Gunicorn"
echo "   - Production-ready"
echo "   - Évolutif (API, formulaires, etc.)"
echo ""
