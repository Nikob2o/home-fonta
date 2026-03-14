import os
import requests as http_client
from flask import Flask, render_template, jsonify, request

app = Flask(__name__, static_url_path='/static', static_folder='static', template_folder='templates')

# URL interne de Loki dans le cluster K8s (configurable via variable d'env)
LOKI_URL = os.environ.get('LOKI_URL', 'http://loki.loki.svc.cluster.local:3100')

# Coordonnées du serveur (destination des arcs sur le globe)
SERVER_LAT = 43.6
SERVER_LON = 1.44


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/presentation')
def presentation():
    return render_template('presentation.html')


@app.route('/galerie')
def galerie():
    return render_template('galerie.html')


@app.route('/services')
def services():
    return render_template('services.html')


@app.route('/map')
def attack_map():
    return render_template('map.html')


@app.route('/api/map-data')
def map_data():
    """Interroge Loki pour récupérer les connexions géolocalisées récentes.

    Paramètre GET optionnel :
      - range : durée LogQL (ex: "1h", "6h", "24h"). Défaut "1h".

    Retourne un JSON avec :
      - arcs : liste de {lat, lon, country, city, count}
      - total_ips : nombre d'IPs uniques
      - total_hits : nombre total de requêtes
      - top_countries : top 5 des pays par nombre de hits
    """
    time_range = request.args.get('range', '1h')
    # Sécurité : on n'accepte que des valeurs connues pour éviter l'injection LogQL
    allowed = {'5m', '15m', '30m', '1h', '6h', '12h', '24h'}
    if time_range not in allowed:
        time_range = '1h'

    # Requête LogQL : agrège les hits par coordonnées + pays + ville
    query = (
        'sum by (geoip_location_latitude, geoip_location_longitude, '
        'geoip_country_name, geoip_city_name) '
        '(count_over_time({namespace="ingress-nginx", '
        f'geoip_location_latitude=~".+"}} [{time_range}]))'
    )

    try:
        resp = http_client.get(
            f'{LOKI_URL}/loki/api/v1/query',
            params={'query': query},
            timeout=10
        )
        resp.raise_for_status()
        data = resp.json()
    except Exception:
        return jsonify({'arcs': [], 'total_ips': 0, 'total_hits': 0,
                        'top_countries': []}), 200

    # Extraire les résultats du format Loki (type "vector")
    results = data.get('data', {}).get('result', [])

    arcs = []
    country_counts = {}
    total_hits = 0

    for entry in results:
        metric = entry.get('metric', {})
        # value est [timestamp, "count_string"]
        value = entry.get('value', [0, '0'])
        count = int(float(value[1]))

        lat = metric.get('geoip_location_latitude', '')
        lon = metric.get('geoip_location_longitude', '')
        country = metric.get('geoip_country_name', 'Inconnu')
        city = metric.get('geoip_city_name', '')

        if not lat or not lon:
            continue

        arcs.append({
            'lat': float(lat),
            'lon': float(lon),
            'country': country,
            'city': city,
            'count': count
        })

        total_hits += count
        country_counts[country] = country_counts.get(country, 0) + count

    # Top 5 pays triés par nombre de hits (décroissant)
    top_countries = sorted(country_counts.items(), key=lambda x: x[1],
                           reverse=True)[:5]

    return jsonify({
        'arcs': arcs,
        'total_ips': len(arcs),
        'total_hits': total_hits,
        'top_countries': [{'country': c, 'hits': h} for c, h in top_countries],
        'server': {'lat': SERVER_LAT, 'lon': SERVER_LON}
    })


@app.route('/menu')
def menu():
    return render_template('menu.html')


@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
