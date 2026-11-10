import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../models/transaction_model.dart';
import '../services/api_client.dart';
import '../services/app_backends.dart';

class TransactionFormScreen extends StatefulWidget {
  final MoneyTransaction? transaction;

  const TransactionFormScreen({super.key, this.transaction});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _backend = MoneyMateBackend.instance;
  final _api = ApiClient.instance;

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late TransactionType _type;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  // Hộ gia đình
  String? _householdId;
  String? _householdName;
  double _approvalThreshold = 1000000.0;
  bool _isHousehold = false;

  final List<String> _categories = [
    'Ăn uống',
    'Di chuyển',
    'Học tập',
    'Mua sắm',
    'Giải trí',
    'Lương',
    'Thưởng',
    'Khác',
  ];

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final t = widget.transaction;

    _titleController = TextEditingController(text: t?.title ?? '');
    _amountController = TextEditingController(
      text: t == null ? '' : t.amount.toStringAsFixed(0),
    );
    _noteController = TextEditingController(text: t?.note ?? '');

    _type = t?.type ?? TransactionType.expense;
    _category = t?.category ?? 'Ăn uống';
    _date = t?.date ?? DateTime.now();
    _isHousehold = t?.isHousehold ?? false;

    _amountController.addListener(() => setState(() {}));
    _loadHouseholdInfo();
  }

  Future<void> _loadHouseholdInfo() async {
    try {
      final res = await _api.get('/api/households/mine');
      if (res is Map && mounted) {
        final id = (res['householdId'] ?? res['HouseholdId'])?.toString();
        final name = (res['householdName'] ?? res['HouseholdName'])?.toString();
        final threshold = (res['approvalThreshold'] ?? res['ApprovalThreshold'] as num?)?.toDouble() ?? 1000000.0;
        if (id != null && id.isNotEmpty) {
          setState(() {
            _householdId = id;
            _householdName = name ?? 'Gia đình';
            _approvalThreshold = threshold;
            if (widget.transaction != null) {
              _isHousehold = widget.transaction!.isHousehold;
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.parse(_amountController.text.trim());
    final transaction = MoneyTransaction(
      id: widget.transaction?.id ?? '',
      title: _titleController.text.trim(),
      amount: parsedAmount,
      type: _type,
      category: _category,
      date: _date,
      note: _noteController.text.trim(),
      isHousehold: _isHousehold && _householdId != null,
      householdId: _isHousehold ? _householdId : null,
    );

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _backend.updateTransaction(transaction);
      } else {
        await _backend.addTransaction(transaction);
      }
      if (mounted) {
        final needsApproval = _isHousehold && _type == TransactionType.expense && parsedAmount > _approvalThreshold;
        if (needsApproval) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giao dịch đã được gửi và đang chờ Trưởng nhóm phê duyệt.'),
              backgroundColor: Color(0xFFD97706),
            ),
          );
        }
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được giao dịch: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final isOverThreshold = _isHousehold && _type == TransactionType.expense && currentAmount > _approvalThreshold;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Chi tiêu'),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Thu nhập'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (values) {
                  setState(() => _type = values.first);
                },
              ),
              const SizedBox(height: 20),

              if (_householdId != null) ...[
                Card(
                  color: const Color(0xFFF1F5F9),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.group_outlined, color: Color(0xFF2457C5)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Phạm vi giao dịch', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                _isHousehold
                                    ? 'Chia sẻ cho nhóm "$_householdName"'
                                    : 'Chỉ lưu trong tài chính cá nhân',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isHousehold,
                          onChanged: (val) => setState(() => _isHousehold = val),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tên giao dịch',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập tên giao dịch'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VNĐ)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');

                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Nhập số tiền lớn hơn 0';
                  }

                  return null;
                },
              ),

              if (isOverThreshold) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Khoản chi này vượt ngưỡng duyệt chi gia đình (${CurrencyFormat.format(_approvalThreshold)}). Giao dịch sẽ được gửi vào danh sách chờ phê duyệt.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text('Ngày: ${_date.day}/${_date.month}/${_date.year}'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _saving
                      ? 'Đang lưu...'
                      : _isEditing
                      ? 'Lưu thay đổi'
                      : 'Thêm giao dịch',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
