import 'package:flutter/material.dart';
import 'dart:convert'; // Per convertire i dati in JSON
import 'package:http/http.dart' as http; // Per le chiamate HTTP

void main() {
  runApp(const SmashBossApp());
}

// ==============================================================================
// ⚠️ CONFIGURAZIONE SERVER
// ==============================================================================
// Ho inserito l'URL che ho visto nei tuoi log. Se cambia, aggiornalo qui.
const String baseUrl = 'https://expert-space-fishstick-r4qgpxpwxrw9h5pg5-5000.app.github.dev';

// --- COSTANTI DI STILE ---
const Color kBackgroundColor = Color(0xFF0D0D0D);
const Color kSurfaceColor = Color(0xFF1E1E1E);
const Color kPrimaryColor = Color(0xFFFF9F00);

// --- DATA MODEL ---
class Product {
  final int id;
  final String name;
  final String category;
  final double price;
  final IconData icon;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.icon,
  });

  // Factory per creare un prodotto dal JSON del server Flask
  // CORRETTO: Gestisce il prezzo anche se arriva come Stringa ("3.00")
  factory Product.fromJson(Map<String, dynamic> json) {
    dynamic rawPrice = json['prezzo'];
    double finalPrice = 0.0;

    if (rawPrice is String) {
      // Se è una stringa (es: "3.00"), la convertiamo
      finalPrice = double.tryParse(rawPrice) ?? 0.0;
    } else if (rawPrice is num) {
      // Se è già un numero (int o double)
      finalPrice = rawPrice.toDouble();
    }

    return Product(
      id: json['id'],
      name: json['nome'],
      category: json['categoria'],
      price: finalPrice,
      icon: _getIconForCategory(json['categoria']),
    );
  }

  // Helper per assegnare icone in base alla categoria
  static IconData _getIconForCategory(String category) {
    switch (category.toUpperCase()) {
      case 'PANINI':
        return Icons.lunch_dining;
      case 'FRITTI':
        return Icons.tapas;
      case 'BEVANDE':
        return Icons.local_drink;
      default:
        return Icons.restaurant;
    }
  }
}

class SmashBossApp extends StatelessWidget {
  const SmashBossApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmashBoss Totem',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBackgroundColor,
        primaryColor: kPrimaryColor,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: kPrimaryColor,
          surface: kSurfaceColor,
        ),
        useMaterial3: true,
      ),
      home: const TotemPage(),
    );
  }
}

class TotemPage extends StatefulWidget {
  const TotemPage({super.key});

  @override
  State<TotemPage> createState() => _TotemPageState();
}

class _TotemPageState extends State<TotemPage> {
  String _selectedCategory = 'TUTTE';
  final Map<Product, int> _cart = {};
  
