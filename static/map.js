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
    // Le rayon dépend du nombre de hits (échelle logarithmique pour ne pas
    // avoir un point énorme pour un pays avec 10000 hits)
    .pointColor(() => POINT_COLOR)
    .pointAltitude(0.01)
    .pointRadius(d => Math.min(0.3 + Math.log2(d.count + 1) * 0.15, 2))
    .pointsMerge(true)
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

        // Mettre à jour le globe avec les nouvelles données
        // Globe.gl gère automatiquement les transitions (apparition/disparition)
        globe.arcsData(arcsData);
        globe.pointsData(pointsData);

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

  // ---- Redimensionnement ----
  // Quand la fenêtre change de taille (ou entrée/sortie fullscreen),
  // on ajuste la taille du globe pour qu'il remplisse tout l'espace.

  function handleResize() {
    globe.width(window.innerWidth);
    globe.height(window.innerHeight);
  }

  window.addEventListener("resize", handleResize);
  handleResize();

  // ---- Lancement ----
  // Premier chargement immédiat, puis rafraîchissement toutes les 10s
  fetchData();
  setInterval(fetchData, REFRESH_INTERVAL);
});
