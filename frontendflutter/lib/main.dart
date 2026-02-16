import 'package:flutter/material.dart';

void main() {
  runApp(const SmashBossApp());
}

// --- COSTANTI DI STILE (Estratte dall'immagine) ---
const Color kBackgroundColor = Color(0xFF0D0D0D); // Nero profondo
const Color kSurfaceColor = Color(0xFF1E1E1E);    // Grigio scuro card
const Color kPrimaryColor = Color(0xFFFF9F00);    // Arancione SmashBoss
const Color kTextColor = Colors.white;
const Color kSubTextColor = Colors.grey;

// --- DATA MODEL ---
class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final IconData icon; // Uso icone per ora, sostituire con asset immagini

  Product(this.id, this.name, this.category, this.price, this.icon);
}

// --- MOCK DATA ---
final List<Product> _allProducts = [
  Product('1', 'SmashBoss Double', 'PANINI', 10.50, Icons.lunch_dining),
  Product('2', 'Chicken Crunch', 'PANINI', 9.00, Icons.fastfood),
  Product('3', 'Bacon King', 'PANINI', 11.50, Icons.lunch_dining),
  Product('4', 'Patatine Cheddar', 'FRITTI', 5.50, Icons.tapas),
  Product('5', 'Onion Rings', 'FRITTI', 4.50, Icons.donut_large),
  Product('6', 'Coca Cola', 'BEVANDE', 3.00, Icons.local_drink),
  Product('7', 'Birra Ichnusa', 'BEVANDE', 4.50, Icons.sports_bar),
  Product('8', 'Acqua Nat.', 'BEVANDE', 1.50, Icons.water_drop),
];

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
        fontFamily: 'Roboto', // Ideale: usare un font come 'Anton' o 'Impact'
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

  // Filtra i prodotti
  List<Product> get _visibleProducts {
    if (_selectedCategory == 'TUTTE') return _allProducts;
    return _allProducts.where((p) => p.category == _selectedCategory).toList();
  }

  // Calcola Totale
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- COLONNA SINISTRA: MENU E CATEGORIE ---
          Expanded(
            flex: 7, // 70% dello schermo
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildCategorySelector(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 3 colonne di prodotti
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _visibleProducts.length,
                    itemBuilder: (context, index) {
                      final product = _visibleProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
                ),
              ],
            ),
          ),

          // --- COLONNA DESTRA: CARRELLO ---
          Expanded(
            flex: 3, // 30% dello schermo
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
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shopping_cart_outlined,
                                    size: 60, color: Colors.white24),
                                const SizedBox(height: 10),
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
                  _buildCheckoutSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // HEADER (Logo e Titolo)
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 50, 30, 20),
      child: Row(
        children: [
          Icon(Icons.lunch_dining, color: kPrimaryColor, size: 40),
          const SizedBox(width: 15),
          const Text(
            "SMASHBOSS",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  // BARRA CATEGORIE
  Widget _buildCategorySelector() {
    final categories = ['TUTTE', 'PANINI', 'FRITTI', 'BEVANDE'];
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 15),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? kPrimaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isSelected ? kPrimaryColor : Colors.white24),
              ),
              child: Center(
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
        },
      ),
    );
  }

  // CARD PRODOTTO
  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
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
                Text(
                  product.category,
                  style: const TextStyle(
                      color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "€ ${product.price.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                      ),
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

  // ELEMENTO CARRELLO
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
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle, color: kPrimaryColor),
            onPressed: () => _addToCart(product),
          ),
        ],
      ),
    );
  }

  // SEZIONE CHECKOUT
  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
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
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _cart.isEmpty ? null : () {
                // Azione Checkout
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("ORDINE INVIATO IN CUCINA! 🍔🔥"),
                    backgroundColor: kPrimaryColor,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "VAI AL PAGAMENTO",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}