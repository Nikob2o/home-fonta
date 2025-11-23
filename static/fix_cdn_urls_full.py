#!/usr/bin/env python3
import os
import re
import shutil

# ---------------- CONFIGURATION ----------------
PROJECT_DIR = "."               # Racine du projet
TEMPLATES_DIR = "templates"     # Dossier templates
STATIC_DIR = "static"           # Dossier static
CDN_DOMAIN = "cdn.home-fonta.fr"
BACKUP_SUFFIX = ".backup"
EXTENSIONS = [".html", ".js", ".css"]  # Extensions à scanner

# Regex pour détecter URLs CDN (http ou https)
cdn_regex = re.compile(rf"https?://{re.escape(CDN_DOMAIN)}/(?P<path>[\w./-]+)")

# Fonction pour générer url_for statique pour HTML
def cdn_to_url_for(match, ext):
    path = match.group("path")
    if ext == ".html":
        return "{{ url_for('static', filename='" + path + "') }}"
    else:
        # Pour JS ou CSS, on met juste chemin relatif à static/
        return f"/static/{path}"

# ---------------- SCAN ET REPLACEMENT ----------------
total_replacements = 0
modified_files = []

for root, dirs, files in os.walk(PROJECT_DIR):
    for file in files:
        ext = os.path.splitext(file)[1].lower()
        if ext not in EXTENSIONS:
            continue

        file_path = os.path.join(root, file)
        backup_path = file_path + BACKUP_SUFFIX

        # Backup
        shutil.copyfile(file_path, backup_path)

        # Lecture du fichier
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Remplacement
        new_content, count = cdn_regex.subn(lambda m: cdn_to_url_for(m, ext), content)

        if count > 0:
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(new_content)
            total_replacements += count
            modified_files.append((file_path, count))
            print(f"[MODIFIED] {file_path}: {count} URLs remplacées")

# ---------------- RAPPORT ----------------
print("\n✅ Script terminé.")
print(f"Fichiers modifiés: {len(modified_files)}")
print(f"Nombre total de URLs remplacées: {total_replacements}")
print(f"Backups créés avec suffixe {BACKUP_SUFFIX}")

