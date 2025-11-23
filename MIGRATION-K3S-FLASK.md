# Migration du site home-fonta.fr vers Kubernetes (K3s)

## 📋 Résumé du projet

**Objectif** : Migrer le site Flask home-fonta.fr depuis un environnement Docker simple vers un cluster Kubernetes K3s sur Raspberry Pi, avec une architecture de production professionnelle.

**Durée** : Novembre 2025 (environ 1 semaine de travail intensif)

**Résultat** : Site fonctionnel, rapide (~150ms), avec architecture NGINX + Flask, certificats SSL automatiques, et déploiement via Helm.

---

## 🖥️ Infrastructure matérielle

### Cluster K3s (4 nodes Raspberry Pi)

| Hostname | IP | Rôle | Matériel | OS |
|----------|-----|------|----------|-----|
| rpi4-master | 192.168.1.51 | control-plane, master | Raspberry Pi 4 8GB | Debian 13 (trixie) |
| rpi4-worker | 192.168.1.50 | worker | Raspberry Pi 4 | Debian 13 (trixie) |
| rpi3-worker1 | 192.168.1.36 | worker | Raspberry Pi 3 | Debian 13 (trixie) |
| rpi3-worker2 | 192.168.1.15 | worker | Raspberry Pi 3 | Debian 13 (trixie) |

**Versions** :
- Kubernetes : v1.33.5+k3s1
- Container Runtime : containerd://2.1.4-k3s1
- Kernel : 6.12.47+rpt-rpi-v8 (ARM64)

### Services externes

| Service | IP/Hostname | Port | Description |
|---------|-------------|------|-------------|
| NAS QNAP | 192.168.1.18 | - | Stockage, CDN images |
| Cloudflare | - | - | DNS, proxy |
| Docker Hub | hub.docker.com | - | Registry images |

---

## 🏗️ Architecture finale

### Schéma de l'architecture

```
Internet (Cloudflare DNS)
         │
         ▼
    Ingress Controller (NGINX)
    [rpi4-master:192.168.1.51]
         │
         ▼
    Service ClusterIP (port 80)
         │
         ▼
    ┌─────────────────────────────────┐
    │     Pod home-fonta-web          │
    │  ┌───────────────────────────┐  │
    │  │     NGINX (:80)           │  │
    │  │  ┌─────────────────────┐  │  │
    │  │  │ /static/* → disque  │  │  │
    │  │  │ /* → proxy_pass     │──┼──┼──┐
    │  │  └─────────────────────┘  │  │  │
    │  └───────────────────────────┘  │  │
    │                                  │  │
    │  ┌───────────────────────────┐  │  │
    │  │  Gunicorn (:8000)         │◄─┼──┘
    │  │  └─ Flask App             │  │
    │  └───────────────────────────┘  │
    │                                  │
    │  Supervisord (PID 1)            │
    └─────────────────────────────────┘
```

### Avantages de cette architecture

| Aspect | Avant (Flask seul) | Après (NGINX + Flask) |
|--------|-------------------|----------------------|
| Fichiers statiques | Lent (Python) | Très rapide (C) |
| Gestion cache | Manuelle | Headers automatiques |
| Compression gzip | Non | Automatique |
| Connexions simultanées | ~100 | ~10,000+ |
| Temps de réponse | 10-15s | ~150ms |

---

## 📁 Structure du projet

```
home-fonta/
├── app.py                    # Application Flask
├── requirements.txt          # Dépendances Python
├── Dockerfile                # Multi-stage build NGINX+Flask
├── nginx/
│   └── default.conf          # Configuration NGINX
├── templates/
│   ├── index.html            # Page d'accueil
│   ├── galerie.html          # Galerie photos
│   ├── presentation.html     # Présentation
│   ├── services.html         # Services
│   ├── menu.html             # Menu sidebar
│   └── 404.html              # Page erreur
└── static/
    ├── style.css             # Styles CSS
    ├── script.js             # JavaScript (menu, lightbox)
    └── images/               # Images optimisées
        ├── aigle.jpg
        ├── Bust.jpg
        └── ...
```

---

## ⚙️ Fichiers de configuration

### app.py

```python
from flask import Flask, render_template

app = Flask(__name__, 
    static_url_path='/static', 
    static_folder='static', 
    template_folder='templates'
)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/presentation')
def presentation():
    return render_template('presentation.html')

@app.route('/galerie')
def galerie():
    return render_template('galerie.html')

@app.route('/services')
def services():
    return render_template('services.html')

@app.route('/menu')
def menu():
    return render_template('menu.html')

@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
```

