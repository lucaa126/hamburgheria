from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from database_wrapper import DatabaseWrapper
from dotenv import load_dotenv

# Carica le variabili d'ambiente (.env)
load_dotenv()

app = Flask(__name__)

# Configurazione CORS completa per accettare richieste da Codespaces
CORS(app, resources={r"/*": {"origins": "*"}}, methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"])

# Inizializzazione Database
try:
    db = DatabaseWrapper(
        host=os.getenv("DB_HOST"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        port=os.getenv("DB_PORT")
    )
    print("✅ Connessione al Database riuscita!")
except Exception as e:
    print(f"❌ Errore di connessione al DB: {e}")

# =========================
# ROTTE PRODOTTI
# =========================

@app.route("/products", methods=["GET"])
def get_products():
    try:
        products = db.get_products()
        return jsonify(products), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/products", methods=["POST"])
def add_product():
    try:
        data = request.json
        # Gestione sicura dei dati in ingresso
        nome = data.get("nome")
        prezzo = data.get("prezzo")
        categoria = data.get("categoria")
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
    try:
        db.delete_product(id)
        return jsonify({"message": f"Prodotto {id} eliminato"}), 200
    except Exception as e:
        print(f"❌ Errore nell'eliminazione: {e}")
        return jsonify({"error": str(e)}), 500

# =========================
# ROTTE ORDINI
# =========================

@app.route("/orders", methods=["POST"])
def create_order():
    try:
        data = request.json
        items = data.get("items", [])
        if not items:
            return jsonify({"error": "Nessun prodotto nell'ordine"}), 400
            
        order_id = db.create_order(items)
        return jsonify({"message": "Ordine creato", "order_id": order_id}), 201
    except Exception as e:
        print(f"❌ Errore creazione ordine: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/orders", methods=["GET"])
def get_orders():
    try:
        orders = db.get_orders()
        return jsonify(orders), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/orders/<int:id>", methods=["PUT"])
def update_order(id):
    try:
        data = request.json
        nuovo_stato = data.get("stato")
        db.update_order_status(id, nuovo_stato)
        return jsonify({"message": "Stato aggiornato"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)