#!/usr/bin/env python3
"""
Point d'entrée WSGI pour Gunicorn
"""

from app import app

if __name__ == "__main__":
    app.run()
