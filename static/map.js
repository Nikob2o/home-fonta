// =============================================================================
// Globe 3D — Carte des connexions vers home-fonta.fr
//
// Utilise Globe.gl (basé sur three.js) pour afficher un globe terrestre
// avec des arcs animés représentant les connexions entrantes.
// Les données viennent de Loki via l'API /api/map-data.
// =============================================================================

document.addEventListener("DOMContentLoaded", () => {
  // ---- Configuration ----

  // Période par défaut pour la requête Loki (modifiable via les boutons)
  let currentRange = "1h";

  // Intervalle de rafraîchissement automatique (10 secondes)
  const REFRESH_INTERVAL = 10000;

  // Nombre max d'entrées dans le feed "dernières connexions"
  const MAX_FEED_ITEMS = 8;

  // Couleurs des arcs (dégradé du point source vers la destination)
  const ARC_COLOR_START = "rgba(0, 255, 255, 0.9)";   // Cyan vif (source)
  const ARC_COLOR_END = "rgba(255, 100, 50, 0.6)";    // Orange (destination)

  // Couleur des points lumineux aux origines
  const POINT_COLOR = "rgba(0, 255, 255, 0.8)";

  // Mode d'affichage actuel ("3d" ou "2d")
  let currentView = "3d";

  // ---- Initialisation du globe ----

  // Globe.gl crée un globe WebGL dans le conteneur HTML.
  // On configure :
  //   - globeImageUrl : la texture de la Terre (image Blue Marble NASA)
  //   - bumpImageUrl : relief en 3D (optionnel, donne du réalisme)
  //   - backgroundImageUrl : fond étoilé
  //   - atmosphereColor / atmosphereAltitude : le halo bleuté autour du globe
  //   - pointOfView : position initiale de la caméra (centrée sur l'Europe)
  const globe = Globe()
    .globeImageUrl("//unpkg.com/three-globe/example/img/earth-night.jpg")
    .bumpImageUrl("//unpkg.com/three-globe/example/img/earth-topology.png")
    .backgroundImageUrl("//unpkg.com/three-globe/example/img/night-sky.png")
    .atmosphereColor("rgba(100, 180, 255, 0.4)")
    .atmosphereAltitude(0.2)
    .showGraticules(true)
    // --- Arcs (les lignes courbes entre source et destination) ---
    // Chaque arc a : startLat, startLng, endLat, endLng (coordonnées GPS)
    // La "stroke" (épaisseur) dépend du nombre de hits (plus de hits = plus épais)
    // Le dashLength + dashGap crée l'effet de pointillés animés
    // dashAnimateTime contrôle la vitesse de l'animation (ms pour traverser le globe)
    .arcColor(d => [ARC_COLOR_START, ARC_COLOR_END])
    .arcStroke(d => Math.min(0.5 + Math.log2(d.count + 1) * 0.3, 3))
    .arcDashLength(0.6)
    .arcDashGap(0.3)
    .arcDashAnimateTime(2000)
    .arcAltitudeAutoScale(0.4)
    .arcsTransitionDuration(500)
    // --- Points lumineux aux origines ---
    // Le rayon dépend du nombre de hits (échelle logarithmique)
    // ET du niveau de zoom (altitude caméra) : plus on zoome, plus les points
    // se réduisent, comme les marqueurs Grafana Geomap.
    // altitude ~2.2 = vue globale, ~0.5 = zoom continent, ~0.1 = zoom ville
    .pointColor(() => POINT_COLOR)
    .pointAltitude(0.005)
    .pointRadius(d => {
      const alt = globe.pointOfView().altitude;
      const zoomFactor = Math.min(alt / 2.2, 1);
      return Math.min(0.15 + Math.log2(d.count + 1) * 0.08, 0.8) * (0.3 + zoomFactor * 0.7);
    })
    .pointsMerge(false)
    .pointsTransitionDuration(500)
    // --- Labels au survol ---
    .arcLabel(d => {
      const city = d.city ? ` (${d.city})` : "";
      return `<div class="arc-tooltip">${d.country}${city}<br/>${d.count} requete(s)</div>`;
    })
    (document.getElementById("globe-container"));

  // Position initiale de la caméra : vue sur l'Europe (là où est le serveur)
  globe.pointOfView({ lat: 30, lng: 10, altitude: 2.2 });

  // Rotation automatique lente du globe (en degrés par seconde)
  globe.controls().autoRotate = false;
  globe.controls().autoRotateSpeed = 0.5;

  // ---- Recalcul des points au zoom ----
  // Quand l'utilisateur zoome/dézoome (molette souris, pinch, etc.),
  // on force Globe.gl à recalculer le rayon des points.
  // Sans ça, pointRadius() n'est appelé qu'au chargement des données.
  globe.controls().addEventListener("change", () => {
    const pts = globe.pointsData();
    if (pts && pts.length > 0) {
      globe.pointsData(pts);
    }
  });

  // ---- Chargement des données ----

  // Cette fonction appelle notre API Flask qui interroge Loki,
  // puis met à jour le globe (arcs + points) et le panneau de stats.
  function fetchData() {
    fetch(`/api/map-data?range=${currentRange}`)
      .then(res => res.json())
      .then(data => {
        const server = data.server || { lat: 43.6, lon: 1.44 };

        // Construire les arcs : chaque entrée = une ligne courbe
        // de la source (lat/lon de l'IP) vers le serveur (Toulouse)
        const arcsData = data.arcs.map(a => ({
          startLat: a.lat,
          startLng: a.lon,
          endLat: server.lat,
          endLng: server.lon,
          country: a.country,
          city: a.city,
          count: a.count
        }));

        // Construire les points lumineux (un par localisation source)
        const pointsData = data.arcs.map(a => ({
          lat: a.lat,
          lng: a.lon,
          count: a.count
        }));

        // Mettre à jour la vue active (globe 3D ou carte 2D)
        if (currentView === "3d") {
          globe.arcsData(arcsData);
          globe.pointsData(pointsData);
        } else {
          updateLeafletMap(data);
        }

        // Mettre à jour les statistiques dans le panneau
        updateStats(data);
        updateFeed(data.arcs);
      })
      .catch(err => {
        console.error("Erreur chargement données carte:", err);
      });
  }

  // ---- Mise à jour du panneau de stats ----

  function updateStats(data) {
    // Compteurs principaux
    document.getElementById("total-ips").textContent =
      data.total_ips.toLocaleString("fr-FR");
    document.getElementById("total-hits").textContent =
      data.total_hits.toLocaleString("fr-FR");

    // Top pays : on vide la liste et on la reconstruit
    const topList = document.getElementById("top-countries");
    if (data.top_countries.length === 0) {
      topList.innerHTML = "<li>Aucune donnee</li>";
    } else {
      topList.innerHTML = data.top_countries
        .map(c => `<li><span class="country-name">${c.country}</span> <span class="country-hits">${c.hits.toLocaleString("fr-FR")}</span></li>`)
        .join("");
    }
  }

  // ---- Feed des dernières connexions ----
  // On affiche les N sources les plus récentes (triées par count décroissant
  // ici, car Loki agrège sur la période — on prend les plus actives)

  function updateFeed(arcs) {
    const feed = document.getElementById("recent-feed");
    if (!arcs || arcs.length === 0) {
      feed.innerHTML = "<li>Aucune connexion</li>";
      return;
    }

    // Trier par count décroissant et prendre les N premiers
    const sorted = [...arcs].sort((a, b) => b.count - a.count).slice(0, MAX_FEED_ITEMS);

    feed.innerHTML = sorted
      .map(a => {
        const city = a.city ? a.city + ", " : "";
        return `<li><span class="feed-location">${city}${a.country}</span> <span class="feed-count">${a.count}</span></li>`;
      })
      .join("");
  }

  // ---- Sélecteur de période ----
  // Quand on clique sur un bouton (5m, 1h, 24h...), on change la période
  // et on relance immédiatement une requête vers l'API.

  document.querySelectorAll(".time-selector button").forEach(btn => {
    btn.addEventListener("click", () => {
      // Retirer la classe "active" de tous les boutons
      document.querySelectorAll(".time-selector button")
        .forEach(b => b.classList.remove("active"));
      // Ajouter "active" au bouton cliqué
      btn.classList.add("active");
      // Changer la période et rafraîchir
      currentRange = btn.dataset.range;
      fetchData();
    });
  });

  // ---- Bouton plein écran ----
  // L'API Fullscreen du navigateur permet de passer n'importe quel élément
  // en plein écran. On l'applique à tout le <body> (le document entier).

  document.getElementById("fullscreen-btn").addEventListener("click", () => {
    if (!document.fullscreenElement) {
      // Pas encore en fullscreen → on y passe
      document.documentElement.requestFullscreen().catch(() => {});
    } else {
      // Déjà en fullscreen → on en sort
      document.exitFullscreen();
    }
  });

  // ---- Carte 2D Leaflet ----
  // Leaflet crée une carte 2D classique dans le conteneur #map-container.
  // On utilise les tuiles CartoDB Dark Matter (thème sombre assorti au site).
  // Les marqueurs sont des cercles cyan, les lignes d'attaque sont des
  // polylines SVG avec une animation CSS de pointillés.

  const leafletMap = L.map("map-container", {
    center: [30, 10],
    zoom: 3,
    zoomControl: true,
    attributionControl: false
  });

  // Tuiles CartoDB Dark Matter — carte sombre sans labels intrusifs
  L.tileLayer("https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png", {
    maxZoom: 18,
    subdomains: "abcd"
  }).addTo(leafletMap);

  // Layer groups pour gérer les marqueurs et les lignes séparément
  // (on vide et recrée à chaque rafraîchissement)
  let markersLayer = L.layerGroup().addTo(leafletMap);
  let linesLayer = L.layerGroup().addTo(leafletMap);

  // Marqueur fixe pour le serveur (Toulouse) — point orange
  const serverIcon = L.divIcon({
    className: "leaflet-marker-dot",
    iconSize: [10, 10],
    html: '<div style="width:10px;height:10px;border-radius:50%;background:rgba(255,100,50,0.9);border:2px solid rgba(255,100,50,0.5);box-shadow:0 0 12px rgba(255,100,50,0.7);"></div>'
  });

  // Fonction pour mettre à jour la carte 2D avec les données
  function updateLeafletMap(data) {
    if (!data || !data.arcs) return;
    const server = data.server || { lat: 43.6, lon: 1.44 };

    // Vider les layers précédents
    markersLayer.clearLayers();
    linesLayer.clearLayers();

    // Marqueur serveur
    L.marker([server.lat, server.lon], { icon: serverIcon })
      .bindPopup("<strong>home-fonta.fr</strong><br/>Serveur (Toulouse)")
      .addTo(markersLayer);

    // Pour chaque source, ajouter un marqueur + une ligne vers le serveur
    data.arcs.forEach(a => {
      // Taille du marqueur proportionnelle au count (échelle log, comme le globe)
      const radius = Math.min(3 + Math.log2(a.count + 1) * 1.5, 12);

      // Marqueur cercle cyan
      const marker = L.circleMarker([a.lat, a.lon], {
        radius: radius,
        fillColor: "rgba(0, 255, 255, 0.8)",
        fillOpacity: 0.7,
        color: "rgba(0, 255, 255, 0.4)",
        weight: 1
      });

      const city = a.city ? a.city + ", " : "";
      marker.bindPopup(
        `<strong>${city}${a.country}</strong><br/>${a.count} requête(s)`
      );
      marker.addTo(markersLayer);

      // Ligne d'attaque (polyline avec animation CSS)
      const line = L.polyline(
        [[a.lat, a.lon], [server.lat, server.lon]],
        {
          color: "rgba(0, 255, 255, 0.3)",
          weight: Math.min(1 + Math.log2(a.count + 1) * 0.3, 3),
          dashArray: "8 4",
          className: "leaflet-attack-line"
        }
      );
      line.addTo(linesLayer);
    });
  }

  // ---- Toggle 2D / 3D ----
  // Bascule entre le globe 3D (Globe.gl) et la carte 2D (Leaflet).
  // On ajoute/retire la classe CSS "view-2d" sur le body, ce qui
  // affiche/masque les conteneurs via CSS.

  function switchView(view) {
    currentView = view;
    const body = document.body;

    if (view === "2d") {
      body.classList.add("view-2d");
      document.getElementById("btn-2d").classList.add("active");
      document.getElementById("btn-3d").classList.remove("active");
      // Leaflet a besoin d'un invalidateSize quand son conteneur change de display
      // (sinon les tuiles ne se chargent pas correctement)
      setTimeout(() => leafletMap.invalidateSize(), 100);
    } else {
      body.classList.remove("view-2d");
      document.getElementById("btn-3d").classList.add("active");
      document.getElementById("btn-2d").classList.remove("active");
    }

    // Relancer un fetch pour mettre à jour la vue active
    fetchData();
  }

  document.getElementById("btn-2d").addEventListener("click", () => switchView("2d"));
  document.getElementById("btn-3d").addEventListener("click", () => switchView("3d"));

  // ---- Redimensionnement ----
  // Quand la fenêtre change de taille (ou entrée/sortie fullscreen),
  // on ajuste la taille du globe pour qu'il remplisse tout l'espace.
  // Pour Leaflet, invalidateSize() recalcule les tuiles.

  function handleResize() {
    globe.width(window.innerWidth);
    globe.height(window.innerHeight);
    if (currentView === "2d") {
      leafletMap.invalidateSize();
    }
  }

  window.addEventListener("resize", handleResize);
  handleResize();

  // ---- Lancement ----
  // Premier chargement immédiat, puis rafraîchissement toutes les 10s
  fetchData();
  setInterval(fetchData, REFRESH_INTERVAL);
});
