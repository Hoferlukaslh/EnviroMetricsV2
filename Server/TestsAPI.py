import requests
import time
import statistics
import concurrent.futures

# --- CONFIGURATION ---
IP_PORT = "192.168.1.240:8080"
BASE_URL_GO = f"http://{IP_PORT}/api"
BASE_URL_PYTHON = f"http://{IP_PORT}/api-python"

# Paramètres du test
ITERATIONS_SINGLE = 100         # Nombre de requêtes séquentielles (Single User)
CONCURRENT_USERS = 50           # Nombre d'utilisateurs simultanés (Multi-User)
TIMEOUT_SEC = 15                # Délai max avant d'abandonner une requête

# --- ROUTES À TESTER ---
ENDPOINTS = {
    "1. Liste Appareils": "/appareils",
    "2. Mesures (3 heures)": "/mesures?days=0.125&limit=20000",
    "3. Mesures (6 heures)": "/mesures?days=0.25&limit=20000",
    "4. Mesures (12 heures)": "/mesures?days=0.5&limit=20000",
    "5. Mesures (2 jours)": "/mesures?days=2&limit=20000",
    "6. Mesures (7 semaines)": "/mesures?days=49&limit=20000",
    "7. Mesures (365 jours)": "/mesures?days=365&limit=20000"
}

def fetch_url(session, url):
    """Effectue une requête HTTP et retourne le temps d'exécution ou une erreur."""
    start = time.perf_counter()
    try:
        resp = session.get(url, timeout=TIMEOUT_SEC)
        if resp.status_code == 200:
            return time.perf_counter() - start, None
        else:
            return None, f"HTTP {resp.status_code}"
    except requests.exceptions.RequestException as e:
        return None, "Timeout ou Connexion refusée"

def warmup(session, url):
    """Requête à vide pour réveiller le cache MariaDB/API"""
    try:
        session.get(url, timeout=2)
    except:
        pass

def run_single_user(api_name, base_url):
    print(f"\n[SINGLE USER] Test séquentiel de l'{api_name} ({ITERATIONS_SINGLE} itérations)")
    session = requests.Session()
    results = {}

    for name, route in ENDPOINTS.items():
        url = f"{base_url}{route}"
        times = []
        errors = 0

        warmup(session, url)

        for _ in range(ITERATIONS_SINGLE):
            duration, error = fetch_url(session, url)
            if duration is not None:
                times.append(duration)
            else:
                errors += 1

        if times:
            avg_time = statistics.mean(times) * 1000
            results[name] = avg_time
            print(f" -> {name}: Moyenne {avg_time:.2f} ms | Erreurs: {errors}/{ITERATIONS_SINGLE}")
        else:
            print(f" -> {name}: ❌ ÉCHEC TOTAL")
            results[name] = None

    return results

def run_multi_user(api_name, base_url):
    print(f"\n[MULTI USER] Test de charge de l'{api_name} ({CONCURRENT_USERS} requêtes simultanées)")
    session = requests.Session() # Session partagée pour réutiliser les connexions TCP
    results = {}

    for name, route in ENDPOINTS.items():
        url = f"{base_url}{route}"
        times = []
        errors = 0

        warmup(session, url)

        # Utilisation d'un ThreadPool pour lancer les requêtes en parallèle
        with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENT_USERS) as executor:
            # On prépare les tâches
            futures = [executor.submit(fetch_url, session, url) for _ in range(CONCURRENT_USERS)]

            # On récolte les résultats au fur et à mesure qu'ils se terminent
            for future in concurrent.futures.as_completed(futures):
                duration, error = future.result()
                if duration is not None:
                    times.append(duration)
                else:
                    errors += 1

        if times:
            avg_time = statistics.mean(times) * 1000
            max_time = max(times) * 1000
            results[name] = avg_time
            print(f" -> {name}: Moyenne {avg_time:.2f} ms | Pire temps: {max_time:.2f} ms | Erreurs: {errors}/{CONCURRENT_USERS}")
        else:
            print(f" -> {name}: ❌ ÉCHEC TOTAL (Le serveur a crashé ou tout a timeout)")
            results[name] = None

    return results

def print_comparison(title, results_go, results_python):
    print(f"\n=========================================")
    print(f"  🏆 COMPARAISON FINALE : {title}")
    print(f"=========================================")

    for name in ENDPOINTS.keys():
        go_time = results_go.get(name)
        py_time = results_python.get(name)

        print(f"\n{name}:")
        if go_time is not None and py_time is not None:
            print(f" - Go     : {go_time:.2f} ms")
            print(f" - Python : {py_time:.2f} ms")

            if go_time < py_time:
                ratio = py_time / go_time
                print(f" 🟢 Go est {ratio:.1f}x plus rapide")
            elif py_time < go_time:
                ratio = go_time / py_time
                print(f" 🔵 Python est {ratio:.1f}x plus rapide")
            else:
                print(" ⚪ Égalité parfaite")
        else:
            print(" - ⚠️ Impossible de comparer (trop d'erreurs d'un côté)")

if __name__ == '__main__':
    print("======================================================")
    print("  🚀 DÉMARRAGE DU BENCHMARK API (GO vs PYTHON)")
    print("======================================================\n")

    # --- PHASE 1 : SINGLE USER ---
    results_go_single = run_single_user("API GO", BASE_URL_GO)
    results_py_single = run_single_user("API PYTHON", BASE_URL_PYTHON)

    # --- PHASE 2 : MULTI USER ---
    time.sleep(3) # Petite pause pour laisser le serveur respirer
    results_go_multi = run_multi_user("API GO", BASE_URL_GO)
    results_py_multi = run_multi_user("API PYTHON", BASE_URL_PYTHON)

    # --- RAPPORTS ---
    print_comparison("MODE SINGLE USER", results_go_single, results_py_single)
    print_comparison("MODE MULTI USER (1000 connexions)", results_go_multi, results_py_multi)
