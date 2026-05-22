import os
import pymysql
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional

app = FastAPI(title="EnviroMetrics API", description="API pour capteurs IoT")

# Autoriser Flutter et les navigateurs Web à interroger l'API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Fonction de connexion à MariaDB
def get_db_connection():
    try:
        return pymysql.connect(
            host=os.getenv("DB_HOST", "db"),
            user=os.getenv("DB_USER", "admin"),
            password=os.getenv("DB_PASSWORD", "XYZ"),
            database=os.getenv("DB_NAME", "EnviroMetrics"),
            cursorclass=pymysql.cursors.DictCursor
        )
    except pymysql.Error as e:
        raise HTTPException(status_code=500, detail=f"Erreur DB: {e}")

# ENVOI DES DONNÉES
# Nouvelle URL propre
@app.get("/send")
# Ancienne URL pour la rétrocompatibilité des ESP32
@app.get("/SendDB.php", include_in_schema=False)
def send_mesure(
    temperature: float = Query(...), 
    humidite: float = Query(...), 
    co2: int = Query(...), 
    app_id: int = Query(...)
):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            sql = """INSERT INTO Mesures (timestemp, temperature, humidite, co2, NO) 
                     VALUES (NOW(), %s, %s, %s, %s)"""
            cursor.execute(sql, (temperature, humidite, co2, app_id))
        conn.commit()
        return {"status": "success", "message": f"Inséré: T={temperature}°C, H={humidite}%, CO2={co2}ppm, ID={app_id}"}
    finally:
        conn.close()

# LISTE DES APPAREILS
@app.get("/appareils")
def get_appareils():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT NO as id, nom FROM appareil ORDER BY nom ASC")
            return cursor.fetchall()
    finally:
        conn.close()

# LECTURE DES MESURES
@app.get("/mesures")
def get_mesures(app_id: Optional[int] = None, days: int = 1, limit: int = 10000):
    limit = min(limit, 20000)
    conn = get_db_connection()
    
    try:
        with conn.cursor() as cursor:
            params = [days]

            if days >= 30:
                sql = """SELECT DATE(`timestemp`) AS timestemp, 
                                ROUND(AVG(`temperature`), 2) AS temperature, 
                                ROUND(AVG(`humidite`), 2) AS humidite, 
                                ROUND(AVG(`co2`), 2) AS co2, 
                                MAX(NO) AS app_id 
                         FROM Mesures WHERE timestemp >= NOW() - INTERVAL %s DAY"""
                group_by = " GROUP BY DATE(`timestemp`) ORDER BY timestemp DESC LIMIT %s"
            
            elif days >= 7:
                sql = """SELECT DATE_FORMAT(`timestemp`, '%%Y-%%m-%%d %%H:00:00') AS timestemp, 
                                ROUND(AVG(`temperature`), 2) AS temperature, 
                                ROUND(AVG(`humidite`), 2) AS humidite, 
                                ROUND(AVG(`co2`), 2) AS co2, 
                                MAX(NO) AS app_id 
                         FROM Mesures WHERE timestemp >= NOW() - INTERVAL %s DAY"""
                group_by = " GROUP BY DATE_FORMAT(`timestemp`, '%%Y-%%m-%%d %%H:00:00') ORDER BY timestemp DESC LIMIT %s"
            
            else:
                sql = """SELECT timestemp, temperature, humidite, co2, NO AS app_id 
                         FROM Mesures WHERE timestemp >= NOW() - INTERVAL %s DAY"""
                group_by = " ORDER BY timestemp DESC LIMIT %s"

            if app_id is not None:
                sql += " AND NO = %s"
                params.append(app_id)

            sql += group_by
            params.append(limit)

            cursor.execute(sql, tuple(params))
            results = cursor.fetchall()

            # Formatage des dates pour Flutter (ajout de 00:00:00 si besoin)
            for row in results:
                ts = str(row['timestemp'])
                if len(ts) == 10:
                    row['timestemp'] = f"{ts} 00:00:00"
                else:
                    row['timestemp'] = ts

            return results
    finally:
        conn.close()


# RÉTROCOMPATIBILITÉ (Pour les anciennes versions de l'app avec API PHP)
@app.get("/get_mesures.php", include_in_schema=False)
def legacy_get_mesures(app_id: Optional[int] = None, days: int = 1, limit: int = 10000):
    # On redirige silencieusement vers la nouvelle fonction interne
    return get_mesures(app_id=app_id, days=days, limit=limit)

@app.get("/get_appareils.php", include_in_schema=False)
def legacy_get_appareils():
    # On redirige silencieusement vers la nouvelle fonction interne
    return get_appareils()