class AppTransaction {
  final int? id; // id de una transacción
  final String title; // titulo de la transacción
  final double amount; // monto de la transacción
  final String type; // tipo de la transacción
  final String category; // categoria de la transacción
  final DateTime date; // fecha de la transacción

  AppTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      type: map['type'],
      category: map['category'],
      date: DateTime.parse(map['date']),
    );
  }
}
