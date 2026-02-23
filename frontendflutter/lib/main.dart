import 'package:flutter/material.dart';
import 'dart:convert'; // Per convertire i dati in JSON e Base64
import 'dart:typed_data'; // Per gestire i byte delle immagini
import 'package:http/http.dart' as http; // Per le chiamate HTTP

void main() {
  runApp(const SmashBossApp());
}

// ==============================================================================
// ⚠️ CONFIGURAZIONE SERVER
// ==============================================================================
const String baseUrl = 'https://verbose-journey-976jpg4j459r29rxg-5000.app.github.dev';

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
  final String? imageBase64; // Aggiunto il campo per l'immagine

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.icon,
    this.imageBase64,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    dynamic rawPrice = json['prezzo'];
    double finalPrice = 0.0;

    if (rawPrice is String) {
      finalPrice = double.tryParse(rawPrice) ?? 0.0;
    } else if (rawPrice is num) {
      finalPrice = rawPrice.toDouble();
    }

    return Product(
      id: json['id'],
      name: json['nome'],
      category: json['categoria'],
      price: finalPrice,
      icon: _getIconForCategory(json['categoria']),
      // Prende l'immagine dal JSON (se esiste ed è non vuota)
      imageBase64: (json['immagine'] != null && json['immagine'].toString().isNotEmpty) 
          ? json['immagine'] 
          : null,
    );
  }

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
  
  List<Product> _products = [];
  bool _isFetchingProducts = true;
  bool _isSendingOrder = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
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
      setState(() {
        _isFetchingProducts = false;
        _errorMessage = "Impossibile caricare il menu.\nVerifica la connessione.";
      });
    }
  }

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
              content: Text("ORDINE #${respData['order_id']} INVIATO! 🍔", style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception("Server Error");
      }

    } catch (e) {
      setState(() => _isSendingOrder = false);
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
  // WIDGET HELPER: RENDER IMMAGINE BASE64 O FALLBACK ALL'ICONA
  // ============================================================================
  Widget _buildProductImage(String? base64String, IconData fallbackIcon, {double borderRadius = 8, bool isCartItem = false}) {
    if (base64String == null || base64String.isEmpty) {
      return Icon(fallbackIcon, size: isCartItem ? 24 : 60, color: isCartItem ? kPrimaryColor : Colors.white24);
    }
    
    try {
      // Rimuoviamo l'eventuale intestazione (es: data:image/png;base64,)
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }
      
      // Decodifichiamo i byte
      Uint8List imageBytes = base64Decode(cleanBase64);
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          imageBytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          // Se per caso i byte sono corrotti, mostra l'icona di fallback
          errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: isCartItem ? 24 : 60, color: Colors.white24),
        ),
      );
    } catch (e) {
      return Icon(fallbackIcon, size: isCartItem ? 24 : 60, color: Colors.white24);
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
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(), 
                Expanded(child: _buildContentArea()),
              ],
            ),
          ),
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
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.white24),
                                SizedBox(height: 10),
                                Text("Il carrello è vuoto", style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _cart.length,
                            separatorBuilder: (ctx, i) => const Divider(color: Colors.white10),
                            itemBuilder: (ctx, i) {
                              final product = _cart.keys.elementAt(i);
                              final qty = _cart[product]!;
                              return _buildCartItem(product, qty);
                            },
                          ),
                  ),
                  _buildCheckoutSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (_isFetchingProducts) return const Center(child: CircularProgressIndicator(color: kPrimaryColor));

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

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, 
        childAspectRatio: 0.80, // Leggermente ritoccato per far respirare meglio l'immagine
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _visibleProducts.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_visibleProducts[index]);
      },
    );
  }

  Widget _buildTopBar() {
    Set<String> categories = {'TUTTE'};
    if (!_isFetchingProducts && _products.isNotEmpty) {
      categories.addAll(_products.map((p) => p.category));
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          const Icon(Icons.fastfood, color: kPrimaryColor, size: 50),
          const SizedBox(width: 20),
          Container(width: 1, height: 40, color: Colors.white24),
          const SizedBox(width: 20),
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
                        border: Border.all(color: isSelected ? kPrimaryColor : Colors.white24),
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

  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _addToCart(product),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Area Immagine estesa
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Qua inseriamo il nuovo widget per l'immagine
                    child: _buildProductImage(product.imageBase64, product.icon, borderRadius: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(product.category, style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("€ ${product.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
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

  Widget _buildCartItem(Product product, int qty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Miniatura dell'immagine per il carrello
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
                color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: _buildProductImage(product.imageBase64, product.icon, borderRadius: 8, isCartItem: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("€ ${product.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
            onPressed: () => _removeFromCart(product),
          ),
          Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle, color: kPrimaryColor),
            onPressed: () => _addToCart(product),
          ),
        ],
      ),
    );
  }

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
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: (_cart.isEmpty || _isSendingOrder) ? null : _submitOrderToFlask,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSendingOrder
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text("PAGA E ORDINA", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}