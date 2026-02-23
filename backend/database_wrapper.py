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
        
        # Crea le tabelle appena viene inizializzata la classe
        self.create_tables()

    def connect(self):
        return pymysql.connect(**self.db_config)

    # ========================
    # METODI GENERICI
    # ========================

    def execute_query(self, query, params=()):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, params)
                conn.commit()
        finally:
            conn.close()

    def fetch_query(self, query, params=()):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                cursor.execute(query, params)
                result = cursor.fetchall()
            return result
        finally:
            conn.close()

    # ========================
    # CREAZIONE TABELLE
    # ========================

    def create_tables(self):
        # 1. Tabella PRODOTTI (con colonna immagine LONGTEXT)
        self.execute_query("""
        CREATE TABLE IF NOT EXISTS products (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nome VARCHAR(100) NOT NULL,
            prezzo DECIMAL(6,2) NOT NULL,
            categoria VARCHAR(50) NOT NULL,
            immagine LONGTEXT
        )
        """)

        # 2. Tabella ORDINI
        self.execute_query("""
        CREATE TABLE IF NOT EXISTS orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            stato VARCHAR(50) DEFAULT 'In preparazione',
            data_creazione TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)

        # 3. Tabella DETTAGLIO ORDINI
        self.execute_query("""
        CREATE TABLE IF NOT EXISTS order_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            order_id INT,
            product_id INT,
            quantita INT,
            FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
            FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
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
        # Grazie al 'ON DELETE CASCADE' definito nella tabella, 
        # basta cancellare il prodotto e si cancellano anche le righe in order_items
        self.execute_query("DELETE FROM products WHERE id = %s", (product_id,))

    # ========================
    # ORDINI
    # ========================

    def create_order(self, items):
        conn = self.connect()
        try:
            with conn.cursor() as cursor:
                # 1. Crea l'ordine testata
                cursor.execute("INSERT INTO orders (stato) VALUES ('In preparazione')")
                order_id = cursor.lastrowid

                # 2. Inserisce i prodotti collegati
                for item in items:
                    cursor.execute("""
                        INSERT INTO order_items (order_id, product_id, quantita)
                        VALUES (%s, %s, %s)
                    """, (order_id, item["product_id"], item["quantita"]))
                
                conn.commit()
                return order_id
        finally:
            conn.close()

    def get_orders(self):
        # 1. Recupera tutti gli ordini ordinati dal più recente
        orders = self.fetch_query("SELECT * FROM orders ORDER BY data_creazione DESC")
        
        # 2. Per ogni ordine, andiamo a cercare quali panini/bevande contiene
        for order in orders:
            order_id = order['id']
            query_dettagli = """
                SELECT oi.quantita, p.nome, p.prezzo 
                FROM order_items oi
                JOIN products p ON oi.product_id = p.id
                WHERE oi.order_id = %s
            """
            dettagli = self.fetch_query(query_dettagli, (order_id,))
            
            # Aggiungiamo l'array dei dettagli all'ordine (è esattamente quello che Angular si aspetta!)
            order['dettagli'] = dettagli
            
            # Formattiamo la data per evitare che Flask vada in errore convertendola in JSON
            if 'data_creazione' in order and order['data_creazione']:
                order['data_creazione'] = str(order['data_creazione'])

        return orders

    def update_order_status(self, order_id, nuovo_stato):
        self.execute_query(
            "UPDATE orders SET stato = %s WHERE id = %s",
            (nuovo_stato, order_id)
        )