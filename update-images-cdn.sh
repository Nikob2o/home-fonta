#!/bin/bash

echo "=== REMPLACEMENT url_for → CDN ==="

for file in templates/*.html; do
  if [ -f "$file" ]; then
    echo "Modification de $file..."
    
    # Remplacer les url_for pour images par le CDN
    sed -i "s|{{ url_for('static', filename='images/\([^']*\)') }}|https://cdn.home-fonta.fr/images/\1|g" "$file"
    
    # Compter les remplacements
    count=$(grep -c "cdn.home-fonta.fr" "$file" 2>/dev/null || echo 0)
    echo "  → $count références CDN"
  fi
done

echo ""
echo "✅ Terminé"
echo ""
echo "=== VÉRIFICATION ==="
grep -n "cdn.home-fonta.fr" templates/*.html | head -5
