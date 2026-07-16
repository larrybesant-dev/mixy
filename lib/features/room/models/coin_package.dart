/// Represents a purchasable coin package.
class CoinPackage {
  final String id;
  final int coins;
  final double priceUSD;
  final String displayName;
  final bool isPopular;

  const CoinPackage({
    required this.id,
    required this.coins,
    required this.priceUSD,
    required this.displayName,
    this.isPopular = false,
  });

  double get costPerCoin => priceUSD / coins;

  @override
  String toString() =>
      'CoinPackage(id: $id, coins: $coins, price: \$$priceUSD, name: $displayName)';
}

/// Predefined coin packages available for purchase.
class CoinCatalog {
  static const List<CoinPackage> packages = [
    CoinPackage(
      id: 'coins_50',
      coins: 50,
      priceUSD: 4.99,
      displayName: '50 Coins',
      isPopular: false,
    ),
    CoinPackage(
      id: 'coins_120',
      coins: 120,
      priceUSD: 9.99,
      displayName: '120 Coins',
      isPopular: true, // ~24% bonus
    ),
    CoinPackage(
      id: 'coins_350',
      coins: 350,
      priceUSD: 24.99,
      displayName: '350 Coins',
      isPopular: false, // ~28% bonus
    ),
    CoinPackage(
      id: 'coins_750',
      coins: 750,
      priceUSD: 49.99,
      displayName: '750 Coins',
      isPopular: false, // ~30% bonus
    ),
  ];

  static CoinPackage? findById(String id) {
    try {
      return packages.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
