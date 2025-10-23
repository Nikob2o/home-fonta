# Dockerfile pour Home-Fonta.fr
FROM python:3.11-slim

# Métadonnées
LABEL maintainer="home-fonta.fr"
LABEL description="Serveur web Python pour Home-Fonta.fr"

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PORT=8000

# Créer un utilisateur non-root
RUN useradd -m -u 1000 webuser

# Répertoire de travail
WORKDIR /app

# Copier les fichiers du site
COPY --chown=webuser:webuser . /app/

# Exposer le port
EXPOSE 8000

# Utiliser l'utilisateur non-root
USER webuser

# Lancer le serveur Python
CMD ["python3", "server.py"]
