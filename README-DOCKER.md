# 🐳 Home-Fonta.fr - Migration vers Docker

## 📋 Table des matières

1. [Pourquoi Docker ?](#pourquoi)
2. [Architecture](#architecture)
3. [Installation (zéro downtime)](#installation)
4. [Nouveaux fichiers](#fichiers)
5. [Migration étape par étape](#migration)
6. [Gestion quotidienne](#gestion)
7. [Retour arrière](#rollback)
8. [Commandes Docker](#commandes)

---

## 🎯 Pourquoi Docker ? {#pourquoi}

### **Avantages**

✅ **Isolation complète** - Le serveur tourne dans son propre environnement  
✅ **Portable** - Fonctionne partout (dev, prod, autre serveur)  
✅ **Facile à déployer** - Un simple `docker-compose up`  
✅ **Rollback instantané** - Retour à la version précédente en 1 commande  
✅ **Pas de conflit** - Pas de problème de dépendances système  
✅ **Logs centralisés** - `docker-compose logs`  
✅ **Redémarrage automatique** - En cas de crash  

### **Inconvénients**

⚠️ Légèrement plus de RAM utilisée  
⚠️ Nécessite d'apprendre quelques commandes Docker

---

## 🏗️ Architecture {#architecture}

### **Avant (systemd)**

```
Internet → Nginx → Python (systemd, port 8000) → Fichiers
```

### **Après (Docker)**

```
Internet → Nginx → Docker (port 8001) → Python → Fichiers
```

**Changement :** Python tourne dans un container Docker au lieu d'un service systemd.

---

## 🚀 Installation (zéro downtime) {#installation}

### **Phase 1 : Setup Docker en parallèle** ⏱️ 5 min

Les deux serveurs tourneront **en même temps** :
- Systemd sur le port 8000 (production actuelle)
- Docker sur le port 8001 (test)

```bash
cd ~/home-fonta/

# Créer les nouveaux fichiers (voir section suivante)
# ...

# Rendre les scripts exécutables
chmod +x setup-docker.sh switch-to-docker.sh rollback-to-systemd.sh

# Installer et lancer Docker
./setup-docker.sh
```

**Résultat :**
- ✅ Site actuel toujours en ligne (port 8000)
- ✅ Docker tourne en parallèle (port 8001)
- ✅ Vous pouvez tester tranquillement

### **Phase 2 : Tests** ⏱️ 10 min

```bash
# Test direct Docker
curl http://127.0.0.1:8001

# Test dans le navigateur (local)
http://localhost:8001

# Voir les logs Docker
docker-compose logs -f

# Vérifier que tout fonctionne (CSS, JS, images)
```

**Testez bien tout avant de passer à la suite !**

### **Phase 3 : Bascule vers Docker** ⏱️ 2 min

Quand vous êtes sûr que Docker fonctionne :

```bash
# Bascule Nginx vers Docker (instantané, zéro downtime)
./switch-to-docker.sh
```

**Ce qui se passe :**
1. ✅ Sauvegarde config Nginx
2. ✅ Nginx pointe vers Docker (port 8001)
3. ✅ Rechargement Nginx (sans interruption)
4. ✅ Arrêt du service systemd
5. ✅ Site maintenant servi par Docker

**Votre site n'a jamais cessé de fonctionner ! 🎉**

---

## 📁 Nouveaux fichiers {#fichiers}

Créez ces fichiers dans `~/home-fonta/` :

### **1. Dockerfile**

```dockerfile
FROM python:3.11-slim

LABEL maintainer="home-fonta.fr"
LABEL description="Serveur web Python pour Home-Fonta.fr"

ENV PYTHONUNBUFFERED=1
ENV PORT=8000

RUN useradd -m -u 1000 webuser

WORKDIR /app

COPY --chown=webuser:webuser . /app/

EXPOSE 8000

USER webuser

CMD ["python3", "server.py"]
```

### **2. docker-compose.yml**

```yaml
version: '3.8'

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: home-fonta-web
    restart: unless-stopped
    ports:
      - "127.0.0.1:8001:8000"  # Port 8001 pour test en parallèle
    volumes:
      - ./:/app:ro
    environment:
      - PORT=8000
    networks:
      - home-fonta-network
    healthcheck:
      test: ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  home-fonta-network:
    driver: bridge
```

### **3. .dockerignore**

```
.git
.gitignore
deploy.sh
install-service.sh
install-nginx.sh
README.md
QUICK_START.md
README-DOCKER.md
home-fonta.service
nginx-home-fonta.conf
*.backup
__pycache__/
*.py[cod]
*.log
```

### **4. server.py (version Docker)**

Remplacez votre `server.py` actuel par la version Docker (voir artifact).

**Important :** Le script `setup-docker.sh` sauvegarde automatiquement l'ancien fichier dans `server.py.systemd-backup`.

### **5. Scripts**

- `setup-docker.sh` - Installation Docker
- `switch-to-docker.sh` - Bascule vers Docker
- `rollback-to-systemd.sh` - Retour arrière

---

## 📖 Migration étape par étape {#migration}

### **Étape 1 : Préparation** ✅

```bash
cd ~/home-fonta/

# Créer les 8 nouveaux fichiers listés ci-dessus
# (Dockerfile, docker-compose.yml, .dockerignore, server.py Docker, 3 scripts)

# Vérifier
ls -la
```

### **Étape 2 : Installation Docker** ✅

```bash
chmod +x setup-docker.sh switch-to-docker.sh rollback-to-systemd.sh
./setup-docker.sh

# Si Docker n'était pas installé, le script l'installe
# Puis déconnectez-vous / reconnectez-vous
# Et relancez ./setup-docker.sh
```

### **Étape 3 : Vérification** ✅

```bash
# Les 2 serveurs doivent tourner en parallèle
sudo systemctl status home-fonta       # systemd (port 8000)
docker ps                               # Docker (port 8001)

# Test systemd (site actuel)
curl http://127.0.0.1:8000

# Test Docker
curl http://127.0.0.1:8001

# Les deux doivent retourner votre HTML !
```

### **Étape 4 : Tests approfondis** ✅

```bash
# Logs Docker en temps réel
docker-compose logs -f

# Dans un autre terminal, testez votre site
# Ouvrez http://localhost:8001 dans un navigateur
# Vérifiez : pages, CSS, JS, images, menu, galerie

# Rechargez plusieurs fois
# Testez toutes les pages
```

### **Étape 5 : Bascule (quand prêt)** ✅

```bash
# Bascule Nginx vers Docker
./switch-to-docker.sh

# Vérifier votre site (production)
https://home-fonta.fr
```

**C'est fait ! Votre site tourne maintenant sur Docker ! 🎉**

---

## 🔄 Gestion quotidienne {#gestion}

### **Modifier le site**

**Rien ne change !** Le workflow reste identique :

```bash
cd ~/home-fonta/

# Modifier vos fichiers
nano index.html

# Commit (déploiement automatique via hook Git)
git add .
git commit -m "Modifications"
git push

# Redémarrer Docker pour appliquer
docker-compose restart
```

### **Voir les logs**

```bash
# Logs en temps réel
docker-compose logs -f

# Dernières lignes
docker-compose logs --tail=50

# Logs d'un service spécifique
docker-compose logs web
```

### **Redémarrer**

```bash
# Redémarrage rapide
docker-compose restart

# Reconstruction complète (après modification Dockerfile)
docker-compose down
docker-compose build
docker-
