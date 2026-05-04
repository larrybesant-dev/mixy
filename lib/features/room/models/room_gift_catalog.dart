class RoomGiftItem {
  final String id;
  final String displayName;
  final String emoji;
  final int coinCost;

  const RoomGiftItem({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.coinCost,
  });
}

class RoomGiftCatalog {
  RoomGiftCatalog._();

  static const List<RoomGiftItem> items = [
    RoomGiftItem(id: 'rose', displayName: 'Rose', emoji: '🌹', coinCost: 5),
    RoomGiftItem(id: 'heart', displayName: 'Heart', emoji: '💖', coinCost: 10),
    RoomGiftItem(
      id: 'mic',
      displayName: 'Golden Mic',
      emoji: '🎤',
      coinCost: 15,
    ),
    RoomGiftItem(id: 'star', displayName: 'Star', emoji: '⭐', coinCost: 25),
    RoomGiftItem(id: 'fire', displayName: 'Fire', emoji: '🔥', coinCost: 30),
    RoomGiftItem(id: 'crown', displayName: 'Crown', emoji: '👑', coinCost: 50),
    RoomGiftItem(
      id: 'diamond',
      displayName: 'Diamond',
      emoji: '💎',
      coinCost: 100,
    ),
    RoomGiftItem(
      id: 'rocket',
      displayName: 'Rocket',
      emoji: '🚀',
      coinCost: 200,
    ),
  ];

  static RoomGiftItem? findById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
