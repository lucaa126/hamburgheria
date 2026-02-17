import pymysql

class DatabaseWrapper:

    def __init__(self, host, user, password, database, port):
        self.db_config = {
            'host': host,
            'user': user,
            'password': password,
            'database': database,
            'port': int(port),
            'cursorclass': pymysql.cursors.DictCursor
        }

        self.create_tables()

    def connect(self):
        return pymysql.connect(**self.db_config)

    # ========================
    # METODI GENERICI
    # ========================

    def execute_query(self, query, params=()):
        conn = self.connect()
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            conn.commit()
        conn.close()

    def fetch_query(self, query, params=()):
        conn = self.connect()
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            result = cursor.fetchall()
        conn.close()
        return result

    # ========================
    # CREAZIONE TABELLE
    # ========================

    def create_tables(self):

        # PRODOTTI (Aggiornato con LONGTEXT per l'immagine)
        self.execute_query("""
        CREATE TABLE IF NOT EXISTS products (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nome VARCHAR(100) NOT NULL,
            prezzo DECIMAL(6,2) NOT NULL,
            categoria VARCHAR(50) NOT NULL,
            immagine LONGTEXT
        )
        """)

        # ORDINI
        self.execute_query("""
        CREATE TABLE IF NOT EXISTS orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            stato VARCHAR(50) DEFAULT 'In preparazione',
            data_creazione TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)

        # DETTAGLIO ORDINI
        self.execute_query("""
        CREATE TABLE IF NOT EXISTS order_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            order_id INT,
            product_id INT,
            quantita INT,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id)
        )
        """)

    # ========================
    # PRODOTTI
    # ========================

    def get_products(self):
        return self.fetch_query("SELECT * FROM products")

    def add_product(self, nome, prezzo, categoria, immagine=""):
        self.execute_query(
            "INSERT INTO products (nome, prezzo, categoria, immagine) VALUES (%s, %s, %s, %s)",
            (nome, prezzo, categoria, immagine)
        )

    def delete_product(self, product_id):
        self.execute_query(
            "DELETE FROM products WHERE id = %s",
            (product_id,)
        )

    # ========================
    # ORDINI
    # ========================

    def create_order(self, items):
        conn = self.connect()
        with conn.cursor() as cursor:

            # crea ordine
            cursor.execute("INSERT INTO orders (stato) VALUES ('In preparazione')")
            order_id = cursor.lastrowid

            # inserisce prodotti
            for item in items:
                cursor.execute("""
                    INSERT INTO order_items (order_id, product_id, quantita)
                    VALUES (%s, %s, %s)
                """, (order_id, item["product_id"], item["quantita"]))

            conn.commit()

        conn.close()
        return order_id

    def get_orders(self):
        return self.fetch_query("SELECT * FROM orders ORDER BY data_creazione DESC")

    def update_order_status(self, order_id, nuovo_stato):
        self.execute_query(
            "UPDATE orders SET stato = %s WHERE id = %s",
            (nuovo_stato, order_id)
        )