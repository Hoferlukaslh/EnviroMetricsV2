# EnviroMetricsV2

**EnviroMetricsV2** est une solution IoT complète (de bout en bout) conçue pour la surveillance de la qualité de l'air et de l'environnement intérieur.
Le système collecte les données de température, d'humidité et de CO2 via un microcontrôleur ESP32-C6, les stocke sur un serveur auto-hébergé et les restitue sur un tableau de bord multiplateforme personnalisable.

## Fonctionnalités Principales

- **Acquisition de données précise :** Mesure de la température et de l'humidité via le capteur AHT10, et du CO2 via le capteur SCD4x.
- **Optimisation énergétique :** Utilisation du Deep Sleep (réveil toutes les 5 minutes) et du Light Sleep sur l'ESP32-C6 pour minimiser la consommation sur batterie.
- **Connexion Wi-Fi optimisée :** Sauvegarde du canal et du BSSID en mémoire RTC pour une reconnexion quasi instantanée (moins de 300 ms), complétée par une adresse IP statique.
- **Tableau de bord sur mesure :** Application multiplateforme en Flutter offrant des graphiques interactifs, la gestion de plusieurs capteurs et le choix de la plage temporelle.
- **Accessibilité et affichage E-Ink :** Prise en charge du mode sombre classique et d'un mode "Haut Contraste" exclusif (fond blanc, tracés noirs, suppression des ombres et des animations) optimisé pour les liseuses et tablettes E-Ink.
- **Rétrocompatibilité et double API :** Le proxy Nginx redirige de manière transparente les requêtes de l'application et les anciennes requêtes PHP (`SendDB.php`, `get_mesures.php`, `get_appareils.php`) vers la nouvelle API performante écrite en Go (ou Python), garantissant le fonctionnement des anciennes versions de l'application et des capteurs existants.

## Architecture du Projet
Le système repose sur une pile technologique moderne, modulaire et conteneurisée :

| Composant | Technologie | Rôle |
| --- | --- | --- |
| **Microcontrôleur** | ESP32-C6 (Arduino/C++/RTOS) | Lecture I2C des capteurs (AHT10, SCD4x) et transmission HTTP des mesures. |
| **API Backend (Par défaut)** | Go / Fiber | Point d'entrée principal ultra-rapide (port `/api/`) pour l'enregistrement et la requête des données. |
| **API Backend (Alternative)** | Python / FastAPI | API de secours ou alternative (port `/api-python/`). |
| **Base de Données** | MariaDB | Stockage persistant des appareils et de l'historique des mesures. |
| **Serveur Web / Proxy** | Nginx | Service du frontend web (Flutter) et routage dynamique vers les API ou les anciens liens PHP. |
| **Interface Utilisateur** | Flutter / Dart | Application mobile/web dynamique avec gestion des seuils d'alerte et paramètres API. |

