#!/bin/bash

# Fonction pour créer le header commun
create_header() {
    local page_title=$1
    local body_class=$2
    
    cat << EOF
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${page_title} - Home-Fonta.fr</title>
  <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
  <link rel="icon" href="{{ url_for('static', filename='images/ours.jpg') }}" type="image/png">
</head>
<body class="${body_class}">
  <!-- Emplacement du menu -->
  <div id="menu-placeholder"></div>
  
EOF
}

# Fonction pour créer le footer + scripts
create_footer() {
    cat << 'EOF'
  
  <footer>
    Hébergé en France — © 2025 Home-Fonta.fr
  </footer>
  
  <!-- Chargement du menu -->
  <script>
    document.addEventListener("DOMContentLoaded", () => {
      fetch("/menu")
        .then(res => {
          if (!res.ok) throw new Error("Erreur HTTP " + res.status);
          return res.text();
        })
        .then(html => {
          const placeholder = document.getElementById("menu-placeholder");
          if (placeholder) placeholder.innerHTML = html;
          
          const toggleButton = document.createElement("button");
          toggleButton.classList.add("menu-toggle");
          toggleButton.textContent = "☰";
          document.body.appendChild(toggleButton);
          
          const overlay = document.createElement("div");
          overlay.classList.add("overlay");
          document.body.appendChild(overlay);
          
          setTimeout(() => {
            const sidebar = document.querySelector(".sidebar");
            if (!sidebar) return;
            
            const toggleMenu = () => {
              sidebar.classList.toggle("show");
              overlay.classList.toggle("show");
            };
            
            toggleButton.addEventListener("click", toggleMenu);
            overlay.addEventListener("click", toggleMenu);
          }, 100);
        })
        .catch(err => console.error("Erreur menu:", err));
    });
  </script>
  
  <script src="{{ url_for('static', filename='script.js') }}"></script>
</body>
</html>
EOF
}

# Extraire juste le contenu <main> de chaque page existante
cd templates/

# Présentation
PRESENTATION_CONTENT=$(sed -n '/<main/,/<\/main>/p' presentation.html)
create_header "Présentation" "presentation" > presentation_new.html
echo "$PRESENTATION_CONTENT" >> presentation_new.html
create_footer >> presentation_new.html
mv presentation_new.html presentation.html

# Services
SERVICES_CONTENT=$(sed -n '/<main/,/<\/main>/p' services.html)
create_header "Services" "services" > services_new.html
echo "$SERVICES_CONTENT" >> services_new.html
create_footer >> services_new.html
mv services_new.html services.html

echo "✅ Templates mis à jour"
