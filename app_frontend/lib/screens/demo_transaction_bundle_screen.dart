import 'dart:math';

import 'package:flutter/material.dart';

import '../models/bank_wallet.dart';
import '../models/transaction_model.dart';
import '../services/app_backends.dart';
import '../services/transaction_api_service.dart';

class DemoTransactionBundleScreen extends StatefulWidget {
  const DemoTransactionBundleScreen({super.key});

  @override
  State<DemoTransactionBundleScreen> createState() =>
      _DemoTransactionBundleScreenState();
}

class _DemoTransactionBundleScreenState
    extends State<DemoTransactionBundleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _backend = MoneyMateBackend.instance;
  final _transactionApi = TransactionApiService.instance;
  final List<_DemoEntryFormData> _entries = [];

  WalletType _walletType = WalletType.bank;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addEntry();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    final entry = _DemoEntryFormData();
    setState(() => _entries.add(entry));
    _loadCategories(entry);
  }

  Future<void> _loadCategories(_DemoEntryFormData entry) async {
    final requestVersion = ++entry.categoryRequestVersion;
    final requestedType = entry.type;
    setState(() {
      entry.loadingCategories = true;
      entry.categoryError = null;
      entry.categoryId = null;
      entry.categories = [];
    });
    try {
      final categories = await _transactionApi.getCategoriesForType(
        requestedType,
      );
      if (!mounted ||
          !_entries.contains(entry) ||
          requestVersion != entry.categoryRequestVersion) {
        return;
      }
      setState(() {
        entry.categories = categories;
        entry.loadingCategories = false;
      });
    } catch (error) {
      if (!mounted ||
          !_entries.contains(entry) ||
          requestVersion != entry.categoryRequestVersion) {
        return;
      }
      setState(() {
        entry.categoryError = error.toString();
        entry.loadingCategories = false;
      });
    }
  }

  Future<void> _pickDate(_DemoEntryFormData entry) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => entry.date = selected);
    }
  }

  void _removeEntry(_DemoEntryFormData entry) {
    if (_entries.length == 1) return;
    setState(() => _entries.remove(entry));
    entry.dispose();
  }

  double? _parseAmount(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'[.,\s]'), '');
    final amount = double.tryParse(normalized);
    return amount != null && amount.isFinite && amount > 0 ? amount : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_entries.any((entry) => entry.loadingCategories)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải danh mục, vui lòng thử lại.')),
      );
      return;
    }
    if (_entries.any(
      (entry) => entry.categoryError != null || entry.categories.isEmpty,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần tải được danh mục trước khi lưu giao dịch.'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final accountName = _accountNameController.text.trim();
    final entries = _entries
        .map(
          (entry) => DemoTransactionEntry(
            idempotencyKey: entry.idempotencyKey,
            title: entry.titleController.text.trim(),
            type: entry.type,
            amount: _parseAmount(entry.amountController.text)!,
            categoryId: entry.categoryId!,
            date: entry.date,
            note: entry.noteController.text.trim(),
          ),
        )
        .toList();

    setState(() => _saving = true);
    try {
      final created = await _backend.createDemoTransactionBundle(
        accountName: accountName,
        walletType: _walletType,
        entries: entries,
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được bộ giao dịch mẫu: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo giao dịch mẫu')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Thông tin ngân hàng/ví điện tử',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNameController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Tên ngân hàng hoặc ví điện tử',
                hintText: 'Ví dụ: MoMo Demo',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tên ngân hàng hoặc ví điện tử.'
                  : null,
            ),
            const SizedBox(height: 8),
            SegmentedButton<WalletType>(
              segments: const [
                ButtonSegment(
                  value: WalletType.bank,
                  label: Text('Ngân hàng'),
                  icon: Icon(Icons.account_balance),
                ),
                ButtonSegment(
                  value: WalletType.eWallet,
                  label: Text('Ví điện tử'),
                  icon: Icon(Icons.account_balance_wallet),
                ),
              ],
              selected: {_walletType},
              onSelectionChanged: _saving
                  ? null
                  : (selection) =>
                        setState(() => _walletType = selection.first),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Danh sách giao dịch',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _addEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm giao dịch'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _entries.length; index++)
              _buildEntryCard(_entries[index], index),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Đang lưu...' : 'Tạo bộ giao dịch mẫu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(_DemoEntryFormData entry, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Giao dịch ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_entries.length > 1)
                  IconButton(
                    tooltip: 'Xóa giao dịch',
                    onPressed: _saving ? null : () => _removeEntry(entry),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Thu nhập'),
                  icon: Icon(Icons.south_west),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Chi tiêu'),
                  icon: Icon(Icons.north_east),
                ),
              ],
              selected: {entry.type},
              onSelectionChanged: _saving
                  ? null
                  : (selection) {
                      setState(() => entry.type = selection.first);
                      _loadCategories(entry);
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: entry.titleController,
              decoration: const InputDecoration(
                labelText: 'Tên giao dịch',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tên giao dịch.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: entry.amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Số tiền (VNĐ)',
                hintText: 'Ví dụ: 200000',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _parseAmount(value ?? '') == null
                  ? 'Số tiền phải lớn hơn 0.'
                  : null,
            ),
            const SizedBox(height: 12),
            if (entry.loadingCategories)
              const LinearProgressIndicator()
            else if (entry.categoryError != null)
              Text(
                'Không tải được danh mục: ${entry.categoryError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey(
                  '${entry.idempotencyKey}-${entry.type}-${entry.categories.length}',
                ),
                initialValue: entry.categoryId,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                ),
                items: entry.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: (category['id'] ?? category['Id']).toString(),
                        child: Text(
                          (category['name'] ?? category['Name'] ?? '')
                              .toString(),
                        ),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng chọn danh mục.'
                    : null,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => entry.categoryId = value),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickDate(entry),
              icon: const Icon(Icons.calendar_month),
              label: Text(
                'Ngày giao dịch: ${entry.date.day}/${entry.date.month}/${entry.date.year}',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoEntryFormData {
  _DemoEntryFormData()
    : idempotencyKey = _createIdempotencyKey(),
      date = DateTime.now();

  final String idempotencyKey;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  TransactionType type = TransactionType.expense;
  DateTime date;
  List<Map<String, dynamic>> categories = [];
  String? categoryId;
  String? categoryError;
  bool loadingCategories = true;
  int categoryRequestVersion = 0;

  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
  }

  static String _createIdempotencyKey() {
    final random = Random.secure().nextInt(0x7fffffff);
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
        '${random.toRadixString(16)}';
  }
}