## Performances (Go vs Python)
Pour garantir une réactivité optimale et supporter un grand nombre de capteurs, le backend a été migré de Python (FastAPI) vers Go (Fiber). Les benchmarks (détails dans [260706_resultTests.txt](file:///home/lukas/Bureau/EnviroMetricsV2/Server/260706_resultTests.txt)) montrent des gains significatifs en mode Single-User :
- **Liste Appareils** : Go est **18.0x plus rapide** (2.93 ms vs 52.83 ms)
- **Mesures (3h)** : Go est **4.7x plus rapide** (13.19 ms vs 61.39 ms)
- **Mesures (365 jours)** : Go est **2.6x plus rapide** (33.05 ms vs 84.87 ms)
En charge (Multi-User, 50 requêtes simultanées), Go reste jusqu'à **19.9x plus rapide**, d'où son utilisation par défaut pour toutes les requêtes de production.

## Installation & Déploiement (Serveur)

L'ensemble de l'infrastructure backend est conteneurisé et se déploie via Docker Compose.

**Prérequis :**
- Docker et Docker Compose installés sur votre serveur (ex: Raspberry Pi).

**Étapes :**

1. **Cloner le dépôt :** Clonez ce projet sur votre serveur hôte.
2. **Configuration de l'environnement :**
   Dans le dossier [Server](file:///home/lukas/Bureau/EnviroMetricsV2/Server), créez un fichier `.env` en vous basant sur la configuration actuelle ou l'exemple ci-dessous :
   ```env
   DB_ROOT_PASSWORD=VotreMotDePasseRoot
   DB_NAME=EnviroMetrics
   DB_USER=admin
   DB_PASSWORD=VotreMotDePasseUser
   PORT_PHPMYADMIN=1889
   PATH_BDD=./BDD
   ```
3. **Compiler le Web :** Placez la compilation web de votre application Flutter (`flutter build web`) dans le dossier `Server/frontend_web/`.
4. **Lancer les conteneurs :**
   Depuis le dossier `Server`, exécutez la commande suivante :
   ```bash
   cd Server
   docker-compose up -d --build
   ```
5. Le serveur Nginx exposera le frontend sur le port `8080` de votre réseau local, tout en gérant le routage `/api/` (Go) et `/api-python/` (Python) en arrière-plan. L'interface PhpMyAdmin sera disponible sur le port configuré dans le `.env` (`1889` par défaut).

## Conception Matérielle (Hardware)

Le dossier [Hardware](file:///home/lukas/Bureau/EnviroMetricsV2/Hardware) contient la conception électronique du projet :
- Schéma électronique et routage du circuit imprimé (PCB) sous **KiCad** (dossier [EnvirometricsV2](file:///home/lukas/Bureau/EnviroMetricsV2/Hardware/EnvirometricsV2)).
- Le circuit intègre l'ESP32-C6, le capteur de CO2 (SCD4x), le capteur de température/humidité (AHT10) ainsi que la gestion de l'alimentation par batterie avec retour de charge (`vbat`).

## Configuration du Capteur (ESP32-C6)

Le code C++ pour l'ESP32 se trouve dans le fichier [ESP-C6.ino](file:///home/lukas/Bureau/EnviroMetricsV2/ESP-C6/ESP-C6.ino).

1. **Câblage :** Connectez l'AHT10 et le SCD4x au bus I2C de l'ESP32-C6.
2. **Paramétrage Réseau :** Modifiez les variables `ssid` et `password` pour correspondre à votre réseau Wi-Fi.
3. **Paramétrage IP :** Ajustez `staticIP` et `gateway` selon votre routeur local pour éviter les latences DHCP lors du réveil.
4. **Serveur API :** Modifiez la variable `server` pour pointer vers l'adresse IP de votre serveur auto-hébergé.
5. Flashez le code avec l'IDE Arduino ou VS Code + PlatformIO.

## Utilisation de l'Application (Flutter)

L'application [EnviroMetrics](file:///home/lukas/Bureau/EnviroMetricsV2/App/envirometrics) permet de visualiser et d'adapter l'affichage des données environnementales en temps réel.

- **Configuration Initiale :** Rendez-vous dans les "Paramètres" (via le menu latéral) pour définir l'URL de votre API locale (ex: `http://<IP_SERVEUR>:8080/api`).
- **Limites des graphiques :** Ajustez manuellement les échelles Y pour la température (Min-Max), l'humidité et le CO2 afin de les adapter à chaque pièce.
- **Taux d'actualisation :** Le polling de l'application est paramétrable de 30 à 600 secondes.

## Ancien projet ([V1](https://github.com/Hoferlukaslh/EnviroMetrics))

Ce projet EnviroMetrics V2 n'est pas parti d'une page blanche : il s'agit d'une refonte complète et d'une amélioration majeure d'une première version (V1).

Le passage de cette ancienne version vers EnviroMetrics V2 marque l'évolution d'une architecture basique vers un véritable système IoT moderne et modulaire.
Là où l'ancienne mouture reposait sur des scripts PHP monolithiques (`SendDB.php`, `graphiques.php`) qui mélangeaient requêtes SQL directes et affichage web statique, la V2 sépare proprement la logique avec des API performantes (Go/Fiber par défaut, ou Python/FastAPI sous Docker) et une interface riche et multiplateforme (Flutter).
Du côté matériel, l'optimisation énergétique a fait un bond en avant grâce à l'utilisation d'un véritable Deep Sleep couplé à la sauvegarde des données Wi-Fi, réduisant ainsi drastiquement la consommation de la batterie.
