import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<Budget> _budgets = [];
  List<AppTransaction> _transactions = [];
  List<String> _allCategories = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await DBHelper.getBudgets(_selectedMonth, _selectedYear);
    final transactions = await DBHelper.getTransactions();
    final custom = await DBHelper.getSavedCategories();
    setState(() {
      _budgets = budgets;
      _transactions = transactions;
      _allCategories = [...DBHelper.defaultCategories, ...custom];
    });
  }

  double _spentInCategory(String category) {
    return _transactions
        .where((t) =>
    t.type == 'expense' &&
        t.category == category &&
        t.date.month == _selectedMonth &&
        t.date.year == _selectedYear)
        .fold(0, (sum, t) => sum + t.amount);
  }

  void _changeMonth(int delta) {
    setState(() {
      int month = _selectedMonth + delta;
      int year = _selectedYear;
      if (month > 12) { month = 1; year++; }
      if (month < 1) { month = 12; year--; }
      if (year > DateTime.now().year ||
          (year == DateTime.now().year && month > DateTime.now().month)) return;
      _selectedMonth = month;
      _selectedYear = year;
    });
    _load();
  }

  Future<void> _showBudgetDialog({Budget? existing, String? preCategory}) async {
    final amountController = TextEditingController(
      text: existing != null ? existing.limitAmount.toString() : '',
    );
    String selectedCategory = preCategory ??
        existing?.category ??
        _allCategories.first;

    final categoriesWithoutBudget = _allCategories.where((c) {
      if (existing != null && c == existing.category) return true;
      return !_budgets.any((b) => b.category == c);
    }).toList();

    if (categoriesWithoutBudget.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas las categorías ya tienen presupuesto')),
      );
      return;
    }

    if (!categoriesWithoutBudget.contains(selectedCategory)) {
      selectedCategory = categoriesWithoutBudget.first;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Editar presupuesto' : 'Nuevo presupuesto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: categoriesWithoutBudget
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: existing != null
                    ? null
                    : (v) => setDialogState(() => selectedCategory = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Límite mensual (S/)',
                  hintText: '0.00',
                ),
              ),
            ],
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
                final amount = double.tryParse(
                    amountController.text.trim().replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un monto válido')),
                  );
                  return;
                }
                final budget = Budget(
                  id: existing?.id,
                  category: selectedCategory,
                  limitAmount: amount,
                  month: _selectedMonth,
                  year: _selectedYear,
                );
                await DBHelper.upsertBudget(budget);
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
    final monthName = DateFormat('MMMM yyyy', 'es')
        .format(DateTime(_selectedYear, _selectedMonth));
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C0EF1),
        foregroundColor: Colors.white,
        title: const Text('Presupuestos'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMonthSelector(monthName),
            const SizedBox(height: 16),
            if (_budgets.isEmpty)
              _buildEmptyState()
            else
              ..._budgets.map((b) => _buildBudgetCard(b, fmt)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1C0EF1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo presupuesto'),
        onPressed: () => _showBudgetDialog(),
      ),
    );
  }

  Widget _buildMonthSelector(String monthName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
          style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
        Text(
          monthName[0].toUpperCase() + monthName.substring(1),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
          style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(Budget budget, NumberFormat fmt) {
    final spent = _spentInCategory(budget.category);
    final progress = (spent / budget.limitAmount).clamp(0.0, 1.0);
    final isOver = spent > budget.limitAmount;
    final isWarning = progress >= 0.8 && !isOver;

    Color progressColor = const Color(0xFF1C0EF1);
    if (isWarning) progressColor = Colors.orange;
    if (isOver) progressColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOver
            ? Border.all(color: Colors.red.shade200, width: 1.5)
            : isWarning
            ? Border.all(color: Colors.orange.shade200, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(budget.category,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              if (isOver)
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 18),
              if (isWarning)
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: Colors.grey),
                onPressed: () => _showBudgetDialog(existing: budget),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.grey),
                onPressed: () async {
                  await DBHelper.deleteBudget(budget.id!);
                  _load();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gastado: ${fmt.format(spent)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: isOver ? Colors.red : Colors.grey.shade600)),
              Text('Límite: ${fmt.format(budget.limitAmount)}',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.grey)),
            ],
          ),
          if (isOver)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Superaste el límite por ${fmt.format(spent - budget.limitAmount)}',
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          if (isWarning)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Estás al ${(progress * 100).toStringAsFixed(0)}% del límite',
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Sin presupuestos este mes',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
          SizedBox(height: 6),
          Text('Toca + para crear uno',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}