# Guide de Troubleshooting - Migration K3s home-fonta.fr

## 📋 Table des matières

1. [Problèmes de build Docker](#1-problèmes-de-build-docker)
2. [Problèmes de templates Jinja2](#2-problèmes-de-templates-jinja2)
3. [Problèmes de fichiers statiques (504/404)](#3-problèmes-de-fichiers-statiques-504404)
4. [Problèmes de déploiement Kubernetes](#4-problèmes-de-déploiement-kubernetes)
5. [Problèmes de réseau CNI](#5-problèmes-de-réseau-cni)
6. [Problèmes de certificats SSL](#6-problèmes-de-certificats-ssl)
7. [Commandes de diagnostic utiles](#7-commandes-de-diagnostic-utiles)

---

## 1. Problèmes de build Docker

### 1.1 Buildx ne fonctionne pas sur PC (cross-compilation ARM64)

**Symptôme** :
```bash
docker buildx build --platform linux/arm64 ...
# Erreur ou build très lent/échoue
```

**Cause** : QEMU pas installé ou mal configuré pour l'émulation ARM64.

**Solutions** :

**Option A** : Configurer QEMU sur le PC
```bash
# Installer QEMU
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Créer un builder buildx
docker buildx create --name mybuilder --use
docker buildx inspect --bootstrap
```

**Option B** : Build directement sur le Raspberry Pi (ARM natif)
```bash
# Créer l'archive sur le PC
tar -czf /tmp/home-fonta.tar.gz templates/ static/ nginx/ app.py Dockerfile requirements.txt

# Envoyer sur le RPi
scp /tmp/home-fonta.tar.gz pi@192.168.1.51:~/

# Build sur le RPi
ssh pi@192.168.1.51 << 'ENDSSH'
cd ~/builds/home-fonta
tar -xzf ~/home-fonta.tar.gz
sudo docker build -t nocoblas/home-fonta-web:v3.1 .
sudo docker push nocoblas/home-fonta-web:v3.1
ENDSSH
```

---

## 2. Problèmes de templates Jinja2

### 2.1 Liens CDN au lieu de /static/

**Symptôme** :
```
GET https://cdn.home-fonta.fr/images/style.css 404
```

**Cause** : Les templates HTML contenaient des liens directs vers le CDN au lieu d'utiliser `url_for()`.

**Solution** :

Remplacer :
```html
<link rel="stylesheet" href="https://cdn.home-fonta.fr/images/style.css">
```

Par :
```html
<link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
```

**Script de correction automatique** :
```bash
#!/bin/bash
# fix_all_templates.sh

for file in templates/*.html; do
    # Remplacer les URLs CDN par url_for
    sed -i "s|https://cdn.home-fonta.fr/images/\([^\"']*\)|{{ url_for('static', filename='\1') }}|g" "$file"
done
```

### 2.2 Syntaxe Jinja2 cassée (double fermeture)

**Symptôme** :
```
GET https://home-fonta.fr/static/images/aigle.jpg') }} 404
```

L'URL contient `') }}` à la fin.

**Cause** : Erreur lors de la correction des templates, double syntaxe Jinja2 :
```html
<!-- CASSÉ -->
<img src="{{ url_for('static', filename='images/aigle.jpg') }}') }}">
```

**Solution** :
```html
<!-- CORRECT -->
<img src="{{ url_for('static', filename='images/aigle.jpg') }}">
```

**Commande de correction** :
```bash
# Supprimer les ') }} en trop
sed -i "s/') }}\"/\"/g" templates/*.html
```

---

## 3. Problèmes de fichiers statiques (504/404)

### 3.1 Timeout 504 sur les fichiers statiques

**Symptôme** :
```
GET https://home-fonta.fr/static/style.css [HTTP/2 504 15313ms]
GET https://home-fonta.fr/static/script.js [HTTP/2 504 15313ms]
```

**Cause** : Flask servait les fichiers statiques, ce qui est trop lent en production.

**Solution temporaire** (patch Flask) :
```python
from flask import send_from_directory

@app.route('/static/<path:filename>')
def static_files(filename):
    return send_from_directory('static', filename)
```

**Solution définitive** : Architecture NGINX + Flask (voir section Architecture dans MIGRATION-K3S-FLASK.md)

### 3.2 404 sur les fichiers statiques après migration NGINX

**Symptôme** :
```
curl https://home-fonta.fr/static/style.css
# 404 Not Found
```

**Diagnostic** :
```bash
# Vérifier que les fichiers existent dans le container
kubectl exec -n home-fonta $(kubectl get pods -n home-fonta -o name | head -1) -- ls -la /app/static/

# Vérifier la config NGINX
kubectl exec -n home-fonta $(kubectl get pods -n home-fonta -o name | head -1) -- cat /etc/nginx/sites-enabled/default
```

**Causes possibles** :

1. **Chemin incorrect dans nginx** : `alias` au lieu de `root`
```nginx
# CORRECT
location /static/ {
    alias /app/static/;  # Avec trailing slash !
}
```

2. **Fichiers non copiés dans l'image Docker** : Vérifier le Dockerfile
```dockerfile
COPY static/ /app/static/
```

---

## 4. Problèmes de déploiement Kubernetes

### 4.1 Pods en CrashLoopBackOff

**Symptôme** :
```bash
kubectl get pods -n home-fonta
NAME                              READY   STATUS             RESTARTS   AGE
home-fonta-web-59c5486fb5-nl22t   0/1     CrashLoopBackOff   19         55m
```

**Diagnostic** :
```bash
# Logs du pod
kubectl logs -n home-fonta $(kubectl get pods -n home-fonta -o name | head -1) --tail=50

# Logs du crash précédent
kubectl logs -n home-fonta $(kubectl get pods -n home-fonta -o name | head -1) --previous

# Describe du pod
kubectl describe pod -n home-fonta $(kubectl get pods -n home-fonta -o name | head -1)
```

**Cause dans notre cas** : Les health probes pointaient vers le port 8000 alors que NGINX écoute sur le port 80.

**Solution** : Modifier `values.yaml` :
```yaml
# AVANT (cassé)
livenessProbe:
  httpGet:
    port: 8000

# APRÈS (correct)
livenessProbe:
  httpGet:
    port: 80
```

Puis redéployer :
```bash
helm upgrade home-fonta . -n home-fonta
kubectl rollout restart deployment home-fonta-web -n home-fonta
```

### 4.2 Deployment exceeded progress deadline

**Symptôme** :
```bash
kubectl rollout status deployment home-fonta-web -n home-fonta
error: deployment "home-fonta-web" exceeded its progress deadline
```

**Cause** : Les nouveaux pods n'arrivent pas à passer les health checks.

**Diagnostic** :
```bash
# Voir les événements
kubectl describe deployment home-fonta-web -n home-fonta

# Voir l'état des pods
kubectl get pods -n home-fonta -o wide

# Vérifier les probes
kubectl get deployment home-fonta-web -n home-fonta -o yaml | grep -A15 "livenessProbe\|readinessProbe"
```

### 4.3 Service targetPort incorrect

**Symptôme** : Le site charge lentement ou pas du tout malgré les pods Running.

**Diagnostic** :
```bash
kubectl get service home-fonta-web -n home-fonta -o yaml | grep -A10 "ports:"
```

**Cause** : Le service pointe vers `targetPort: 8000` mais le container écoute sur `80`.

**Solution** :
```yaml
# values.yaml
service:
  port: 80
  targetPort: 80  # Doit correspondre au port du container (NGINX)
```

---

## 5. Problèmes de réseau CNI

### 5.1 Timeout entre pods sur différents nodes

**Symptôme** :
```
upstream timed out (110: Operation timed out) while connecting to upstream
10.42.4.63:80, 10.42.1.41:80, 10.42.3.102:80
5.000, 5.001, 0.002  ← 2 timeout, 1 OK
504, 504, 200
```

**Diagnostic** :
```bash
# Où est l'Ingress Controller ?
kubectl get pods -n ingress-nginx -o wide

# Où sont les pods de l'application ?
kubectl get pods -n home-fonta -o wide

# Vérifier la connectivité physique
ssh pi@192.168.1.51 "ping -c 3 192.168.1.36"

# Vérifier le CNI (Flannel)
kubectl get pods -n kube-system | grep flannel
```

**Cause** : Le réseau Pod (overlay CNI) ne fonctionne pas correctement entre les nodes, même si le réseau physique est OK.

**Solution temporaire** : Forcer tous les pods sur le même node que l'Ingress Controller :
```bash
kubectl patch deployment home-fonta-web -n home-fonta --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"kubernetes.io/hostname": "rpi4-master"}}
]'
```

**Solution permanente** : Investiguer le problème CNI :
```bash
# Vérifier les pods Flannel
kubectl logs -n kube-system -l app=flannel

# Redémarrer K3s sur tous les nodes si nécessaire
ssh pi@192.168.1.51 "sudo systemctl restart k3s"
ssh pi@192.168.1.50 "sudo systemctl restart k3s-agent"
ssh pi@192.168.1.36 "sudo systemctl restart k3s-agent"
ssh pi@192.168.1.15 "sudo systemctl restart k3s-agent"
```

### 5.2 Ingress sans ADDRESS

**Symptôme** :
```bash
kubectl get ingress -n home-fonta
NAME             CLASS   HOSTS           ADDRESS   PORTS
home-fonta-web   nginx   home-fonta.fr             80, 443
#                                        ^^^^^^^^^ VIDE !
```

**Cause** : L'Ingress Controller n'arrive pas à déterminer les IPs externes.

**Diagnostic** :
```bash
# Logs de l'Ingress Controller
kubectl logs -n ingress-nginx $(kubectl get pods -n ingress-nginx -o name | head -1) --tail=50
```

**Solution** : Vérifier la configuration du LoadBalancer K3s :
```bash
# Supprimer une annotation IP forcée si présente
kubectl annotate service ingress-nginx-controller -n ingress-nginx lb.k3s.cattle.io/ip-

# Redémarrer le controller
kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
```

---

## 6. Problèmes de certificats SSL

### 6.1 Certificat non valide / non généré

**Symptôme** :
```bash
curl https://home-fonta.fr
# SSL certificate problem
```

**Diagnostic** :
```bash
# État du certificat
kubectl get certificate -n home-fonta

# Détails
kubectl describe certificate wildcard-homefonta-tls -n home-fonta

# État du ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod-dns
```

**Causes et solutions** :

1. **Challenge DNS en attente** :
```bash
kubectl get challenges -A
kubectl describe challenge <challenge-name> -n home-fonta
```

2. **Token Cloudflare invalide** :
```bash
kubectl get secret cloudflare-api-token -n cert-manager -o yaml
```

3. **Forcer le renouvellement** :
```bash
kubectl delete certificate wildcard-homefonta-tls -n home-fonta
# cert-manager va recréer automatiquement
```

---

## 7. Commandes de diagnostic utiles

### État général du cluster

```bash
# Nodes
kubectl get nodes -o wide

# Tous les pods
kubectl get pods -A

# Événements récents
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Application home-fonta

```bash
# État complet
kubectl get all,ingress,certificate -n home-fonta

# Logs de tous les pods
kubectl logs -n home-fonta -l app=homefonta --tail=50

# Logs NGINX dans le container
kubectl exec -n home-fonta $(kubectl get pods -n home-fonta -o name | head -1) -- tail -20 /var/log/nginx/access.log
kubectl exec -n home-fonta $(kubectl get pods -n home-fonta -o name | head -1) -- tail -20 /var/log/nginx/error.log
```

### Ingress Controller

```bash
# État
kubectl get all -n ingress-nginx

# Logs
kubectl logs -n ingress-nginx $(kubectl get pods -n ingress-nginx -o name | head -1) --tail=100

# Config NGINX générée
kubectl exec -n ingress-nginx $(kubectl get pods -n ingress-nginx -o name | head -1) -- cat /etc/nginx/nginx.conf
```

### Tests de connectivité

```bash
# Test direct du service
kubectl port-forward -n home-fonta service/home-fonta-web 8080:80 &
curl -I http://localhost:8080
pkill -f "port-forward"

# Test depuis Internet
time curl -I https://home-fonta.fr
time curl -I https://home-fonta.fr/static/style.css
time curl -I https://home-fonta.fr/static/images/aigle.jpg

# Test avec verbose
curl -vvv https://home-fonta.fr 2>&1 | head -50
```

### Helm

```bash
# Liste des releases
helm list -A

# Historique
helm history home-fonta -n home-fonta

# Valeurs actuelles
helm get values home-fonta -n home-fonta

# Rollback
helm rollback home-fonta <REVISION> -n home-fonta
```

---

## 📊 Tableau récapitulatif des erreurs

| Erreur | Symptôme | Cause | Solution |
|--------|----------|-------|----------|
| 504 Gateway Timeout | Fichiers statiques timeout | Flask trop lent | Architecture NGINX |
| 404 Not Found | Images/CSS/JS introuvables | Chemin incorrect | Corriger url_for() |
| CrashLoopBackOff | Pods redémarrent en boucle | Health probes mauvais port | Corriger port: 80 |
| Upstream timeout | 2/3 pods injoignables | Problème CNI inter-nodes | nodeSelector sur master |
| Ingress sans ADDRESS | Pas d'IP dans l'ingress | LoadBalancer mal configuré | Vérifier annotations |
| Syntaxe ') }} | URLs cassées | Double Jinja2 | sed correction |

---

## 🔄 Workflow de débogage recommandé

```
1. Vérifier les pods
   kubectl get pods -n home-fonta -o wide
   
2. Si CrashLoopBackOff → Voir les logs
   kubectl logs -n home-fonta <pod> --previous
   
3. Si Running mais erreurs → Vérifier les services
   kubectl get svc,ingress -n home-fonta
   
4. Si service OK → Tester la connectivité
   kubectl port-forward service/home-fonta-web 8080:80
   curl http://localhost:8080
   
5. Si port-forward OK mais site KO → Problème Ingress/réseau
   kubectl logs -n ingress-nginx <ingress-pod>
   
6. Si timeout inter-nodes → nodeSelector
   kubectl patch deployment ... --type='json' nodeSelector
```

---

*Documentation générée le 23 novembre 2025*
