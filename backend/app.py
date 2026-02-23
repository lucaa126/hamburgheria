from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from database_wrapper import DatabaseWrapper
from dotenv import load_dotenv

# =========================
# 1. CARICAMENTO VARIABILI
# =========================
load_dotenv()

app = Flask(__name__)

# Configurazione CORS (Permette l'accesso da qualsiasi origine)
CORS(app)

# =========================
# 2. CONFIGURAZIONE DATABASE
# =========================
db = None

try:
    # RECUPERO SICURO DELLA PORTA
    raw_port = os.getenv("DB_PORT", "5432")
    db_port = int(raw_port)  # Converte in intero

    print(f"🔌 Tentativo di connessione a {os.getenv('DB_HOST')} sulla porta {db_port}...")

    db = DatabaseWrapper(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "password"),
        database=os.getenv("DB_NAME", "postgres"),
        port=db_port
    )
    print("✅ Connessione al Database riuscita!")

except ValueError:
    print("❌ ERRORE: La porta del DB nel file .env non è un numero valido.")
except Exception as e:
    print(f"❌ Errore critico di connessione al DB: {e}")

# =========================
# HELPER: CONTROLLO DB
# =========================
def check_db():
    """Controlla se il database è connesso prima di eseguire query"""
    if db is None:
        return jsonify({"error": "Database non connesso. Contatta l'amministratore."}), 503
    return None

# =========================
# 3. ROTTE PRODOTTI
# =========================

@app.route("/products", methods=["GET"])
def get_products():
    if error := check_db(): return error
    
    try:
        products = db.get_products()
        return jsonify(products), 200
    except Exception as e:
        print(f"Errore get_products: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/products", methods=["POST"])
def add_product():
    if error := check_db(): return error

    try:
        data = request.json
        nome = data.get("nome")
        prezzo = data.get("prezzo")
        categoria = data.get("categoria", "Altro")
        immagine_base64 = data.get("immagine", "")

        if not nome or not prezzo:
            return jsonify({"error": "Nome e prezzo sono obbligatori"}), 400

        db.add_product(nome, prezzo, categoria, immagine_base64)
        return jsonify({"message": "Prodotto aggiunto con successo"}), 201
    except Exception as e:
        print(f"❌ Errore nel salvataggio prodotto: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/products/<int:id>", methods=["DELETE"])
def delete_product(id):
    if error := check_db(): return error

    try:
        db.delete_product(id)
        return jsonify({"message": f"Prodotto {id} eliminato"}), 200
    except Exception as e:
        print(f"❌ Errore nell'eliminazione: {e}")
        return jsonify({"error": str(e)}), 500

# =========================
# 4. ROTTE ORDINI
# =========================

@app.route("/orders", methods=["POST"])
def create_order():
    if error := check_db(): return error

    try:
        data = request.json
        items = data.get("items", []) # Lista di {product_id, quantita}
        
        if not items:
            return jsonify({"error": "Nessun prodotto nell'ordine"}), 400
            
        order_id = db.create_order(items)
        return jsonify({"message": "Ordine creato", "order_id": order_id}), 201
    except Exception as e:
        print(f"❌ Errore creazione ordine: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/orders", methods=["GET"])
def get_orders():
    if error := check_db(): return error

    try:
        orders = db.get_orders()
        return jsonify(orders), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/orders/<int:id>", methods=["PUT"])
def update_order(id):
    if error := check_db(): return error

    try:
        data = request.json
        nuovo_stato = data.get("stato")
        
        if not nuovo_stato:
             return jsonify({"error": "Stato mancante"}), 400

        db.update_order_status(id, nuovo_stato)
        return jsonify({"message": "Stato aggiornato"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# =========================
# MAIN
# =========================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)