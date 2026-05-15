<?php
// Inclure le fichier de connexion
include('db_connect.php');

// Requête SQL pour obtenir la dernière mesure de température, humidité et CO2
$query = "SELECT timestemp, temperature, humidite, co2
          FROM mesure
          WHERE APP_ID = 1
          ORDER BY timestemp DESC
          LIMIT 1";  // On limite à 1 pour obtenir la dernière mesure

// Initialiser les variables pour les températures, humidité et CO2 actuels, et les données des graphiques
$currentTemperature = null;
$currentHumidity = null;
$currentCO2 = null;
$timestamps = [];
$temperatures = [];
$humidities = [];
$co2Levels = [];

// Exécution de la requête
try {
    // Exécuter la requête
    $stmt = $conn->prepare($query);
    $stmt->execute();

    // Vérifier si des résultats sont trouvés
    if ($stmt->rowCount() > 0) {
        // Récupérer la dernière mesure
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        $currentTemperature = $row['temperature'];
        $currentHumidity = $row['MES_humidite'];
        $currentCO2 = $row['co2'];

        /* Requête pour obtenir toutes les données pour les graphiques (1 jour)
        $query_all = "  SELECT timestemp, temperature, MES_humidite, co2
                        FROM mesure
                        WHERE APP_ID = 2
                        AND timestemp >= NOW() - INTERVAL 1 DAY  -- Filtrer les données des dernières 24 heures
                        ORDER BY timestemp ASC;
                        ";*/

        //Requête pour obtenir toutes les données pour les graphiques
        $query_all = "SELECT timestemp, temperature, MES_humidite, co2
                      FROM mesure
                      WHERE APP_ID = 1
                      ORDER BY timestemp ASC";


        $stmt_all = $conn->prepare($query_all);
        $stmt_all->execute();

        // Récupérer toutes les données
        while ($row_all = $stmt_all->fetch(PDO::FETCH_ASSOC)) {
            $timestamps[] = $row_all['timestemp'];
            $temperatures[] = $row_all['temperature'];
            $humidities[] = $row_all['MES_humidite'];
            $co2Levels[] = $row_all['co2'];
        }
    } else {
        echo "<p>Aucune mesure trouvée.</p>";
    }
} catch (PDOException $e) {
    // Gestion des erreurs de requête
    echo "Erreur lors de l'exécution de la requête: " . $e->getMessage();
}
?>

<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Graphiques des Mesures</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns"></script>
    <link rel="stylesheet" href="styles.css">
</head>
<body>

    <h3>Mesures actuelles</h3>
    <!-- Affichage des mesures actuelles -->
    <p><strong>Température actuelle : </strong> <?php echo htmlspecialchars($currentTemperature); ?> °C <br/>
        <strong>Humidité actuelle : </strong> <?php echo htmlspecialchars($currentHumidity); ?> %<br/>
        <strong>CO₂ actuel : </strong> <?php echo htmlspecialchars($currentCO2); ?> ppm
    </p>
    
    <h3>Graphiques des Mesures</h3>

    <div class=graphiques>
        <canvas id="temperatureChart" width="100" height="100"></canvas>
        <canvas id="humidityChart" width="100" height="100"></canvas>
        <canvas id="co2Chart" width="100" height="100"></canvas>
    </div>
    
    
    <script>
        // Données PHP passées à JavaScript
        var timestamps = <?php echo json_encode($timestamps); ?>;
        var temperatures = <?php echo json_encode($temperatures); ?>;
        var humidities = <?php echo json_encode($humidities); ?>;
        var co2Levels = <?php echo json_encode($co2Levels); ?>;

        // Convertir les timestamps en objets Date JavaScript
        var dateLabels = timestamps.map(function(timestamp) {
            return new Date(timestamp); // Conversion des chaînes en objets Date
        });

        // Création du graphique de température
        var ctxTemp = document.getElementById('temperatureChart').getContext('2d');
        var temperatureChart = new Chart(ctxTemp, {
            type: 'line',
            data: {
                labels: dateLabels, // Labels de l'axe X (timestamps en tant qu'objets Date)
                datasets: [{
                    label: 'Température (°C)',
                    data: temperatures, // Données de température
                    borderColor: 'rgba(75, 192, 192, 1)',
                    backgroundColor: 'rgba(75, 192, 192, 0.2)',
                    fill: false,
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                scales: {
                    x: {
                        type: 'time', // Utilisation du type 'time' pour les dates
                        time: {
                            unit: 'hour', // Unité de temps (heure dans cet exemple)
                            tooltipFormat: 'll HH:mm', // Format de tooltip pour afficher la date
                            displayFormats: {
                                hour: 'yyyy-MM-dd HH:mm', // Format des dates sur l'axe X
                            }
                        },
                        title: {
                            display: true,
                            text: 'Temps'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: 'Température (°C)'
                        }
                    }
                }
            }
        });

        // Création du graphique d'humidité
        var ctxHumidity = document.getElementById('humidityChart').getContext('2d');
        var humidityChart = new Chart(ctxHumidity, {
            type: 'line',
            data: {
                labels: dateLabels, // Labels de l'axe X (timestamps en tant qu'objets Date)
                datasets: [{
                    label: 'Humidité (%)',
                    data: humidities, // Données d'humidité
                    borderColor: 'rgba(255, 159, 64, 1)',
                    backgroundColor: 'rgba(255, 159, 64, 0.2)',
                    fill: false,
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'hour',
                            tooltipFormat: 'll HH:mm',
                            displayFormats: {
                                hour: 'yyyy-MM-dd HH:mm',
                            }
                        },
                        title: {
                            display: true,
                            text: 'Temps'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: 'Humidité (%)'
                        }
                    }
                }
            }
        });

        // Création du graphique de CO₂
        var ctxCO2 = document.getElementById('co2Chart').getContext('2d');
        var co2Chart = new Chart(ctxCO2, {
            type: 'line',
            data: {
                labels: dateLabels, // Labels de l'axe X (timestamps en tant qu'objets Date)
                datasets: [{
                    label: 'CO₂ (ppm)',
                    data: co2Levels, // Données de CO₂
                    borderColor: 'rgba(153, 102, 255, 1)',
                    backgroundColor: 'rgba(153, 102, 255, 0.2)',
                    fill: false,
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'hour',
                            tooltipFormat: 'll HH:mm',
                            displayFormats: {
                                hour: 'yyyy-MM-dd HH:mm',
                            }
                        },
                        title: {
                            display: true,
                            text: 'Temps'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: 'CO₂ (ppm)'
                        }
                    }
                }
            }
        });
    </script>

</body>
</html>
