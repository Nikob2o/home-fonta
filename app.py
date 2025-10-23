#!/usr/bin/env python3
"""
Application Flask pour Home-Fonta.fr
"""

from flask import Flask, send_from_directory, abort
import os

app = Flask(__name__, static_folder='.', static_url_path='')

# Configuration
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0  # Désactive le cache pour dev

@app.route('/')
def index():
    """Page d'accueil"""
    return send_from_directory('.', 'index.html')

@app.route('/<path:path>')
def serve_file(path):
    """Sert tous les autres fichiers (HTML, CSS, JS, images)"""
    try:
        return send_from_directory('.', path)
    except:
        abort(404)

@app.route('/health')
def health():
    """Health check pour Docker"""
    return {'status': 'ok', 'server': 'Flask+Gunicorn'}, 200

@app.errorhandler(404)
def not_found(e):
    """Page 404 personnalisée"""
    if os.path.exists('404.html'):
        return send_from_directory('.', '404.html'), 404
    return "404 - Page non trouvée", 404

if __name__ == '__main__':
    # Mode debug pour tests locaux uniquement
    app.run(host='0.0.0.0', port=8000, debug=True)
