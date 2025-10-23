# 🔥 Home-Fonta.fr - Documentation Flask

## 📋 Table des matières

1. [Architecture Flask](#architecture)
2. [Structure du code](#structure)
3. [Routes disponibles](#routes)
4. [Configuration Gunicorn](#gunicorn)
5. [Ajouter des fonctionnalités](#features)
6. [Performance & Optimisation](#performance)
7. [Dépannage](#depannage)

---

## 🏗️ Architecture Flask {#architecture}

### **Stack technique**

```
┌─────────────────────────────────────┐
│  Nginx (reverse proxy)              │
│  - SSL/TLS (Let's Encrypt)         │
│  - Gzip compression                 │
│  - Static caching                   │
└──────────────┬──────────────────────┘
               ↓
┌─────────────────────────────────────┐
│  Docker Container                   │
│  ┌───────────────────────────────┐ │
│  │  Gunicorn (WSGI Server)       │ │
│  │  - 2 workers                  │ │
│  │  - 2 threads per worker       │ │
│  │  - Port 8000                  │ │
│  └──────────────┬────────────────┘ │
│                 ↓                   │
│  ┌───────────────────────────────┐ │
│  │  Flask Application            │ │
│  │  - app.py (routes)            │ │
│  │  - wsgi.py (entry point)      │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### **Avantages de cette stack**

✅ **Performance** - Gunicorn multi-workers + threads  
✅ **Scalabilité** - Facile d'ajouter des workers  
✅ **Production-ready** - Configuration optimale  
✅ **Logs structurés** - Via Docker + Gunicorn  
✅ **Health checks** - Endpoint dédié  
✅ **Zero-downtime deploys** - Graceful reload  

---

## 📁 Structure du code {#structure}

```
~/home-fonta/
├── app.py                 # Application Flask principale
├── wsgi.py               # Point d'entrée WSGI
├── requirements.txt      # Dépendances Python
├── Dockerfile            # Image Docker
├── docker-compose.yml    # Orchestration
│
├── templates/            # Templates Jinja2 (si besoin)
│   └── ...
│
├── static/              # Fichiers statiques (actuellement à la racine)
│   ├── css/
│   ├── js/
│   └── images/
│
├── index.html           # Pages HTML
├── style.css
├── script.js
└── images/
```

---

## 🛣️ Routes disponibles {#routes}

### **Routes actuelles**

```python
# Page d'accueil
GET /                    → index.html

# Toutes les autres pages
GET /<path>             → Sert le fichier demandé
                          (HTML, CSS, JS, images)

# Health check (pour Docker)
GET /health             → {"status": "ok", "server": "Flask+Gunicorn"}

# Erreur 404
GET /inexistant         → 404.html (si existe) ou message par défaut
```

### **Exemples de requêtes**

```bash
# Page d'accueil
curl http://localhost:8002/

# CSS
curl http://localhost:8002/style.css

# Image
curl http://localhost:8002/images/ours.jpg

# Health check
curl http://localhost:8002/health
```

---

## 🚀 Ajouter des fonctionnalités {#features}

### **1. Ajouter une nouvelle route simple**

```python
# Dans app.py
@app.route('/about')
def about():
    return send_from_directory('.', 'about.html')
```

Puis créez `about.html` et `docker-compose restart`.

---

### **2. Créer une API REST**

```python
from flask import jsonify

@app.route('/api/photos')
def api_photos():
    """Liste toutes les photos du dossier images/"""
    import os
    photos = os.listdir('images/')
    return jsonify({
        'count': len(photos),
        'photos': photos
    })

# Test : curl http://localhost:8002/api/photos
```

---

### **3. Formulaire de contact**

**a) Créer la route POST :**

```python
from flask import request, redirect, flash

@app.route('/contact', methods=['POST'])
def contact():
    name = request.form.get('name')
    email = request.form.get('email')
    message = request.form.get('message')
    
    # Envoyer un email, stocker en DB, etc.
    # TODO: Implémenter l'envoi
    
    flash('Message envoyé !', 'success')
    return redirect('/')
```

**b) HTML du formulaire :**

```html
<!-- Dans index.html ou contact.html -->
<form action="/contact" method="POST">
    <input type="text" name="name" placeholder="Nom" required>
    <input type="email" name="email" placeholder="Email" required>
    <textarea name="message" placeholder="Message" required></textarea>
    <button type="submit">Envoyer</button>
</form>
```

---

### **4. Utiliser des templates Jinja2**

**a) Créer le dossier templates :**

```bash
mkdir ~/home-fonta/templates
```

**b) Créer un template :**

```html
<!-- templates/base.html -->
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}Home-Fonta.fr{% endblock %}</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
    {% block content %}{% endblock %}
</body>
</html>
```

**c) Utiliser le template :**

```python
from flask import render_template

@app.route('/dynamic')
def dynamic():
    photos = os.listdir('images/')
    return render_template('gallery.html', photos=photos)
```

---

### **5. Ajouter une base de données (SQLite)**

**a) Installer SQLAlchemy :**

```bash
# Ajouter dans requirements.txt
Flask-SQLAlchemy==3.0.5
```

**b) Configuration :**

```python
from flask_sqlalchemy import SQLAlchemy

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///site.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

class Article(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# Créer les tables
with app.app_context():
    db.create_all()
```

**c) Utiliser la DB :**

```python
@app.route('/blog')
def blog():
    articles = Article.query.all()
    return render_template('blog.html', articles=articles)
```

---

### **6. Authentification simple**

```python
from flask import session
from functools import wraps

app.secret_key = 'votre-cle-secrete-tres-longue'

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return redirect('/login')
        return f(*args, **kwargs)
    return decorated_function

@app.route('/admin')
@login_required
def admin():
    return "Page admin protégée"

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        # Vérifier les credentials
        if check_password(request.form['password']):
            session['user_id'] = 1
            return redirect('/admin')
    return send_from_directory('.', 'login.html')

@app.route('/logout')
def logout():
    session.pop('user_id', None)
    return redirect('/')
```

---

## ⚙️ Configuration Gunicorn {#gunicorn}

### **Configuration actuelle**

```dockerfile
# Dans Dockerfile
CMD ["gunicorn", 
     "--bind", "0.0.0.0:8000",
     "--workers", "2",           # Nombre de workers
     "--threads", "2",            # Threads par worker
     "--timeout", "60",           # Timeout requête
     "--access-logfile", "-",     # Logs accès
     "--error-logfile", "-",      # Logs erreur
     "wsgi:app"]
```

### **Optimisations possibles**

#### **Serveur puissant (4+ CPU cores)**

```dockerfile
CMD ["gunicorn", 
     "--bind", "0.0.0.0:8000",
     "--workers", "4",           # Plus de workers
     "--threads", "4",           # Plus de threads
     "--worker-class", "gthread",
     "--timeout", "60",
     "wsgi:app"]
```

#### **Serveur limité (Raspberry Pi)**

```dockerfile
CMD ["gunicorn", 
     "--bind", "0.0.0.0:8000",
     "--workers", "1",           # 1 seul worker
     "--threads", "2",
     "--timeout", "120",          # Timeout plus long
     "wsgi:app"]
```

#### **Très haute performance (async)**

```bash
# Ajouter dans requirements.txt
gevent==23.9.1

# Dans Dockerfile
CMD ["gunicorn", 
     "--bind", "0.0.0.0:8000",
     "--workers", "2",
     "--worker-class", "gevent",  # Workers async
     "--worker-connections", "1000",
     "wsgi:app"]
```

### **Formule workers**

```
workers = (2 × CPU_cores) + 1
```

**Exemples :**
- 1 CPU → 3 workers
- 2 CPU → 5 workers
- 4 CPU → 9 workers

---

## 📊 Performance & Optimisation {#performance}

### **1. Activer le cache des fichiers statiques**

```python
# Dans app.py
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 31536000  # 1 an pour prod

# Ou conditionnel
if os.environ.get('FLASK_ENV') == 'production':
    app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 31536000
else:
    app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0  # Pas de cache en dev
```

### **2. Compression Gzip**

```python
from flask_compress import Compress

Compress(app)

# Ajouter dans requirements.txt
Flask-Compress==1.14
```

### **3. Rate limiting (anti-spam)**

```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

@app.route('/api/data')
@limiter.limit("10 per minute")
def api_data():
    return jsonify({'data': 'valeur'})

# Ajouter dans requirements.txt
Flask-Limiter==3.5.0
```

### **4. Monitoring avec Prometheus**

```python
from prometheus_flask_exporter import PrometheusMetrics

metrics = PrometheusMetrics(app)

# Métriques automatiques sur /metrics
# Compatible avec Prometheus + Grafana

# Ajouter dans requirements.txt
prometheus-flask-exporter==0.22.4
```

---

## 🔧 Dépannage {#depannage}

### **Le site affiche "500 Internal Server Error"**

```bash
# Voir les logs Flask
docker-compose logs -f

# Vérifier les erreurs Python
docker exec -it home-fonta-flask python3 -c "import app"
```

### **Les modifications ne s'appliquent pas**

```bash
# Option 1 : Redémarrer
docker-compose restart

# Option 2 : Rebuild complet
docker-compose down
docker-compose up -d --build

# Vider le cache navigateur
Ctrl + Shift + R
```

### **"ModuleNotFoundError: No module named 'XXX'"**

```bash
# Ajouter le module dans requirements.txt
echo "module-name==version" >> requirements.txt

# Rebuild
docker-compose up -d --build
```

### **Performance faible**

```bash
# Augmenter les workers (dans Dockerfile)
--workers 4

# Passer en mode async
--worker-class gevent

# Rebuild
docker-compose up -d --build
```

### **Erreur "Address already in use"**

```bash
# Voir ce qui utilise le port
sudo lsof -i :8002

# Arrêter Docker
docker-compose down

# Changer le port dans docker-compose.yml
ports:
  - "127.0.0.1:8003:8000"
```

---

## 📝 Workflow de développement

### **Développement local (hors Docker)**

```bash
# Installer les dépendances
pip install -r requirements.txt

# Lancer Flask en mode debug
python3 app.py

# Accessible sur http://localhost:8000
```

### **Test en production (dans Docker)**

```bash
# Build et démarrage
docker-compose up -d --build

# Logs en temps réel
docker-compose logs -f

# Test
curl http://localhost:8002/health
```

### **Déploiement**

```bash
# 1. Commit
git add .
git commit -m "Nouvelle feature"
git push

# 2. Rebuild Docker
docker-compose up -d --build

# 3. Vérifier
curl https://home-fonta.fr/health
```

---

## 🎯 Exemples d'utilisation avancée

### **Servir plusieurs domaines**

```python
@app.before_request
def redirect_subdomain():
    if request.host == 'api.home-fonta.fr':
        # Logique API
        pass
    elif request.host == 'blog.home-fonta.fr':
        # Logique blog
        pass
```

### **WebSockets (temps réel)**

```bash
# Ajouter dans requirements.txt
Flask-SocketIO==5.3.5
python-socketio==5.10.0

# Dans app.py
from flask_socketio import SocketIO, emit

socketio = SocketIO(app)

@socketio.on('message')
def handle_message(data):
    emit('response', {'data': 'Message reçu'})
```

### **Upload de fichiers**

```python
from werkzeug.utils import secure_filename

UPLOAD_FOLDER = 'uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

@app.route('/upload', methods=['POST'])
def upload():
    if 'file' not in request.files:
        return 'No file', 400
    
    file = request.files['file']
    if file.filename == '':
        return 'No selected file', 400
    
    filename = secure_filename(file.filename)
    file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
    return 'File uploaded', 200
```

---

## 📚 Ressources

- **Flask Documentation** : https://flask.palletsprojects.com/
- **Gunicorn Documentation** : https://docs.gunicorn.org/
- **Flask Extensions** : https://flask.palletsprojects.com/extensions/
- **Best Practices** : https://flask.palletsprojects.com/patterns/

---

**Documentation Flask créée le 22 octobre 2025 par **  
**Version : 1.0 - Flask + Gunicorn + Docker**
