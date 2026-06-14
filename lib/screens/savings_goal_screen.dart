import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/savings_goal.dart';

class SavingsGoalScreen extends StatefulWidget {
  const SavingsGoalScreen({super.key});

  @override
  State<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends State<SavingsGoalScreen> {
  List<SavingsGoal> _goals = [];

  final Map<String, List<double>> _amountOptions = {
    'daily': [2, 5, 10, 20],
    'weekly': [10, 20, 50, 100],
    'biweekly': [25, 50, 100, 200],
    'monthly': [50, 100, 200, 500],
  };

  final Map<String, String> _frequencyLabels = {
    'daily': 'Diario',
    'weekly': 'Semanal',
    'biweekly': 'Quincenal',
    'monthly': 'Mensual',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await DBHelper.getSavingsGoals();
    setState(() => _goals = goals);
  }

  Future<void> _resetAllGoals() async {
    final goals = await DBHelper.getSavingsGoals();

    for (final goal in goals) {
      await DBHelper.updateSavingsGoal(goal.withResetSchedule());
    }

    await _load();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Metas reiniciadas correctamente')),
    );
  }

  Future<void> _showGoalDialog({SavingsGoal? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController = TextEditingController(
      text: existing?.targetAmount.toString() ?? '',
    );
    final currentController = TextEditingController(
      text: existing?.currentAmount.toString() ?? '0',
    );
    String frequency = existing?.frequency ?? 'weekly';
    double autoAmount = existing?.autoAmount ?? _amountOptions['weekly']!.first;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Editar meta' : 'Nueva meta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la meta',
                    hintText: 'Coloca aquí tu meta',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto objetivo (S/)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ya tengo ahorrado (S/)',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Frecuencia de ahorro',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _frequencyLabels.entries.map((e) {
                    final selected = frequency == e.key;
                    return ChoiceChip(
                      label: Text(e.value),
                      selected: selected,
                      selectedColor: const Color(0xFF1C0EF1),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) {
                        setDialogState(() {
                          frequency = e.key;
                          autoAmount = _amountOptions[frequency]!.first;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Monto a abonar (${_frequencyLabels[frequency]})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _amountOptions[frequency]!.map((amount) {
                    final selected = autoAmount == amount;
                    return ChoiceChip(
                      label: Text('S/ ${amount.toStringAsFixed(0)}'),
                      selected: selected,
                      selectedColor: const Color(0xFF1C0EF1),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) =>
                          setDialogState(() => autoAmount = amount),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C0EF1),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final target = double.tryParse(
                  targetController.text.trim().replaceAll(',', '.'),
                );
                final current =
                    double.tryParse(
                      currentController.text.trim().replaceAll(',', '.'),
                    ) ??
                    0;

                if (name.isEmpty || target == null || target <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Completa todos los campos')),
                  );
                  return;
                }

                final now = DateTime.now();
                final draftGoal = SavingsGoal(
                  id: existing?.id,
                  name: name,
                  targetAmount: target,
                  currentAmount: current,
                  frequency: frequency,
                  autoAmount: autoAmount,
                  startDate: existing?.startDate ?? now,
                  nextPaymentDate: null,
                );
                final goal = SavingsGoal(
                  id: existing?.id,
                  name: name,
                  targetAmount: target,
                  currentAmount: current,
                  frequency: frequency,
                  autoAmount: autoAmount,
                  startDate: existing?.startDate ?? now,
                  nextPaymentDate:
                      existing?.nextPaymentDate ??
                      draftGoal.calculateNextDate(now),
                );

                if (existing != null) {
                  await DBHelper.updateSavingsGoal(goal);
                } else {
                  await DBHelper.insertSavingsGoal(goal);
                }

                if (context.mounted) Navigator.pop(context);
                _load();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C0EF1),
        foregroundColor: Colors.white,
        title: const Text('Metas de ahorro'),
        actions: [
          IconButton(
            tooltip: 'Reset temporal',
            icon: const Icon(Icons.restart_alt),
            onPressed: _resetAllGoals,
          ),
        ],
        elevation: 0,
      ),
      body: _goals.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _goals.length,
              itemBuilder: (ctx, i) => _buildGoalCard(_goals[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1C0EF1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
        onPressed: () => _showGoalDialog(),
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoal goal) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy', 'es');
    final pct = (goal.progress * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: goal.isCompleted
            ? Border.all(color: Colors.green.shade300, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (goal.isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () => _showGoalDialog(existing: goal),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.grey,
                ),
                onPressed: () async {
                  await DBHelper.deleteSavingsGoal(goal.id!);
                  _load();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                goal.isCompleted ? Colors.green : const Color(0xFF1C0EF1),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${fmt.format(goal.currentAmount)} de ${fmt.format(goal.targetAmount)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.repeat, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${_frequencyLabels[goal.frequency]} · S/ ${goal.autoAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              if (!goal.isCompleted) ...[
                const Icon(Icons.flag_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateFmt.format(goal.estimatedDate),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else
                const Text(
                  '¡Meta alcanzada! 🎉',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Sin metas de ahorro',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Toca + para crear tu primera meta',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
