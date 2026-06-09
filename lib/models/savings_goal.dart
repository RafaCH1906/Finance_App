class SavingsGoal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String frequency;  // 'daily', 'weekly', 'biweekly', 'monthly'
  final double autoAmount;
  final DateTime startDate;
  final DateTime? nextPaymentDate;

  SavingsGoal({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.frequency,
    required this.autoAmount,
    required this.startDate,
    this.nextPaymentDate,
  });

  double get progress => (currentAmount / targetAmount).clamp(0.0, 1.0);
  bool get isCompleted => currentAmount >= targetAmount;
  double get remaining => (targetAmount - currentAmount).clamp(0.0, double.infinity);

  DateTime calculateNextDate(DateTime from) {
    switch (frequency) {
      case 'daily':    return from.add(const Duration(days: 1));
      case 'weekly':   return from.add(const Duration(days: 7));
      case 'biweekly': return from.add(const Duration(days: 15));
      case 'monthly':  return DateTime(from.year, from.month + 1, from.day);
      default:         return from.add(const Duration(days: 7));
    }
  }

  int get paymentsRemaining {
    if (isCompleted) return 0;
    return (remaining / autoAmount).ceil();
  }

  DateTime get estimatedDate {
    DateTime date = nextPaymentDate ?? DateTime.now();
    int payments = paymentsRemaining;
    for (int i = 0; i < payments; i++) {
      date = calculateNextDate(date);
    }
    return date;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'frequency': frequency,
      'auto_amount': autoAmount,
      'start_date': startDate.toIso8601String(),
      'next_payment_date': nextPaymentDate?.toIso8601String(),
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      name: map['name'],
      targetAmount: map['target_amount'],
      currentAmount: map['current_amount'],
      frequency: map['frequency'],
      autoAmount: map['auto_amount'],
      startDate: DateTime.parse(map['start_date']),
      nextPaymentDate: map['next_payment_date'] != null
          ? DateTime.parse(map['next_payment_date'])
          : null,
    );
  }

  SavingsGoal copyWith({
    double? currentAmount,
    DateTime? nextPaymentDate,
  }) {
    return SavingsGoal(
      id: id,
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      frequency: frequency,
      autoAmount: autoAmount,
      startDate: startDate,
      nextPaymentDate: nextPaymentDate ?? this.nextPaymentDate,
    );
  }
}