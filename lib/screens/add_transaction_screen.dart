import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import '../models/app_database.dart';

class AddTransactionScreen extends StatefulWidget {
  final AppDatabase db;
  final Transaction? transaction;
  const AddTransactionScreen({Key? key, required this.db, this.transaction}) : super(key: key);

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late CategoryType _type;
  int? _selectedCategoryId;
  late DateTime _date;
  late TextEditingController _descController;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx != null
        ? CategoryType.values.firstWhere((e) => e.name == tx.type)
        : CategoryType.Expense;
    _selectedCategoryId = tx?.categoryId;
    _date = tx?.date ?? DateTime.now();
    _descController = TextEditingController(text: tx?.description);
    _amountController = TextEditingController(
      text: tx != null ? tx.amount.toString() : '',
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final desc = _descController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    if (widget.transaction == null) {
      await widget.db.into(widget.db.transactions).insert(
        TransactionsCompanion(
          categoryId: Value(_selectedCategoryId!),
          type: Value(_type.name),
          date: Value(_date),
          description: Value(desc),
          amount: Value(amount),
        ),
      );
    } else {
      final updated = Transaction(
        id: widget.transaction!.id,
        categoryId: _selectedCategoryId,
        type: _type.name,
        date: _date,
        description: desc,
        amount: amount,
      );
      await widget.db.update(widget.db.transactions).replace(updated);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Add Transaction' : 'Edit Transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<CategoryType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: CategoryType.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (val) => setState(() {
                  _type = val!;
                  _selectedCategoryId = null;
                }),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Category>>(
                stream: widget.db.select(widget.db.categories).watch(),
                builder: (ctx, snap) {
                  final cats = (snap.data ?? [])
                      .where((c) => c.type == _type.name)
                      .toList();
                  return DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: cats
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                    validator: (v) => v == null ? 'Select category' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(DateFormat.yMMMd().format(_date)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => v?.isEmpty == true ? 'Enter description' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter amount';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
