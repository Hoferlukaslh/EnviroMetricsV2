<?php
    // Connexion à la base de données
    $servername = "db";
    $username = "admin";
    $password = "XYZ";
    $dbname = "EnviroMetrics";
    
    $userLogged = FALSE;

    // Essai la connection a la base de données, si erreur -> affichage
    try {
        // Connexion à la base de données avec PDO
        $conn = new PDO("mysql:host=$servername;dbname=$dbname;charset=utf8", $username, $password);

        // Configuration des options PDO
        $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION); // Active les exceptions pour les erreurs

        //echo "Connexion réussie à la base de données !";

    } catch (PDOException $e) {
        // Gestion des erreurs de connexion
        die("Échec de la connexion : " . $e->getMessage());
    }
?>