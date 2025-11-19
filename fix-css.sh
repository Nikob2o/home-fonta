#!/bin/bash

# Récupérer le CSS de prod (qui fonctionne)
echo "Récupération du CSS de prod..."
kubectl exec -n home-fonta deployment/home-fonta-web -- cat /app/style.css > static/style.css

# Vérifier
echo "CSS récupéré. Vérification..."
grep "sidebar.show" static/style.css

echo "✅ CSS restauré depuis la prod"
