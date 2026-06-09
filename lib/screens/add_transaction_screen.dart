import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'expense';
  String _category = DBHelper.defaultCategories.first;
  DateTime _date = DateTime.now();
  List<String> _customCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  Future<void> _loadCustomCategories() async {
    final savedCategories = await DBHelper.getSavedCategories();
    if (!mounted) return;
    setState(() {
      _customCategories = savedCategories;
      if (!_allCategories.contains(_category)) {
        _category = DBHelper.defaultCategories.first;
      }
    });
  }

  List<String> get _allCategories => [
    ...DBHelper.defaultCategories,
    ..._customCategories,
    'Otros',
  ];

  Future<String?> _askForCustomCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Escribe el nombre de la categoría',
          ),
          onSubmitted: (_) {
            Navigator.pop(context, controller.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    // Do not explicitly dispose the controller here. Let garbage collection
    // reclaim it after the dialog is removed from the tree to avoid
    // disposing while Flutter still has dependents attached to the widget.
    return result;
  }

  Future<void> _handleCategoryChanged(String? value) async {
    if (value == null) return;

    if (value != 'Otros') {
      setState(() => _category = value);
      return;
    }

    final newCategoryName = await _askForCustomCategory();
    if (newCategoryName == null) {
      if (!mounted) return;
      setState(() => _category = DBHelper.defaultCategories.first);
      return;
    }

    final savedCategory = await DBHelper.addCustomCategory(newCategoryName);
    if (savedCategory == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre de categoría válido')),
      );
      return;
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (!_customCategories.contains(savedCategory)) {
          _customCategories = [..._customCategories, savedCategory]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
        _category = savedCategory;
      });
    });
  }

  Future<int?> _pickYear() async {
    final currentYear = DateTime.now().year;
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecciona un año'),
        children: List.generate(
          currentYear - 2019,
          (index) {
            final year = currentYear - index;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, year),
              child: Text(year.toString()),
            );
          },
        ),
      ),
    );
  }

  Future<int?> _pickMonth(int selectedYear) async {
    const monthNames = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final now = DateTime.now();
    final maxMonth = selectedYear == now.year ? now.month : 12;

    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Selecciona un mes'),
        children: List.generate(
          maxMonth,
          (index) {
            final month = index + 1;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, month),
              child: Text(monthNames[index]),
            );
          },
        ),
      ),
    );
  }

  Future<DateTime?> _showDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDatePickerMode: DatePickerMode.day,
    );
  }

  Future<void> _pickDate() async {
    final selectedYear = await _pickYear();
    if (selectedYear == null) return;

    final selectedMonth = await _pickMonth(selectedYear);
    if (selectedMonth == null) return;

    final now = DateTime.now();
    final firstDate = DateTime(selectedYear, selectedMonth, 1);
    final lastDayOfMonth = DateUtils.getDaysInMonth(selectedYear, selectedMonth);
    var lastDate = DateTime(selectedYear, selectedMonth, lastDayOfMonth);
    if (selectedYear == now.year && selectedMonth == now.month) {
      lastDate = now;
    }

    var initialDay = _date.day;
    if (initialDay > lastDate.day) {
      initialDay = lastDate.day;
    }

    var initialDate = DateTime(selectedYear, selectedMonth, initialDay);
    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await _showDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _date = picked;
    });
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    final rawAmount = _amountController.text.trim().replaceAll(',', '.');
    final parsedAmount = double.tryParse(rawAmount);
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido mayor a 0')),
      );
      return;
    }

    try {
      final t = AppTransaction(
        title: _titleController.text.trim(),
        amount: parsedAmount,
        type: _type,
        category: _category,
        date: _date,
      );
      await DBHelper.insertTransaction(t);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la transaccion')),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C0EF1),
        foregroundColor: Colors.white,
        title: const Text('Nueva transacción'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Tipo'),
            const SizedBox(height: 8),
            Row(
              children: [
                _typeButton('expense', 'Gasto', Colors.red),
                const SizedBox(width: 12),
                _typeButton('income', 'Ingreso', Colors.green),
              ],
            ),
            const SizedBox(height: 20),
            _label('Descripción'),
            const SizedBox(height: 8),
            _input(_titleController, 'Coloca aqui una breve descripcion'),
            const SizedBox(height: 20),
            _label('Monto (S/)'),
            const SizedBox(height: 8),
            _input(
              _amountController,
              '0.00',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _label('Categoría'),
            const SizedBox(height: 8),
            _dropdown(),
            const SizedBox(height: 20),
            _label('Fecha'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Color(0xFF1C0EF1),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd MMM yyyy', 'es').format(_date),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C0EF1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'Guardar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
      color: Colors.black87,
    ),
  );

  Widget _input(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _typeButton(String value, String label, Color color) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          items: _allCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: _handleCategoryChanged,
        ),
      ),
    );
  }
}
