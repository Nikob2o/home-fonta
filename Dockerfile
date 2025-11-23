# ============================================
# Stage 1: Builder Python
# ============================================
FROM python:3.12-slim AS python-builder

WORKDIR /app

# Installer les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code Flask
COPY app.py .
COPY templates/ templates/

# ============================================
# Stage 2: Production avec NGINX + Supervisor
# ============================================
FROM python:3.12-slim

# Installer NGINX et Supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

WORKDIR /app

# Copier les dépendances Python depuis le builder
COPY --from=python-builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=python-builder /usr/local/bin/gunicorn /usr/local/bin/gunicorn

# Copier l'application
COPY --from=python-builder /app /app

# Copier les fichiers statiques
COPY static/ /app/static/

# Copier la config NGINX
COPY nginx/default.conf /etc/nginx/sites-enabled/default

# Créer la config Supervisor
RUN echo '[supervisord]' > /etc/supervisor/conf.d/app.conf && \
    echo 'nodaemon=true' >> /etc/supervisor/conf.d/app.conf && \
    echo '' >> /etc/supervisor/conf.d/app.conf && \
    echo '[program:nginx]' >> /etc/supervisor/conf.d/app.conf && \
    echo 'command=/usr/sbin/nginx -g "daemon off;"' >> /etc/supervisor/conf.d/app.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/app.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisor/conf.d/app.conf && \
    echo '' >> /etc/supervisor/conf.d/app.conf && \
    echo '[program:gunicorn]' >> /etc/supervisor/conf.d/app.conf && \
    echo 'command=/usr/local/bin/gunicorn --bind 127.0.0.1:8000 --workers 2 --threads 2 app:app' >> /etc/supervisor/conf.d/app.conf && \
    echo 'directory=/app' >> /etc/supervisor/conf.d/app.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/app.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisor/conf.d/app.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisor/conf.d/app.conf

# Créer les dossiers de logs nginx
RUN mkdir -p /var/log/nginx && \
    touch /var/log/nginx/access.log /var/log/nginx/error.log

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
