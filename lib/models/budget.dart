class Budget {
  final int? id;
  final String category;
  final double limitAmount;
  final int month;
  final int year;

  Budget({
    this.id,
    required this.category,
    required this.limitAmount,
    required this.month,
    required this.year,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'limit_amount': limitAmount,
      'month': month,
      'year': year,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      limitAmount: map['limit_amount'],
      month: map['month'],
      year: map['year'],
    );
  }
}