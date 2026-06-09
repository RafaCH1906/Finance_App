import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  List<AppTransaction> _transactions = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final data = await DBHelper.getTransactions();
    setState(() => _transactions = data);
  }

  List<AppTransaction> get _filtered => _transactions.where((t) {
        return t.date.month == _selectedMonth &&
            t.date.year == _selectedYear;
      }).toList();

  double get _totalIncome => _filtered
      .where((t) => t.type == 'income')
      .fold(0, (sum, t) => sum + t.amount);

  double get _totalExpense => _filtered
      .where((t) => t.type == 'expense')
      .fold(0, (sum, t) => sum + t.amount);

  double get _balance => _totalIncome - _totalExpense;

  Map<String, double> get _expenseByCategory {
    final map = <String, double>{};
    for (final t in _filtered.where((t) => t.type == 'expense')) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  final List<Color> _chartColors = [
    const Color(0xFF6C63FF),
    const Color(0xFFFF6584),
    const Color(0xFF43BCCD),
    const Color(0xFFFFBE0B),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
  ];

  void _changeMonth(int delta) {
    setState(() {
      _touchedIndex = null;
      int month = _selectedMonth + delta;
      int year = _selectedYear;
      if (month > 12) { month = 1; year++; }
      if (month < 1) { month = 12; year--; }
      if (year > DateTime.now().year ||
          (year == DateTime.now().year && month > DateTime.now().month)) return;
      _selectedMonth = month;
      _selectedYear = year;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final monthName = DateFormat('MMMM yyyy', 'es').format(
        DateTime(_selectedYear, _selectedMonth));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        title: const Text('Resumen mensual'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildMonthSelector(monthName),
            const SizedBox(height: 16),
            _buildBalanceCard(fmt),
            const SizedBox(height: 16),
            _buildIncomeExpenseRow(fmt),
            const SizedBox(height: 20),
            if (_expenseByCategory.isNotEmpty) ...[
              const Text('Gastos por categoría',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildPieChart(),
              const SizedBox(height: 12),
              _buildLegend(),
            ] else
              _buildEmptyState(),
          ],
        ),
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
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildBalanceCard(NumberFormat fmt) {
    final isPositive = _balance >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Balance del mes',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            fmt.format(_balance),
            style: TextStyle(
              color: isPositive ? Colors.greenAccent : Colors.redAccent,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseRow(NumberFormat fmt) {
    return Row(
      children: [
        Expanded(child: _statCard('Ingresos', fmt.format(_totalIncome),
            Colors.green, Icons.arrow_downward)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Gastos', fmt.format(_totalExpense),
            Colors.red, Icons.arrow_upward)),
      ],
    );
  }

  Widget _statCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(color: color, fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final categories = _expenseByCategory.entries.toList();
    final total = _totalExpense;

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = null;
                  return;
                }
                _touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          sections: List.generate(categories.length, (i) {
            final isTouched = i == _touchedIndex;
            final pct = total > 0
                ? (categories[i].value / total * 100)
                : 0.0;
            return PieChartSectionData(
              color: _chartColors[i % _chartColors.length],
              value: categories[i].value,
              title: '${pct.toStringAsFixed(1)}%',
              radius: isTouched ? 70 : 55,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final categories = _expenseByCategory.entries.toList();
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return Column(
      children: List.generate(categories.length, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: _chartColors[i % _chartColors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(categories[i].key,
                    style: const TextStyle(fontSize: 14)),
              ),
              Text(fmt.format(categories[i].value),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        );
      }),
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
          Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Sin gastos este mes',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }
}