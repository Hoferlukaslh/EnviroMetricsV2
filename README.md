# EnviroMetricsV2

**EnviroMetricsV2** est une solution IoT complète (de bout en bout) conçue pour la surveillance de la qualité de l'air et de l'environnement intérieur. 
Le système collecte les données de température, d'humidité et de CO2 via un ESP32, les stocke sur un serveur auto-hébergé et les restitue sur un tableau de bord multiplateforme personnalisable.

## Fonctionnalités Principales

- **Acquisition de données précise :** 
Mesure de la température et de l'humidité via le capteur AHT10, et du CO2 via le capteur SCD4x.

- **Optimisation énergétique :** 
Utilisation du Deep Sleep (réveil toutes les 5 minutes) et du Light Sleep sur l'ESP32-C6 pour minimiser la consommation.

- **Connexion Wi-Fi optimisée :** 
Sauvegarde du canal et du BSSID en mémoire RTC pour une reconnexion quasi instantanée, complétée par une IP statique.

- **Tableau de bord sur mesure :** 
Application Flutter offrant des graphiques interactifs, la gestion de plusieurs capteurs, et le choix de la plage temporelle.

- **Accessibilité et affichage E-Ink :** 
Prise en charge du mode sombre classique et d'un mode "Haut Contraste" exclusif (fond blanc, tracés noirs, suppression des ombres et animations) optimisé pour les tablettes E-Ink.

- **Rétrocompatibilité :** 
Le proxy Nginx redirige de manière transparente les anciennes requêtes PHP (`SendDB.php`, `get_mesures.php`) vers la nouvelle API FastAPI, garantissant le fonctionnement des anciennes versions de l'application et des capteurs existants.


## Architecture du Projet
Le système repose sur une pile technologique moderne et conteneurisée :

| Composant | Technologie | Rôle |
| --- | --- | --- |
| **Microcontrôleur** | ESP32-C6 (Arduino/C++/RTOS) | Lecture I2C des capteurs (AHT10, SCD4x) et transmission HTTP des mesures. |
| **API Backend** | Python / FastAPI | Point d'entrée ultra-rapide pour l'enregistrement et la requête des données. |
| **Base de Données** | MariaDB | Stockage persistant des appareils et de l'historique des mesures. |
| **Serveur Web / Proxy** | Nginx | Service du frontend web (Flutter) et routage dynamique vers l'API interne ou les anciens liens PHP. |
| **Interface Utilisateur** | Flutter / Dart | Application mobile/web dynamique avec gestion des seuils d'alerte et paramètres API. |

## Installation & Déploiement (Serveur)

L'ensemble de l'infrastructure backend est conteneurisé et se déploie via Docker Compose.

**Prérequis :**

- Docker et Docker Compose installés sur votre serveur (ex: Raspberry Pi).

**Étapes :**

1. **Cloner le dépôt :** Clonez ce projet sur votre serveur hôte.
2. **Configuration de l'environnement :** Créez un fichier `.env` à la racine du dossier serveur en vous basant sur l'exemple fourni.
3. **Compiler le Web :** Placez la compilation web de votre application Flutter (`flutter build web`) dans le dossier `./frontend_web`.
4. **Lancer les conteneurs :** ```bash docker-compose up -d --build ```
5. Le serveur Nginx exposera le frontend sur le port `8080` de votre réseau local, tout en gérant le routage `/api/` en arrière-plan. L'interface PhpMyAdmin sera disponible sur le port défini dans votre `.env`.

## Configuration du Capteur (ESP32-C6)

Le code C++ pour l'ESP32 se trouve dans le fichier `ESP-C6.ino`.

1. **Câblage :** Connectez l'AHT10 et le SCD4x au bus I2C de l'ESP32.
2. **Paramétrage Réseau :** Modifiez les variables `ssid`, `password` pour correspondre à votre réseau Wi-Fi.
3. **Paramétrage IP :** Ajustez `staticIP` et `gateway` selon votre routeur local pour éviter les latences liées au DHCP.
4. **Serveur API :** Modifiez la variable `server` pour pointer vers l'adresse IP de votre serveur auto-hébergé.
5. Flashez le code avec l'IDE Arduino.

## Utilisation de l'Application (Flutter)
L'application EnviroMetrics vous permet de visualiser et d'adapter l'affichage des données environnementales en temps réel.

- **Configuration Initiale :** 
Rendez-vous dans les "Paramètres" (via le menu latéral) pour définir l'URL de votre API locale (ex: `http://<IP_SERVEUR>:8080/api`).

- **Limites des graphiques :** 
Ajustez manuellement les échelles Y pour la température (Min-Max), l'humidité et le CO2 pour un affichage adapté à vos pièces.

- **Taux d'actualisation :** 
Le polling de l'application est paramétrable (de 30 à 600 secondes).

## Ancien projet ([V1](https://github.com/Hoferlukaslh/EnviroMetrics))
Ce projet EnviroMetrics V2 n'est pas parti d'une page blanche : il s'agit d'une refonte complète et d'une amélioration majeure d'une première version (V1).

Le passage de cette ancienne version vers EnviroMetrics V2 marque l'évolution d'une architecture basique vers un véritable système IoT moderne et modulaire. 
Là où l'ancienne mouture reposait sur des scripts PHP monolithiques (SendDB.php, graphiques.php) qui mélangeaient requêtes SQL directes et affichage web statique, la V2 sépare proprement la logique avec une API performante (FastAPI/Docker) et une interface riche et multiplateforme (Flutter). 
Du côté matériel, l'optimisation énergétique a fait un bond en avant par l'utilisation d'un véritable Deep Sleep couplé à la sauvegarde des données Wi-Fi, réduisant ainsi drastiquement la consommation de la batterie.
