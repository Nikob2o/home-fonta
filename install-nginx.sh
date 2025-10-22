#!/bin/bash
# Installation de la configuration Nginx

set -e

CONFIG_NAME="home-fonta"
WORK_DIR="/home/nocob/home-fonta"
AVAILABLE="/etc/nginx/sites-available/${CONFIG_NAME}"
ENABLED="/etc/nginx/sites-enabled/${CONFIG_NAME}"

echo "🔧 Installation configuration Nginx"
echo "===================================="
echo ""

# Vérifier sudo
if [ "$EUID" -ne 0 ]; then 
	    echo "❌ Lancez avec sudo"
	        exit 1
		fi

# Vérifier Nginx
if ! command -v nginx &> /dev/null; then
	    echo "❌ Nginx non installé"
	        echo "💡 sudo apt install nginx"
		    exit 1
		    fi

# Vérifier le fichier
if [ ! -f "$WORK_DIR/nginx-home-fonta.conf" ]; then
	    echo "❌ Fichier nginx-home-fonta.conf introuvable"
	        exit 1
		fi

# Copier la config
echo "📋 Installation..."
cp "$WORK_DIR/nginx-home-fonta.conf" "$AVAILABLE"

# Créer le lien symbolique
[ -L "$ENABLED" ] && rm "$ENABLED"
ln -s "$AVAILABLE" "$ENABLED"

# Tester
echo "🧪 Test de la configuration..."
if nginx -t; then
	    echo "   ✅ Configuration valide"
	    else
		        echo "   ❌ Configuration invalide !"
			    rm "$ENABLED"
			        exit 1
				fi

# Recharger
echo "🔄 Rechargement..."
systemctl reload nginx
echo "   ✅ OK"

echo ""
echo "✨ Installation réussie !"
echo "========================"
echo ""
echo "💡 N'oubliez pas de modifier le server_name"
echo "   dans : $AVAILABLE"
echo ""
echo "Logs :"
echo "  tail -f /var/log/nginx/home-fonta-access.log"
echo "  tail -f /var/log/nginx/home-fonta-error.log"
echo ""
