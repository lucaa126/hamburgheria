from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from database_wrapper import DatabaseWrapper
from dotenv import load_dotenv

# Carica le variabili dal file .env
load_dotenv()
print("HOST:", os.getenv("DB_HOST"))
print("PORT:", os.getenv("DB_PORT"))

app = Flask(__name__)
CORS(app)

db = DatabaseWrapper(
    host=os.getenv("DB_HOST"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    database=os.getenv("DB_NAME"),
    port=os.getenv("DB_PORT")
)

# =========================
# PRODOTTI
# =========================

@app.route("/products", methods=["GET"])
def get_products():
    return jsonify(db.get_products())

@app.route("/products", methods=["POST"])
def add_product():
    data = request.json
    # Prende l'immagine se c'è, altrimenti stringa vuota
    immagine_base64 = data.get("immagine", "")
    
    db.add_product(
        data["nome"],
        data["prezzo"],
        data["categoria"],
        immagine_base64
    )
    return jsonify({"message": "Prodotto aggiunto"}), 201

@app.route("/products/<int:id>", methods=["DELETE"])
def delete_product(id):
    db.delete_product(id)
    return jsonify({"message": "Prodotto eliminato"})

# =========================
# ORDINI
# =========================

@app.route("/orders", methods=["POST"])
def create_order():
    data = request.json
    order_id = db.create_order(data["items"])
    return jsonify({"message": "Ordine creato", "order_id": order_id})

@app.route("/orders", methods=["GET"])
def get_orders():
    return jsonify(db.get_orders())

@app.route("/orders/<int:id>", methods=["PUT"])
def update_order(id):
    data = request.json
    db.update_order_status(id, data["stato"])
    return jsonify({"message": "Stato aggiornato"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)