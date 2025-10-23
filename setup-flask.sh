#!/bin/bash
# Migration vers Flask + Gunicorn

set -e

echo "🔥 Migration vers Flask + Gunicorn"
echo "==================================="
echo ""

# Vérifier les fichiers nécessaires
if [ ! -f "app.py" ]; then
    echo "❌ Fichier app.py manquant"
    exit 1
fi

if [ ! -f "requirements.txt" ]; then
    echo "❌ Fichier requirements.txt manquant"
    exit 1
fi

if [ ! -f "Dockerfile" ]; then
    echo "❌ Fichier Dockerfile manquant"
    exit 1
fi

echo "✅ Tous les fichiers sont présents"
echo ""

# Arrêter l'ancien container Python
echo "⏸️  Arrêt de l'ancien container..."
docker compose down
echo "   ✅ Container arrêté"

echo ""
echo "🏗️  Build de la nouvelle image Flask..."
docker compose build --no-cache

echo ""
echo "▶️  Démarrage du container Flask (port 8002)..."
docker compose up -d

echo ""
echo "⏳ Attente du démarrage (10 secondes)..."
sleep 10

# Vérifier que le container tourne
if docker ps | grep -q "home-fonta-flask"; then
    echo "   ✅ Container Flask démarré"
else
    echo "   ❌ Erreur de démarrage"
    echo ""
    echo "📋 Logs :"
    docker-compose logs
    exit 1
fi

echo ""
echo "🧪 Test du serveur Flask..."

# Test health check
if curl -s http://127.0.0.1:8002/health | grep -q "ok"; then
    echo "   ✅ Health check OK"
else
    echo "   ❌ Health check échoué"
    docker compose logs
    exit 1
fi

# Test page d'accueil
if curl -s http://127.0.0.1:8002 > /dev/null; then
    echo "   ✅ Page d'accueil accessible"
else
    echo "   ❌ Page d'accueil inaccessible"
    docker compose logs
    exit 1
fi

echo ""
echo "✨ Migration Flask terminée avec succès !"
echo "========================================="
echo ""
echo "📊 État actuel :"
echo "   - Flask (test)         : http://127.0.0.1:8002"
echo "   - Docker Python (prod) : http://127.0.0.1:8001 (si encore actif)"
echo ""
echo "🧪 Testez Flask :"
echo "   curl http://127.0.0.1:8002"
echo "   curl http://127.0.0.1:8002/health"
echo "   ou ouvrez http://localhost:8002 dans un navigateur"
echo ""
echo "📋 Commandes utiles :"
echo "   docker-compose logs -f        # Logs en temps réel"
echo "   docker-compose restart        # Redémarrer"
echo ""
echo "🔄 Prochaine étape :"
echo "   Quand Flask fonctionne bien, basculez Nginx avec :"
echo "   ./switch-to-flask.sh"
echo ""
