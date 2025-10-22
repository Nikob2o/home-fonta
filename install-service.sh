#!/bin/bash
# Installation du service systemd

set -e

SERVICE_NAME="home-fonta"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
WORK_DIR="/home/nocob/home-fonta"

echo "🔧 Installation du service systemd"
echo "==================================="
echo ""

# Vérifier sudo
if [ "$EUID" -ne 0 ]; then 
	    echo "❌ Lancez avec sudo"
	        exit 1
		fi

# Vérifier que le fichier existe
if [ ! -f "$WORK_DIR/home-fonta.service" ]; then
	    echo "❌ Fichier home-fonta.service introuvable"
	        exit 1
		fi

# Copier le service
echo "📋 Installation..."
cp "$WORK_DIR/home-fonta.service" "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
	    echo "   ✅ Service actif"
	    else
		        echo "   ❌ Erreur !"
			    journalctl -u "$SERVICE_NAME" -n 10 --no-pager
			        exit 1
				fi

				echo ""
				echo "✨ Installation réussie !"
				echo "========================"
				echo ""
				echo "Commandes utiles :"
				echo "  sudo systemctl status home-fonta"
				echo "  sudo systemctl restart home-fonta"
				echo "  sudo journalctl -u home-fonta -f"
				echo ""
