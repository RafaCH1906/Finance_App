import '../database/db_helper.dart';
import '../models/transaction.dart';
import 'notification_service.dart';

class SavingsService {
  static Future<void> processPendingGoals() async {
    final goals = await DBHelper.getPendingGoals();

    for (final goal in goals) {
      var currentGoal = goal;

      while (!currentGoal.isCompleted &&
          currentGoal.nextPaymentDate != null &&
          !currentGoal.nextPaymentDate!.isAfter(DateTime.now())) {
        final abono = currentGoal.autoAmount.clamp(0.0, currentGoal.remaining);
        final abonoDate = currentGoal.nextPaymentDate!;
        final newAmount = currentGoal.currentAmount + abono;
        final nextDate = currentGoal.calculateNextDate(abonoDate);

        final transaction = AppTransaction(
          title: 'Ahorro automático - ${currentGoal.name}',
          amount: abono,
          type: 'expense',
          category: 'Ahorro',
          date: abonoDate,
        );
        await DBHelper.insertTransaction(transaction);

        currentGoal = currentGoal.copyWith(
          currentAmount: newAmount,
          nextPaymentDate: newAmount >= currentGoal.targetAmount
              ? null
              : nextDate,
        );
        await DBHelper.updateSavingsGoal(currentGoal);
      }

      if (currentGoal.currentAmount > goal.currentAmount) {
        await NotificationService.showSavingsNotification(
          goalName: goal.name,
          amount: currentGoal.currentAmount - goal.currentAmount,
          currentAmount: currentGoal.currentAmount,
          targetAmount: goal.targetAmount,
        );
      }
    }
  }
}