### requirements.txt

```
Flask==3.0.0
gunicorn==21.2.0
```

### nginx/default.conf

```nginx
server {
    listen 80;
    server_name _;

    # Logs
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Fichiers statiques - servis directement par NGINX
    location /static/ {
        alias /app/static/;
        expires 7d;
        add_header Cache-Control "public, immutable";
        
        # Compression gzip
        gzip on;
        gzip_types text/css application/javascript image/svg+xml image/jpeg image/png;
    }

    # Favicon
    location /favicon.ico {
        alias /app/static/images/ours.jpg;
        expires 30d;
    }

    # Tout le reste → Flask (Gunicorn)
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### Dockerfile (Multi-stage)

```dockerfile
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
```

---

## 🎛️ Configuration Kubernetes (Helm)

### values.yaml

```yaml
replicaCount: 3

image:
  repository: nocoblas/home-fonta-web
  pullPolicy: Always
  tag: "v3.1"

fullnameOverride: "home-fonta-web"

service:
  type: ClusterIP
  port: 80
  targetPort: 80

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod-dns"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: home-fonta.fr
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: wildcard-homefonta-tls
      hosts:
        - home-fonta.fr

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe:
  enabled: true
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  enabled: true
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# IMPORTANT: Forcer les pods sur le master pour éviter les problèmes CNI
nodeSelector:
  kubernetes.io/hostname: rpi4-master
```

---

## 🚀 Commandes de déploiement

### Build et push de l'image

```bash
cd ~/DevOps/home-fonta

# Build pour ARM64 avec buildx
docker buildx build \
    --platform linux/arm64 \
    -t nocoblas/home-fonta-web:v3.1 \
    --push \
    .
```

### Déploiement avec Helm

```bash
cd ~/DevOps/ansible-k3s/helm-charts/homefonta

# Installation initiale
helm install home-fonta . -n home-fonta --create-namespace

# Mise à jour
helm upgrade home-fonta . -n home-fonta --set image.tag=v3.1

# Rollback si problème
helm rollback home-fonta -n home-fonta
```

### Vérification

```bash
# État des pods
kubectl get pods -n home-fonta -o wide

# Logs
kubectl logs -n home-fonta -l app=homefonta --tail=50

# Test du site
time curl -I https://home-fonta.fr
time curl -I https://home-fonta.fr/static/style.css
```

---

## 🔐 Certificats SSL

### Configuration cert-manager

Le cluster utilise **cert-manager** avec un **ClusterIssuer** pour Let's Encrypt :

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: votre-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-dns
    solvers:
    - dns01:
        cloudflare:
          email: votre-email@example.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
```

### Certificat wildcard

Un certificat wildcard `*.home-fonta.fr` est utilisé pour tous les sous-domaines :

```bash
# Vérifier l'état du certificat
kubectl get certificate -n home-fonta

# Détails
kubectl describe certificate wildcard-homefonta-tls -n home-fonta
```

---

## 📊 Métriques de performance

| Métrique | Avant migration | Après migration |
|----------|-----------------|-----------------|
| Temps de réponse (HTML) | 10-15s | ~150ms |
| Temps de réponse (CSS) | 504 timeout | ~150ms |
| Temps de réponse (images) | 504 timeout | ~150ms |
| Disponibilité | Intermittente | 100% |

---

## 📝 Historique des versions

| Version | Date | Changements |
|---------|------|-------------|
| v2.0 | Nov 2025 | Migration initiale vers K3s |
| v2.1 | Nov 2025 | Ajout menu burger responsive |
| v2.2 | Nov 2025 | Images optimisées |
| v2.3 | Nov 2025 | Correction templates CDN |
| v2.4.1 | Nov 2025 | Patch Flask route /static |
| v3.0 | Nov 2025 | Architecture NGINX + Supervisor |
| v3.1 | Nov 2025 | Correction syntaxe Jinja2 galerie |

---

## 🔗 Ressources

- **Repository Git** : ~/DevOps/ansible-k3s
- **Code source** : ~/DevOps/home-fonta-backup/home/nocob/home-fonta
- **Docker Hub** : nocoblas/home-fonta-web
- **Site production** : https://home-fonta.fr

---

## ✅ Checklist de maintenance

- [ ] Vérifier les certificats SSL (renouvellement automatique)
- [ ] Surveiller les logs (`kubectl logs`)
- [ ] Vérifier l'utilisation des ressources (`kubectl top pods`)
- [ ] Sauvegarder les configurations Helm
- [ ] Tester le site après chaque mise à jour

---

*Documentation générée le 23 novembre 2025*
