<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$host = 'db';
$user = 'admin';
$password = 'XYZ';
$dbname = 'EnviroMetrics';

$conn = new mysqli($host, $user, $password, $dbname);

if ($conn->connect_error) {
    echo json_encode(["error" => "Erreur de connexion à la base de données"]);
    exit();
}

// 1. Récupération des paramètres (avec des valeurs par défaut si non fournis)
// On utilise $_GET pour récupérer les arguments dans l'URL
$app_id = isset($_GET['app_id']) ? intval($_GET['app_id']) : null;
$limit  = isset($_GET['limit']) ? intval($_GET['limit']) : 50;   // 50 par défaut
$days   = isset($_GET['days']) ? intval($_GET['days']) : null;

// Sécurité : on plafonne la limite pour éviter de faire crasher le serveur
if ($limit > 1000) $limit = 1000;

// 2. Construction dynamique de la requête SQL
$sql = "SELECT timestemp, temperature, humidite, co2, NO AS app_id FROM Mesures WHERE 1=1";
$types = "";
$params = [];

// Ajout du filtre par appareil (NO)
if ($app_id !== null) {
    $sql .= " AND NO = ?";
    $types .= "i"; // 'i' pour integer
    $params[] = $app_id;
}

// Ajout du filtre de temps (depuis X jours)
if ($days !== null && $days > 0) {
    $sql .= " AND timestemp >= NOW() - INTERVAL ? DAY";
    $types .= "i";
    $params[] = $days;
}

// Ajout du tri et de la limite
$sql .= " ORDER BY timestemp DESC LIMIT ?";
$types .= "i";
$params[] = $limit;

// 3. Exécution sécurisée (Préparation)
$stmt = $conn->prepare($sql);

// On "bind" dynamiquement les paramètres (l'équivalent de bind_param mais variable)
if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}

$stmt->execute();
$result = $stmt->get_result();

// 4. Formatage et envoi du JSON
$data = array();
if ($result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $data[] = $row;
    }
}

echo json_encode($data);

$stmt->close();
$conn->close();
?>