  // Stato per il caricamento prodotti
  List<Product> _products = [];
  bool _isFetchingProducts = true;
  bool _isSendingOrder = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProducts(); // Carica i prodotti all'avvio
  }

  // ============================================================================
  // 📡 SCARICA PRODOTTI DAL SERVER (GET)
  // ============================================================================
  Future<void> _fetchProducts() async {
    setState(() {
      _isFetchingProducts = true;
      _errorMessage = null;
    });

    try {
      print("Fetching products from: $baseUrl/products");
      final response = await http.get(Uri.parse('$baseUrl/products'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _products = data.map((json) => Product.fromJson(json)).toList();
          _isFetchingProducts = false;
        });
      } else {
        throw Exception("Errore server: ${response.statusCode}");
      }
    } catch (e) {
      print("Errore fetch: $e");
      setState(() {
        _isFetchingProducts = false;
        _errorMessage = "Impossibile caricare il menu.\nVerifica la connessione.";
      });
    }
  }

  // Filtra i prodotti in base alla categoria selezionata
  List<Product> get _visibleProducts {
    if (_selectedCategory == 'TUTTE') return _products;
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  double get _totalPrice {
    double total = 0;
    _cart.forEach((product, qty) {
      total += product.price * qty;
    });
    return total;
  }

  void _addToCart(Product p) {
    setState(() {
      _cart.update(p, (value) => value + 1, ifAbsent: () => 1);
    });
  }

  void _removeFromCart(Product p) {
    setState(() {
      if (_cart.containsKey(p) && _cart[p]! > 1) {
        _cart.update(p, (value) => value - 1);
      } else {
        _cart.remove(p);
      }
    });
  }

  // ============================================================================
  // 🚀 INVIA ORDINE A FLASK (POST)
  // ============================================================================
  Future<void> _submitOrderToFlask() async {
    setState(() => _isSendingOrder = true);

    try {
      List<Map<String, dynamic>> itemsPayload = [];
      
      _cart.forEach((product, qty) {
        itemsPayload.add({
          "product_id": product.id,
          "quantita": qty
        });
      });

      final Map<String, dynamic> requestBody = {
        "items": itemsPayload
      };

      print("Invio ordine a: $baseUrl/orders");
      
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final respData = jsonDecode(response.body);
        
        setState(() {
          _cart.clear();
          _isSendingOrder = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("ORDINE #${respData['order_id']} INVIATO! 🍔"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception("Server Error (${response.statusCode})");
      }

    } catch (e) {
      setState(() => _isSendingOrder = false);
      print("ERRORE INVIO: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Errore nell'invio dell'ordine."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================================
  // UI BUILDER
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- COLONNA SINISTRA (Prodotti) ---
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(), 
                
                // Area Contenuto (Loader, Errore o Griglia)
                Expanded(
                  child: _buildContentArea(),
                ),
              ],
            ),
          ),

          // --- COLONNA DESTRA (Carrello) ---
          Expanded(
            flex: 3,
            child: Container(
              color: kSurfaceColor,
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  const Text(
                    "IL TUO ORDINE",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: kPrimaryColor,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 40),
                  
                  // Lista elementi carrello
                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.shopping_cart_outlined,
                                    size: 60, color: Colors.white24),
                                SizedBox(height: 10),
                                Text("Il carrello è vuoto",
                                    style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _cart.length,
                            separatorBuilder: (ctx, i) =>
                                const Divider(color: Colors.white10),
                            itemBuilder: (ctx, i) {
                              final product = _cart.keys.elementAt(i);
                              final qty = _cart[product]!;
                              return _buildCartItem(product, qty);
                            },
                          ),
                  ),
                  
                  // Sezione Totale e Bottone
                  _buildCheckoutSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- GESTIONE CONTENUTO CENTRALE (Loading/Error/Grid) ---
  Widget _buildContentArea() {
    if (_isFetchingProducts) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 10),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchProducts,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text("Riprova", style: TextStyle(color: Colors.black)),
            )
          ],
        ),
      );
    }

    if (_visibleProducts.isEmpty) {
      return const Center(child: Text("Nessun prodotto disponibile in questa categoria."));
    }

    // Griglia Prodotti Effettiva
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, 
        childAspectRatio: 0.85,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _visibleProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_visibleProducts[index]);
      },
    );
  }

  // --- HEADER: LOGO E CATEGORIE ---
  Widget _buildTopBar() {
    // Otteniamo le categorie uniche dai prodotti scaricati
    Set<String> categories = {'TUTTE'};
    if (!_isFetchingProducts && _products.isNotEmpty) {
      categories.addAll(_products.map((p) => p.category));
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Logo (Placeholder o Asset)
          const Icon(Icons.fastfood, color: kPrimaryColor, size: 50),
          const SizedBox(width: 20),
          Container(width: 1, height: 40, color: Colors.white24),
          const SizedBox(width: 20),

          // Categorie
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(right: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? kPrimaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: isSelected ? kPrimaryColor : Colors.white24),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD DEL PRODOTTO ---
  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addToCart(product),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Icon(product.icon, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Text(product.category,
                    style: const TextStyle(
                        color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("€ ${product.price.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: kPrimaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- RIGA PRODOTTO NEL CARRELLO ---
  Widget _buildCartItem(Product product, int qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: Icon(product.icon, size: 24, color: kPrimaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("€ ${product.price.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
            onPressed: () => _removeFromCart(product),
          ),
          Text("$qty",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle, color: kPrimaryColor),
            onPressed: () => _addToCart(product),
          ),
        ],
      ),
    );
  }

  // --- SEZIONE CHECKOUT ---
  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.black38,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TOTALE", style: TextStyle(color: Colors.grey)),
              Text(
                "€ ${_totalPrice.toStringAsFixed(2)}",
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: (_cart.isEmpty || _isSendingOrder)
                  ? null
                  : _submitOrderToFlask,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSendingOrder
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      "PAGA E ORDINA",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}