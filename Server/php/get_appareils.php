<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Configuration de la base de données
$host = 'db';
$user = 'admin';
$pass = 'XYZ';
$db = 'EnviroMetrics';

$conn = new mysqli($host, $user, $pass, $db);

if ($conn->connect_error) {
    die(json_encode(["error" => "Échec de connexion"]));
}

// CORRECTION : On utilise "NO" au lieu de "id" comme vu sur l'image phpMyAdmin
$sql = "SELECT NO, nom FROM appareil ORDER BY nom ASC";
$result = $conn->query($sql);

$appareils = [];

if ($result && $result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $appareils[] = [
            "id" => (int)$row["NO"], // On renvoie "NO" mais on garde la clé "id" pour Flutter
            "nom" => $row["nom"]
        ];
    }
}

echo json_encode($appareils);
$conn->close();
?>