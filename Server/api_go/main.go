package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strconv"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
)

var db *sql.DB

func initDB() {
	host := os.Getenv("DB_HOST")
	if host == "" {
		host = "db"
	}
	user := os.Getenv("DB_USER")
	if user == "" {
		user = "admin"
	}
	password := os.Getenv("DB_PASSWORD")
	if password == "" {
		password = "XYZ"
	}
	dbname := os.Getenv("DB_NAME")
	if dbname == "" {
		dbname = "EnviroMetrics"
	}

	dsn := fmt.Sprintf("%s:%s@tcp(%s:3306)/%s", user, password, host, dbname)

	var err error
	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("Erreur d'ouverture de la base de données: %v", err)
	}

	db.SetMaxOpenConns(50)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(0)

	if err = db.Ping(); err != nil {
		log.Fatalf("Impossible de se connecter à MariaDB: %v", err)
	}
	log.Println("Connexion à MariaDB établie avec succès.")
}

func main() {
	initDB()
	defer db.Close()

	app := fiber.New(fiber.Config{
		AppName: "EnviroMetrics API",
	})

	// Configuration CORS corrigée (avec les fameuses virgules !)
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "*",
		AllowMethods: "*",
	}))

	app.Get("/send", sendMesure)
	app.Get("/SendDB.php", sendMesure)

	app.Get("/appareils", getAppareils)
	app.Get("/get_appareils.php", getAppareils)

	app.Get("/mesures", getMesures)
	app.Get("/get_mesures.php", getMesures)

	log.Fatal(app.Listen(":80"))
}

// --- CONTRÔLEURS ---

func sendMesure(c *fiber.Ctx) error {
	if c.Query("temperature") == "" || c.Query("humidite") == "" || c.Query("co2") == "" || c.Query("app_id") == "" {
		return c.Status(422).JSON(fiber.Map{"detail": "Paramètres obligatoires manquants"})
	}

	temperature, errT := strconv.ParseFloat(c.Query("temperature"), 64)
	humidite, errH := strconv.ParseFloat(c.Query("humidite"), 64)
	co2, errC := strconv.Atoi(c.Query("co2"))
	appID, errA := strconv.Atoi(c.Query("app_id"))

	if errT != nil || errH != nil || errC != nil || errA != nil {
		return c.Status(422).JSON(fiber.Map{"detail": "Types de paramètres invalides"})
	}

	vbatStr := c.Query("vbat")
	var vbat interface{}
	vbatMessage := "N/A"

	if vbatStr != "" {
		if v, err := strconv.ParseFloat(vbatStr, 64); err == nil {
			vbat = v
			vbatMessage = fmt.Sprintf("%vV", v)
		} else {
			vbat = nil
		}
	} else {
		vbat = nil
	}

	sqlQuery := `INSERT INTO Mesures (timestemp, temperature, humidite, co2, NO, vbat)
	VALUES (NOW(), ?, ?, ?, ?, ?)`

	_, err := db.Exec(sqlQuery, temperature, humidite, co2, appID, vbat)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"detail": fmt.Sprintf("Erreur DB: %v", err)})
	}

	return c.JSON(fiber.Map{
		"status":  "success",
		"message": fmt.Sprintf("Inséré: T=%v°C, H=%v%%, CO2=%vppm, ID=%v, Vbat=%s", temperature, humidite, co2, appID, vbatMessage),
	})
}

func getAppareils(c *fiber.Ctx) error {
	rows, err := db.Query("SELECT NO as id, nom FROM appareil ORDER BY nom ASC")
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"detail": fmt.Sprintf("Erreur DB: %v", err)})
	}
	defer rows.Close()

	var appareils []fiber.Map
	for rows.Next() {
		var id int
		var nom string
		if err := rows.Scan(&id, &nom); err != nil {
			continue
		}
		appareils = append(appareils, fiber.Map{"id": id, "nom": nom})
	}

	if appareils == nil {
		appareils = []fiber.Map{}
	}
	return c.JSON(appareils)
}

