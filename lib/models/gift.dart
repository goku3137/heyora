class Gift {
  final String id;
  final String name;
  final String emoji;
  final int coinCost;
  final int diamondValue;

  const Gift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinCost,
    required this.diamondValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'coinCost': coinCost,
      'diamondValue': diamondValue,
    };
  }

  factory Gift.fromMap(Map<String, dynamic> map) {
    return Gift(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      coinCost: map['coinCost'] as int,
      diamondValue: map['diamondValue'] as int,
    );
  }

  static const List<Gift> defaultGifts = [
    Gift(id: 'rose', name: 'Rose', emoji: '🌹', coinCost: 10, diamondValue: 7),
    Gift(id: 'heart', name: 'Love Heart', emoji: '💖', coinCost: 25, diamondValue: 18),
    Gift(id: 'cake', name: 'Party Cake', emoji: '🎂', coinCost: 50, diamondValue: 35),
    Gift(id: 'ring', name: 'Diamond Ring', emoji: '💍', coinCost: 150, diamondValue: 105),
    Gift(id: 'car', name: 'Supercar', emoji: '🏎️', coinCost: 500, diamondValue: 350),
    Gift(id: 'castle', name: 'Royal Castle', emoji: '🏰', coinCost: 1000, diamondValue: 700),
  ];
}
