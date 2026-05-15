<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$host = 'db';
$user = 'admin';
$password = 'Admin22#';
$dbname = 'EnviroMetrics';

$conn = new mysqli($host, $user, $password, $dbname);

if ($conn->connect_error) {
    echo json_encode(["error" => "Erreur de connexion à la base de données"]);
    exit();
}

// 1. Récupération des paramètres
$app_id = isset($_GET['app_id']) ? intval($_GET['app_id']) : null;
$days   = isset($_GET['days']) ? intval($_GET['days']) : 1; // Par défaut 1 jour
// On augmente la limite par défaut pour permettre d'afficher un graphique complet
$limit  = isset($_GET['limit']) ? intval($_GET['limit']) : 10000; 

if ($limit > 20000) $limit = 20000;

$types = "";
$params = [];

// 2. Logique Node-RED intégrée directement en PHP
if ($days >= 30) {
    // --- OPTIMISATION >= 30 JOURS : Moyenne journalière ---
    $sql = "SELECT DATE(`timestemp`) AS timestemp, 
                   ROUND(AVG(`temperature`), 2) AS temperature, 
                   ROUND(AVG(`humidite`), 2) AS humidite, 
                   ROUND(AVG(`co2`), 2) AS co2, 
                   MAX(NO) AS app_id 
            FROM Mesures 
            WHERE timestemp >= NOW() - INTERVAL ? DAY";
    $types .= "i";
    $params[] = $days;

    if ($app_id !== null) {
        $sql .= " AND NO = ?";
        $types .= "i";
        $params[] = $app_id;
    }

    $sql .= " GROUP BY DATE(`timestemp`) ORDER BY timestemp DESC LIMIT ?";
    $types .= "i";
    $params[] = $limit;

} else {
    // --- CLASSIQUE (< 30 JOURS) ---
    $sql = "SELECT timestemp, temperature, humidite, co2, NO AS app_id 
            FROM Mesures 
            WHERE timestemp >= NOW() - INTERVAL ? DAY";
    $types .= "i";
    $params[] = $days;

    if ($app_id !== null) {
        $sql .= " AND NO = ?";
        $types .= "i";
        $params[] = $app_id;
    }

    // OPTIMISATION >= 7 JOURS : 1 valeur sur 10 (Modulo)
    if ($days >= 7 && $days < 30) {
        $sql .= " AND MOD(ID, 10) = 0";
    }

    $sql .= " ORDER BY timestemp DESC LIMIT ?";
    $types .= "i";
    $params[] = $limit;
}

// 3. Exécution sécurisée
$stmt = $conn->prepare($sql);

if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}

$stmt->execute();
$result = $stmt->get_result();

// 4. Formatage et envoi du JSON
$data = array();
if ($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        // En mode "AVG", la date sort au format "YYYY-MM-DD". 
        // On rajoute 00:00:00 pour que le parsing Dart "DateTime.parse()" soit parfait.
        if (strlen($row['timestemp']) == 10) {
            $row['timestemp'] .= " 00:00:00";
        }
        $data[] = $row;
    }
}

echo json_encode($data);

$stmt->close();
$conn->close();
?>