func getMesures(c *fiber.Ctx) error {
	days := c.QueryFloat("days", 1.0)
	limit := c.QueryInt("limit", 10000)

	if limit > 20000 {
		limit = 20000
	}

	var appID *int
	if c.Query("app_id") != "" {
		id, err := strconv.Atoi(c.Query("app_id"))
		if err == nil {
			appID = &id
		}
	}

	seconds := int(days * 86400)

	var sqlQuery, groupBy string
	var args []interface{}
	args = append(args, seconds)

	if days >= 30 {
		sqlQuery = "SELECT DATE(`timestemp`) AS timestemp, " +
		"ROUND(AVG(`temperature`), 2) AS temperature, " +
		"ROUND(AVG(`humidite`), 2) AS humidite, " +
		"ROUND(AVG(`co2`), 2) AS co2, " +
		"ROUND(AVG(`vbat`), 2) AS vbat, " +
		"MAX(NO) AS app_id " +
		"FROM Mesures WHERE timestemp >= NOW() - INTERVAL ? SECOND"
		groupBy = " GROUP BY DATE(`timestemp`) ORDER BY timestemp DESC LIMIT ?"
	} else if days >= 7 {
		sqlQuery = "SELECT DATE_FORMAT(`timestemp`, '%Y-%m-%d %H:00:00') AS timestemp, " +
		"ROUND(AVG(`temperature`), 2) AS temperature, " +
		"ROUND(AVG(`humidite`), 2) AS humidite, " +
		"ROUND(AVG(`co2`), 2) AS co2, " +
		"ROUND(AVG(`vbat`), 2) AS vbat, " +
		"MAX(NO) AS app_id " +
		"FROM Mesures WHERE timestemp >= NOW() - INTERVAL ? SECOND"
		groupBy = " GROUP BY DATE_FORMAT(`timestemp`, '%Y-%m-%d %H:00:00') ORDER BY timestemp DESC LIMIT ?"
	} else {
		sqlQuery = "SELECT timestemp, temperature, humidite, co2, vbat, NO AS app_id " +
		"FROM Mesures WHERE timestemp >= NOW() - INTERVAL ? SECOND"
		groupBy = " ORDER BY timestemp DESC LIMIT ?"
	}

	if appID != nil {
		sqlQuery += " AND NO = ?"
		args = append(args, *appID)
	}

	sqlQuery += groupBy
	args = append(args, limit)

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"detail": fmt.Sprintf("Erreur DB: %v", err)})
	}
	defer rows.Close()

	var result []fiber.Map
	for rows.Next() {
		var tsBytes []byte

		var temp, hum, co2, vbat sql.NullFloat64
		var id sql.NullInt64

		if err := rows.Scan(&tsBytes, &temp, &hum, &co2, &vbat, &id); err != nil {
			log.Printf("Erreur de scan sur une ligne : %v", err)
			continue
		}

		ts := string(tsBytes)
		if len(ts) == 10 {
			ts += " 00:00:00"
		}

		rowMap := fiber.Map{
			"timestemp": ts,
		}

		if temp.Valid { rowMap["temperature"] = temp.Float64 } else { rowMap["temperature"] = nil }
		if hum.Valid { rowMap["humidite"] = hum.Float64 } else { rowMap["humidite"] = nil }
		if co2.Valid { rowMap["co2"] = co2.Float64 } else { rowMap["co2"] = nil }
		if id.Valid { rowMap["app_id"] = id.Int64 } else { rowMap["app_id"] = nil }
		if vbat.Valid { rowMap["vbat"] = vbat.Float64 } else { rowMap["vbat"] = nil }

		result = append(result, rowMap)
	}

	if result == nil {
		result = []fiber.Map{}
	}
	return c.JSON(result)
}
