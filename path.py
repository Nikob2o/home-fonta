#!/usr/bin/env python3
"""
Script pour corriger automatiquement les chemins dans les fichiers HTML
Adapte les chemins absolus en chemins relatifs pour le serveur Python
"""

import os
import re

def fix_html_file(filepath):
    """Corrige les chemins dans un fichier HTML"""
    
    if not os.path.exists(filepath):
        print(f"⚠️  Fichier introuvable : {filepath}")
        return False
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # Corrections à effectuer
    fixes = [
        # CSS et JS dans les <head> et <script>
        (r'href="style\.css"', 'href="./style.css"'),
        (r'src="script\.js"', 'src="./script.js"'),
        
        # Fetch avec chemins absolus
        (r'fetch\("/menu\.html', 'fetch("./menu.html'),
        (r'fetch\(\'/menu\.html', 'fetch(\'./menu.html'),
        
        # Origin + path dans galerie.html
        (r'window\.location\.origin \+ "/menu\.html', 'window.location.origin + "/menu.html'),
    ]
    
    changes_made = []
    
    for pattern, replacement in fixes:
        if re.search(pattern, content):
            content = re.sub(pattern, replacement, content)
            changes_made.append(pattern)
    
    # Sauvegarde si des changements ont été faits
    if content != original_content:
        # Créer une sauvegarde
        backup_path = f"{filepath}.backup"
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(original_content)
        
        # Écrire le nouveau contenu
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"✅ {filepath} modifié ({len(changes_made)} changement(s))")
        print(f"   💾 Sauvegarde créée : {backup_path}")
        return True
    else:
        print(f"ℹ️  {filepath} - aucun changement nécessaire")
        return False

def main():
    """Fonction principale"""
    print("\n" + "="*60)
    print("🔧 Correction automatique des chemins HTML")
    print("="*60 + "\n")
    
    # Liste des fichiers à corriger
    files_to_fix = [
        'index.html',
        'presentation.html',
        'services.html',
        'galerie.html'
    ]
    
    fixed_count = 0
    
    for filepath in files_to_fix:
        if fix_html_file(filepath):
            fixed_count += 1
    
    print("\n" + "="*60)
    if fixed_count > 0:
        print(f"✨ Correction terminée : {fixed_count} fichier(s) modifié(s)")
        print("\n💡 Les fichiers originaux sont sauvegardés en .backup")
        print("💡 Vous pouvez maintenant lancer : python server.py")
    else:
        print("✅ Tous les fichiers sont déjà corrects !")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
