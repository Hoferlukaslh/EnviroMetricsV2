<?php
    // Configuration de la connexion à MariaDB
    $host = 'db';
    $user = 'admin';
    $password = 'XYZ';
    $dbname = 'EnviroMetrics';

    $conn = new mysqli($host, $user, $password, $dbname);

    // Vérification de la connexion
    if ($conn->connect_error) {
        die("Erreur de connexion : " . $conn->connect_error);
    }

    // Récupération des données envoyées depuis l'ESP32
    $temperature = $_GET['temperature'] ?? null;
    $humidite = $_GET['humidite'] ?? null;
    $co2 = $_GET['co2'] ?? null;
    $app_id = $_GET['app_id'] ?? null;

    // Validation des données reçues
    if (
        is_null($temperature) || !is_numeric($temperature) ||
        is_null($humidite) || !is_numeric($humidite) ||
        is_null($co2) || !is_numeric($co2) ||
        is_null($app_id) || !is_numeric($app_id)
    ) {
        die("Paramètres manquants ou invalides.");
    }

    // Préparation et exécution de la requête d'insertion
    $sql = "INSERT INTO Mesures (timestemp, temperature, humidite, co2, NO) 
            VALUES (NOW(), ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        die("Erreur de préparation : " . $conn->error);
    }
    // d = double, i = int 
    $stmt->bind_param("ddii", $temperature, $humidite, $co2, $app_id);  

    if ($stmt->execute()) {
        echo "Insertion des valeurs réussie : Température = ";
        echo "{$temperature}°C, Humidité = {$humidite}%, CO₂ = {$co2} ppm, NO = {$app_id}.";
    } else {
        echo "Erreur d'exécution : " . $stmt->error;
    }

    $stmt->close();
    $conn->close();
?>
