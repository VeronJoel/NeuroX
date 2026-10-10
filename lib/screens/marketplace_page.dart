import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'seller_center_page.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _sortBy = 'Featured';
  String _searchQuery = '';

  // Cart is currently stored in memory. Firebase provides the product catalogue.
  final Map<String, int> _cart = {};

  static const Color _green = Color(0xFF287A45);
  static const Color _darkGreen = Color(0xFF174B2B);
  static const Color _lightGreen = Color(0xFFEAF5EC);
  static const Color _background = Color(0xFFF7F9F6);

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      FirebaseFirestore.instance.collection('marketplace_products');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _cartCount => _cart.values.fold(0, (sum, quantity) => sum + quantity);

  double get _cartTotal {
    // The total is recalculated using product prices when the cart is opened.
    return 0;
  }

  List<String> _categories(List<_MarketplaceProduct> products) {
    final categories =
        products
            .map((product) => product.category)
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ['All', ...categories];
  }

  List<_MarketplaceProduct> _filterProducts(
    List<_MarketplaceProduct> products,
  ) {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' ||
          product.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesSearch =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    switch (_sortBy) {
      case 'Price: Low to High':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Top Rated':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        filtered.sort((a, b) {
          if (a.featured != b.featured) {
            return a.featured ? -1 : 1;
          }
          return a.name.compareTo(b.name);
        });
    }

    return filtered;
  }

  void _changeCartQuantity(String productId, int change) {
    setState(() {
      final newQuantity = (_cart[productId] ?? 0) + change;

      if (newQuantity <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = newQuantity;
      }
    });
  }

  void _showProductDetails(_MarketplaceProduct product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 230,
                      child: _ProductImage(product: product),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: _darkGreen,
                          ),
                        ),
                      ),
                      _StockPill(inStock: product.inStock),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.category,
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB300),
                        size: 21,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.rating > 0
                            ? product.rating.toStringAsFixed(1)
                            : 'Not rated yet',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (product.reviewCount > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '(${product.reviewCount} reviews)',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    product.description.isEmpty
                        ? 'A useful addition to your home garden.'
                        : product.description,
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatPrice(product.price),
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: _darkGreen,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: !product.inStock
                            ? null
                            : () {
                                _changeCartQuantity(product.id, 1);
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${product.name} added to cart',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to cart'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openCart(List<_MarketplaceProduct> allProducts) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, updateSheet) {
            final cartProducts = allProducts
                .where((product) => (_cart[product.id] ?? 0) > 0)
                .toList();

            final total = cartProducts.fold<double>(
              0,
              (sum, product) => sum + product.price * (_cart[product.id] ?? 0),
            );

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Your cart',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (cartProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 54,
                              color: _green,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Your cart is empty',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Add some gardening essentials to get started.',
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: cartProducts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final product = cartProducts[index];
                            final quantity = _cart[product.id] ?? 0;

                            return Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 68,
                                    height: 68,
                                    child: _ProductImage(product: product),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        _formatPrice(product.price),
                                        style: const TextStyle(
                                          color: _green,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        _changeCartQuantity(product.id, -1);
                                        updateSheet(() {});
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        _changeCartQuantity(product.id, 1);
                                        updateSheet(() {});
                                      },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        color: _green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    if (cartProducts.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatPrice(total),
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: _darkGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Checkout is not connected yet. '
                                            'Your cart is still available.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                                child: const Text('Continue to checkout'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _productsCollection.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }

            final products = (snapshot.data?.docs ?? [])
                .map((doc) => _MarketplaceProduct.fromFirestore(doc))
                .where((product) => product.active)
                .toList();

            final categories = _categories(products);

            if (!categories.contains(_selectedCategory)) {
              _selectedCategory = 'All';
            }

            final filteredProducts = _filterProducts(products);

            return Column(
              children: [
                _buildHeader(products.length),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                          child: _buildSearchBar(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                          child: _buildFeaturedBanner(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildCategorySelector(categories),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Garden essentials',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: _darkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${filteredProducts.length} products',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                initialValue: _sortBy,
                                tooltip: 'Sort products',
                                onSelected: (value) {
                                  setState(() => _sortBy = value);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'Featured',
                                    child: Text('Featured'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Price: Low to High',
                                    child: Text('Price: Low to High'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Price: High to Low',
                                    child: Text('Price: High to Low'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Top Rated',
                                    child: Text('Top Rated'),
                                  ),
                                  PopupMenuItem(
                                    value: 'Name',
                                    child: Text('Name'),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sort, size: 18),
                                      const SizedBox(width: 5),
                                      Text(
                                        _sortBy,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.expand_more, size: 17),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (products.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyCatalogue(),
                        )
                      else if (filteredProducts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildNoResults(),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.crossAxisExtent;
                              final columns = width >= 1000
                                  ? 4
                                  : width >= 650
                                  ? 3
                                  : 2;

                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: width >= 650
                                          ? 0.70
                                          : 0.57,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _ProductCard(
                                    product: filteredProducts[index],
                                    quantity:
                                        _cart[filteredProducts[index].id] ?? 0,
                                    onTap: () => _showProductDetails(
                                      filteredProducts[index],
                                    ),
                                    onAdd: () {
                                      final product = filteredProducts[index];
                                      if (!product.inStock) return;

                                      _changeCartQuantity(product.id, 1);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${product.name} added to cart',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                  childCount: filteredProducts.length,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _productsCollection.snapshots(),
        builder: (context, snapshot) {
          final allProducts = (snapshot.data?.docs ?? [])
              .map((doc) => _MarketplaceProduct.fromFirestore(doc))
              .where((product) => product.active)
              .toList();

          return FloatingActionButton.extended(
            onPressed: () => _openCart(allProducts),
            backgroundColor: _darkGreen,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text('Cart ($_cartCount)'),
          );
        },
      ),
    );
  }

  Widget _buildHeader(int productCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: _green,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Green Market',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Everything your garden needs',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.eco_outlined, color: _green, size: 17),
                const SizedBox(width: 5),
                Text(
                  '$productCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search seeds, plants, pots...',
        prefixIcon: const Icon(Icons.search, color: _green),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _green, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_darkGreen, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'GROW SOMETHING GOOD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your garden,\\nyour little paradise.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Find the essentials for your next planting day.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_florist_rounded,
              size: 54,
              color: Color(0xFFD8F2A6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(List<String> categories) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == _selectedCategory;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = category),
            selectedColor: _green,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            side: BorderSide(color: selected ? _green : Colors.grey.shade200),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildEmptyCatalogue() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: _lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: _green,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your marketplace is ready!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products to the marketplace_products collection '
              'in Cloud Firestore to display them here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 55, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No products found',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search or category.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
            const SizedBox(height: 14),
            const Text(
              'Could not load marketplace',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and Firestore rules, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceProduct {
  final String id;
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final double price;
  final double rating;
  final int reviewCount;
  final int stock;
  final bool featured;
  final bool active;

  const _MarketplaceProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.stock,
    required this.featured,
    required this.active,
  });

  bool get inStock => stock > 0;

  factory _MarketplaceProduct.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    double toDouble(dynamic value, {double fallback = 0}) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int toInt(dynamic value, {int fallback = 0}) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool toBool(dynamic value, {bool fallback = true}) {
      if (value is bool) return value;
      return fallback;
    }

    return _MarketplaceProduct(
      id: document.id,
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? 'Other').toString(),
      description: (data['description'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      price: toDouble(data['price']),
      rating: toDouble(data['rating']),
      reviewCount: toInt(data['reviewCount']),
      stock: toInt(data['stock']),
      featured: toBool(data['featured'], fallback: false),
      active: toBool(data['active']),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _MarketplaceProduct product;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _ProductCard({
    required this.product,
    required this.quantity,
    required this.onTap,
    required this.onAdd,
  });

  static const Color _green = Color(0xFF287A45);
  static const Color _darkGreen = Color(0xFF174B2B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(product: product),
                  Positioned(
                    top: 9,
                    left: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (product.featured)
                    const Positioned(
                      top: 9,
                      right: 9,
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFE88C26),
                        size: 23,
                      ),
                    ),
                  if (!product.inStock)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.42),
                        alignment: Alignment.center,
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.isEmpty ? 'Unnamed product' : product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB300),
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          product.rating > 0
                              ? product.rating.toStringAsFixed(1)
                              : 'New',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (product.reviewCount > 0) ...[
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '(${product.reviewCount})',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatPrice(product.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _darkGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: product.inStock
                              ? _green
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(11),
                          child: InkWell(
                            onTap: product.inStock ? onAdd : null,
                            borderRadius: BorderRadius.circular(11),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                quantity > 0
                                    ? Icons.add_shopping_cart
                                    : Icons.add,
                                color: product.inStock
                                    ? Colors.white
                                    : Colors.grey,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final _MarketplaceProduct product;

  const _ProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.imageUrl.trim().isEmpty) {
      return _placeholder();
    }

    return Image.network(
      product.imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          color: const Color(0xFFEAF5EC),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF287A45),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFEAF5EC),
      alignment: Alignment.center,
      child: const Icon(Icons.eco_rounded, color: Color(0xFF75A982), size: 54),
    );
  }
}

class _StockPill extends StatelessWidget {
  final bool inStock;

  const _StockPill({required this.inStock});

  @override
  Widget build(BuildContext context) {
    final color = inStock ? const Color(0xFF287A45) : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        inStock ? 'In stock' : 'Out of stock',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatPrice(double price) {
  return '₹${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}';
}
