#!/bin/bash
# Script d'installation et de test Docker en parallèle du site actuel

set -e

echo "🐳 Setup Docker pour Home-Fonta.fr"
echo "==================================="
echo ""

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé"
    echo ""
    echo "📥 Installation de Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "   ✅ Docker installé"
    echo ""
    echo "⚠️  Déconnectez-vous et reconnectez-vous pour que les permissions prennent effet"
    echo "   Puis relancez ce script"
    exit 0
fi

# Vérifier Docker Compose
if ! command -v docker compose &> /dev/null; then
    echo "📥 Installation de Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "   ✅ Docker Compose installé"
fi

echo "✅ Docker et Docker Compose sont installés"
echo ""

# Vérifier qu'on est dans le bon répertoire
if [ ! -f "Dockerfile" ]; then
    echo "❌ Fichier Dockerfile introuvable"
    echo "   Assurez-vous d'être dans ~/home-fonta/"
    exit 1
fi

echo ""
echo "🏗️  Build de l'image Docker..."
docker compose build

echo ""
echo "▶️  Démarrage du container (port 8001)..."
docker compose up -d

echo ""
echo "⏳ Attente du démarrage (5 secondes)..."
sleep 5

# Vérifier que le container tourne
if docker ps | grep -q "home-fonta-web"; then
    echo "   ✅ Container démarré"
else
    echo "   ❌ Erreur de démarrage"
    echo ""
    echo "📋 Logs :"
    docker compose logs
    exit 1
fi

echo ""
echo "🧪 Test du serveur Docker..."

# Test HTTP
if curl -s http://127.0.0.1:8001 > /dev/null; then
    echo "   ✅ Serveur Docker répond sur le port 8001"
else
    echo "   ❌ Serveur Docker ne répond pas"
    echo ""
    echo "📋 Logs :"
    docker compose logs
    exit 1
fi

echo ""
echo "✨ Setup Docker terminé avec succès !"
echo "===================================="
echo ""
echo "📊 État actuel :"
echo "   - Site actuel (systemd) : http://127.0.0.1:8000"
echo "   - Site Docker (test)    : http://127.0.0.1:8001"
echo ""
echo "🧪 Testez Docker :"
echo "   curl http://127.0.0.1:8001"
echo "   ou ouvrez dans un navigateur"
echo ""
echo "📋 Commandes Docker utiles :"
echo "   docker-compose logs -f        # Voir les logs en temps réel"
echo "   docker-compose restart        # Redémarrer"
echo "   docker-compose down           # Arrêter"
echo "   docker-compose up -d          # Démarrer"
echo ""
echo "🔄 Prochaine étape :"
echo "   Quand Docker fonctionne bien, basculez Nginx avec :"
echo "   ./switch-to-docker.sh"
echo ""
