import '../database/db_helper.dart';
import '../models/transaction.dart';
import 'notification_service.dart';

class SavingsService {
  static Future<void> processPendingGoals() async {
    final goals = await DBHelper.getPendingGoals();

    for (final goal in goals) {
      final abono = goal.autoAmount.clamp(0.0, goal.remaining);
      final newAmount = goal.currentAmount + abono;
      final nextDate = goal.calculateNextDate(DateTime.now());

      // Registra como gasto en transacciones
      final transaction = AppTransaction(
        title: 'Ahorro automático - ${goal.name}',
        amount: abono,
        type: 'expense',
        category: 'Ahorro',
        date: DateTime.now(),
      );
      await DBHelper.insertTransaction(transaction);

      // Actualiza la meta
      final updated = goal.copyWith(
        currentAmount: newAmount,
        nextPaymentDate: newAmount >= goal.targetAmount ? null : nextDate,
      );
      await DBHelper.updateSavingsGoal(updated);

      // Envía notificación
      await NotificationService.showSavingsNotification(
        goalName: goal.name,
        amount: abono,
        currentAmount: newAmount,
        targetAmount: goal.targetAmount,
      );
    }
  }
}