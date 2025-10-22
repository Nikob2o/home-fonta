#!/usr/bin/env python3
"""
Serveur Web Python pour Home-Fonta.fr
Lance un serveur HTTP sur le port 8000 (localhost uniquement)

Usage:
    python3 server.py
"""

import http.server
import socketserver
import sys
import os
import signal
from datetime import datetime

# Configuration
PORT = 8000
HOST = "127.0.0.1"  # Écoute uniquement sur localhost (Nginx fera le proxy)

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    """Handler HTTP personnalisé"""
    
    def log_message(self, format, *args):
        """Logs avec timestamp"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        sys.stdout.write(f"[{timestamp}] {format % args}\n")
        sys.stdout.flush()
    
    def end_headers(self):
        """Headers personnalisés"""
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

class ReuseAddrServer(socketserver.TCPServer):
    """Serveur qui permet la réutilisation d'adresse"""
    allow_reuse_address = True

def signal_handler(sig, frame):
    """Arrêt propre du serveur"""
    print("\n👋 Serveur arrêté")
    sys.exit(0)

def main():
    """Démarre le serveur"""
    
    # Gestion des signaux
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        with ReuseAddrServer((HOST, PORT), CustomHandler) as httpd:
            print("=" * 60)
            print("🚀 Serveur Home-Fonta.fr démarré")
            print("=" * 60)
            print(f"🌐 Écoute sur : http://{HOST}:{PORT}")
            print(f"⏰ Démarré à  : {datetime.now().strftime('%H:%M:%S')}")
            print(f"💡 Pour arrêter : Ctrl+C")
            print("=" * 60)
            
            httpd.serve_forever()
            
    except PermissionError:
        print(f"❌ Permission refusée pour le port {PORT}")
        sys.exit(1)
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"❌ Port {PORT} déjà utilisé")
            print(f"💡 Arrêtez l'ancien processus : sudo systemctl stop home-fonta")
        else:
            print(f"❌ Erreur : {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
