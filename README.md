# 🏰 Home-Fonta.fr - Documentation complète

## 📋 Table des matières

1. [Architecture du serveur](#architecture)
2. [Comment ça fonctionne](#fonctionnement)
3. [Structure des fichiers](#structure)
4. [Workflow de développement](#workflow)
5. [Modifications futures](#modifications)
6. [Commandes utiles](#commandes)
7. [Dépannage](#depannage)

---

## 🏗️ Architecture du serveur {#architecture}

```
┌─────────────┐
│  Internet   │
└──────┬──────┘
       │ HTTPS (port 443)
       ↓
┌─────────────────────────────────┐
│  Nginx (Reverse Proxy)          │
│  - Gère SSL/TLS                 │
│  - Logs des accès               │
│  - Redirection HTTP → HTTPS     │
└──────┬──────────────────────────┘
       │ HTTP (localhost:8000)
       ↓
┌─────────────────────────────────┐
│  Python (Serveur Web)           │
│  - http.server                  │
│  - Tourne en arrière-plan       │
│  - Géré par systemd             │
└──────┬──────────────────────────┘
       │
       ↓
┌─────────────────────────────────┐
│  Fichiers statiques             │
│  /var/www/html/home-fonta/      │
│  - HTML, CSS, JS, images        │
└─────────────────────────────────┘
```

**Résumé :** Nginx reçoit les requêtes HTTPS et les redirige vers Python qui sert les fichiers.

---

## ⚙️ Comment ça fonctionne {#fonctionnement}

### **1. Le service systemd**

Votre serveur Python tourne en **arrière-plan** grâce à systemd :

- **Fichier** : `/etc/systemd/system/home-fonta.service`
- **Démarre automatiquement** au boot du serveur
- **Se relance automatiquement** en cas de crash (Restart=always)
- **Logs centralisés** via journalctl

**Configuration actuelle :**
```ini
[Service]
User=www-data                                    # Tourne avec l'utilisateur web
WorkingDirectory=/var/www/html/home-fonta       # Dossier de travail
ExecStart=/usr/bin/python3 server.py            # Commande de démarrage
Restart=always                                   # Redémarrage automatique
```

### **2. Le serveur Python (server.py)**

**Rôle :** Serveur HTTP simple qui sert les fichiers statiques

**Points clés :**
- Écoute sur `127.0.0.1:8000` (localhost uniquement, pas exposé à Internet)
- Utilise le module `http.server` de Python (standard, rien à installer)
- Force le répertoire `/var/www/html/home-fonta/` pour servir les fichiers
- Logs avec timestamps

**Code simplifié :**
```python
PORT = 8000
HOST = "127.0.0.1"
DIRECTORY = "/var/www/html/home-fonta"

# Sert les fichiers du répertoire spécifié
http.server.SimpleHTTPRequestHandler(directory=DIRECTORY)
```

### **3. Nginx (Reverse Proxy)**

**Fichier** : `/etc/nginx/sites-available/home-fonta.fr`

**Rôle :** 
- Reçoit les connexions HTTPS du monde extérieur
- Redirige vers Python sur `http://127.0.0.1:8000`
- Gère les certificats SSL (Let's Encrypt)
- Écrit les logs d'accès

**Configuration simplifiée :**
```nginx
server {
    listen 443 ssl;
    server_name home-fonta.fr;
    
    # Certificats SSL
    ssl_certificate /etc/letsencrypt/live/home-fonta.fr/fullchain.pem;
    
    # Proxy vers Python
    location / {
        proxy_pass http://127.0.0.1:8000;
    }
}
```

---

## 📁 Structure des fichiers {#structure}

### **Développement** : `~/home-fonta/`

```
/home/nocob/home-fonta/
├── 🔧 Serveur & Configuration
│   ├── server.py                  # Serveur Python
│   ├── home-fonta.service        # Service systemd
│   ├── nginx-home-fonta.conf     # Config Nginx (ancienne, non utilisée)
│   │
├── 📜 Scripts
│   ├── deploy.sh                 # 🌟 Script de déploiement
│   ├── install-service.sh        # Installation du service (une fois)
│   └── install-nginx.sh          # Installation Nginx (une fois)
│   │
├── 🌐 Site Web
│   ├── index.html                # Page d'accueil
│   ├── presentation.html         # Page présentation
│   ├── services.html             # Page services
│   ├── galerie.html              # Page galerie
│   ├── menu.html                 # Menu (chargé dynamiquement)
│   ├── style.css                 # Styles
│   ├── script.js                 # JavaScript
│   └── images/                   # Images
│       ├── ours.jpg
│       ├── Macro_briquet.jpg
│       └── ...
│   │
└── 📖 Documentation
    ├── README.md                 # Ce fichier
    └── QUICK_START.md            # Guide rapide
```

### **Production** : `/var/www/html/home-fonta/`

```
/var/www/html/home-fonta/
├── server.py                     # ← Copié par deploy.sh
├── index.html                    # ← Copié par deploy.sh
├── style.css                     # ← Copié par deploy.sh
├── ...                           # Tous vos fichiers web
└── images/
```

**⚠️ Important :** Ne modifiez **JAMAIS** directement dans `/var/www/html/` !  
Toujours modifier dans `~/home-fonta/` puis déployer.

---

## 🔄 Workflow de développement {#workflow}

### **Cycle de travail quotidien**

```bash
# 1. Modifier vos fichiers HTML/CSS/JS
cd ~/home-fonta/
nano index.html        # ou votre éditeur préféré

# 2. (Optionnel) Tester localement
python3 server.py      # Lance le serveur sur http://localhost:8000

# 3. Commit (le déploiement se fait automatiquement)
git add .
git commit -m "Description des modifications"
git push

# ✨ Le script deploy.sh s'exécute automatiquement lors du commit !

# 4. Vérifier que tout fonctionne
# Ouvrir https://home-fonta.fr dans le navigateur
# Vider le cache si nécessaire (Ctrl+Shift+R)
```

**Note :** Le déploiement est automatisé via un hook Git qui exécute `deploy.sh` à chaque commit.

### **Ce que fait deploy.sh automatiquement**

1. ✅ **Sauvegarde** l'ancien site → `~/backups-www/`
2. ⏸️ **Arrête** le service Python
3. 🔄 **Copie** les nouveaux fichiers → `/var/www/html/home-fonta/`
4. 🔐 **Corrige** les permissions (www-data)
5. ▶️ **Redémarre** le service Python
6. 🔄 **Recharge** Nginx
7. 🧹 **Nettoie** les vieilles sauvegardes (garde les 5 dernières)

---

## 🛠️ Modifications futures {#modifications}

### **Ajouter une nouvelle page HTML**

```bash
cd ~/home-fonta/

# 1. Créer la page
nano nouvelle-page.html

# 2. Ajouter un lien dans menu.html
nano menu.html
# Ajouter : <a href="nouvelle-page.html">📄 Nouvelle Page</a>

# 3. Déployer
./deploy.sh
```

### **Modifier le CSS**

```bash
cd ~/home-fonta/
nano style.css

# Déployer
./deploy.sh
```

**⚠️ Cache navigateur** : Après modification CSS, pensez à vider le cache !
- `Ctrl + Shift + R` (rafraîchissement forcé)
- `Ctrl + Shift + Delete` (vider le cache)
- Navigation privée pour tester

### **Ajouter des images**

```bash
cd ~/home-fonta/images/

# Copier vos nouvelles images
cp ~/Photos/ma-photo.jpg .

# Déployer
./deploy.sh
```

Puis dans votre HTML :
```html
<img src="images/ma-photo.jpg" alt="Description">
```

### **Modifier le port Python**

Si vous voulez changer le port 8000 :

**1. Modifier server.py :**
```python
PORT = 8080  # Au lieu de 8000
```

**2. Modifier nginx :**
```bash
sudo nano /etc/nginx/sites-available/home-fonta.fr

# Changer :
proxy_pass http://127.0.0.1:8080;  # Au lieu de 8000
```

**3. Déployer et recharger :**
```bash
./deploy.sh
sudo systemctl reload nginx
```

---

## 💻 Commandes utiles {#commandes}

### **Gestion du service Python**

```bash
# Voir le statut
sudo systemctl status home-fonta

# Démarrer
sudo systemctl start home-fonta

# Arrêter
sudo systemctl stop home-fonta

# Redémarrer
sudo systemctl restart home-fonta

# Voir les logs en temps réel
sudo journalctl -u home-fonta -f

# Voir les derniers logs
sudo journalctl -u home-fonta -n 50

# Désactiver le démarrage automatique
sudo systemctl disable home-fonta

# Réactiver le démarrage automatique
sudo systemctl enable home-fonta
```

### **Gestion de Nginx**

```bash
# Statut
sudo systemctl status nginx

# Tester la configuration
sudo nginx -t

# Recharger (sans interruption)
sudo systemctl reload nginx

# Redémarrer
sudo systemctl restart nginx

# Voir la configuration active
sudo nginx -T

# Logs d'accès en temps réel
tail -f /var/log/nginx/home-fonta-access.log

# Logs d'erreur
tail -f /var/log/nginx/home-fonta-error.log
```

### **Vérifications système**

```bash
# Python écoute bien sur le port 8000 ?
sudo netstat -tlnp | grep 8000
# ou
sudo lsof -i :8000

# Voir tous les ports en écoute
sudo netstat -tlnp

# Tester directement Python
curl http://127.0.0.1:8000

# Tester via Nginx
curl http://localhost
curl https://home-fonta.fr
```

### **Gestion des sauvegardes**

```bash
# Voir les sauvegardes
ls -lh ~/backups-www/

# Restaurer une sauvegarde
cd /var/www/html/home-fonta/
sudo tar -xzf ~/backups-www/html-backup-YYYY-MM-DD_HH-MM-SS.tar.gz

# Supprimer les vieilles sauvegardes manuellement
rm ~/backups-www/html-backup-2025-01-*.tar.gz
```

---

## 🔧 Dépannage {#depannage}

### **Le site affiche "502 Bad Gateway"**

**Cause :** Python n'est pas démarré ou ne répond pas

**Solution :**
```bash
# Vérifier le statut
sudo systemctl status home-fonta

# Si inactif, démarrer
sudo systemctl start home-fonta

# Voir les erreurs
sudo journalctl -u home-fonta -n 50
```

### **Le site affiche "404 Not Found"**

**Cause :** Les fichiers ne sont pas dans `/var/www/html/home-fonta/`

**Solution :**
```bash
# Vérifier les fichiers
ls -la /var/www/html/home-fonta/

# Redéployer
cd ~/home-fonta/
./deploy.sh
```

### **"Port 8000 already in use"**

**Cause :** Un autre processus utilise le port

**Solution :**
```bash
# Trouver le processus
sudo lsof -i :8000

# Arrêter le service
sudo systemctl stop home-fonta

# Ou tuer le processus directement
sudo kill <PID>
```

### **Les modifications CSS/JS ne s'appliquent pas**

**Cause :** Cache du navigateur

**Solution :**
1. `Ctrl + Shift + R` (rafraîchissement forcé)
2. `Ctrl + Shift + Delete` → Vider le cache
3. Tester en navigation privée
4. Ouvrir les DevTools (F12) → Onglet Network → Cocher "Disable cache"

### **Le service ne démarre pas au boot**

**Solution :**
```bash
# Vérifier s'il est activé
sudo systemctl is-enabled home-fonta

# L'activer
sudo systemctl enable home-fonta
```

### **Erreur de permissions**

**Solution :**
```bash
# Corriger les permissions
sudo chown -R www-data:www-data /var/www/html/home-fonta/
sudo chmod -R 755 /var/www/html/home-fonta/
sudo chmod 755 /var/www/html/home-fonta/server.py
```

---

## 📊 Résumé des fichiers importants

| Fichier | Emplacement | Rôle |
|---------|-------------|------|
| **server.py** | `/var/www/html/home-fonta/` | Serveur web Python |
| **home-fonta.service** | `/etc/systemd/system/` | Configuration systemd |
| **home-fonta.fr** | `/etc/nginx/sites-available/` | Configuration Nginx |
| **deploy.sh** | `~/home-fonta/` | Script de déploiement |
| **Logs Python** | `journalctl -u home-fonta` | Logs du serveur |
| **Logs Nginx** | `/var/log/nginx/home-fonta-*.log` | Logs des accès |
| **Sauvegardes** | `~/backups-www/` | Archives .tar.gz |

---

## 🎯 Points clés à retenir

✅ **Toujours modifier dans** `~/home-fonta/`  
✅ **Toujours déployer avec** `./deploy.sh`  
✅ **Ne jamais modifier directement** `/var/www/html/`  
✅ **Vider le cache** après modifications CSS/JS  
✅ **Vérifier les logs** en cas de problème  

---

## 🚀 Prochaine étape : Docker

Une fois que vous êtes à l'aise avec ce setup, on peut le dockeriser pour :
- Faciliter les déploiements
- Isoler complètement l'environnement
- Simplifier la gestion des dépendances
- Rendre le tout portable

---

**Documentation créée le 22 octobre 2025**  
**Version : 1.0 - Setup Python + Nginx**
