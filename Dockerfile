# Dockerfile pour Home-Fonta.fr - Flask + Gunicorn
FROM python:3.11-slim

# Métadonnées
LABEL maintainer="home-fonta.fr"
LABEL description="Serveur Flask + Gunicorn pour Home-Fonta.fr"

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PORT=8000

# Créer un utilisateur non-root
RUN useradd -m -u 1000 webuser

# Répertoire de travail
WORKDIR /app

# Copier requirements et installer les dépendances
COPY --chown=webuser:webuser requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copier tout le reste
COPY --chown=webuser:webuser . /app/

# Exposer le port
EXPOSE 8000

# Utiliser l'utilisateur non-root
USER webuser

# Lancer Gunicorn avec Flask
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "2", "--timeout", "60", "--access-logfile", "-", "--error-logfile", "-", "wsgi:app"]
