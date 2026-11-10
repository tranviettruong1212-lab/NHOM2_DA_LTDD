import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/api_client.dart';
import '../services/app_backends.dart';
import '../services/recurring_api_service.dart';

class RecurringTransactionFormScreen extends StatefulWidget {
  final RecurringTransaction? recurring;

  const RecurringTransactionFormScreen({super.key, this.recurring});

  @override
  State<RecurringTransactionFormScreen> createState() =>
      _RecurringTransactionFormScreenState();
}

class _RecurringTransactionFormScreenState
    extends State<RecurringTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = RecurringApiService.instance;
  final _api = ApiClient.instance;

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late TransactionType _type;
  late RecurrenceFrequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  late DateTime _nextDueDate;
  late bool _autoCreate;
  bool _hasEndDate = false;

  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _householdId;
  String? _householdName;
  bool _isHousehold = false;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loadingDependencies = true;
  bool _saving = false;

  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recurring;

    _titleController = TextEditingController(text: r?.title ?? '');
    _amountController = TextEditingController(
      text: r != null ? r.amount.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: r?.note ?? '');

    _type = r?.type ?? TransactionType.expense;
    _frequency = r?.frequency ?? RecurrenceFrequency.monthly;
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate;
    _hasEndDate = r?.endDate != null;
    _nextDueDate = r?.nextDueDate ?? DateTime.now();
    _autoCreate = r?.autoCreate ?? true;
    _selectedAccountId = r?.accountId;
    _selectedCategoryId = r?.categoryId;
    _isHousehold = r?.householdId != null;

    _amountController.addListener(() => setState(() {}));
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loadingDependencies = true);
    try {
      final accountsFuture = _service.getAccounts();
      final typeVal = _type == TransactionType.income ? 1 : 0;
      final categoriesFuture = _service.getCategories(typeVal);
      final householdFuture = _loadHouseholdInfo();

      final results = await Future.wait([accountsFuture, categoriesFuture, householdFuture]);
      final accounts = results[0] as List<Map<String, dynamic>>;
      final categories = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _categories = categories;

          // Default account
          if (_selectedAccountId == null && _accounts.isNotEmpty) {
            _selectedAccountId = (_accounts.first['id'] ?? _accounts.first['Id'])?.toString();
          }

          // Default category
          if (_selectedCategoryId == null && _categories.isNotEmpty) {
            _selectedCategoryId = (_categories.first['id'] ?? _categories.first['Id'])?.toString();
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDependencies = false);
    }
  }

  Future<void> _loadHouseholdInfo() async {
    try {
      final res = await _api.get('/api/households/mine');
      if (res is Map && mounted) {
        final id = (res['householdId'] ?? res['HouseholdId'])?.toString();
        final name = (res['householdName'] ?? res['HouseholdName'])?.toString();
        if (id != null && id.isNotEmpty) {
          _householdId = id;
          _householdName = name ?? 'Gia đình';
        }
      }
    } catch (_) {}
  }

  Future<void> _onTypeChanged(TransactionType newType) async {
    if (newType == _type) return;
    setState(() {
      _type = newType;
      _selectedCategoryId = null;
      _loadingDependencies = true;
    });

    try {
      final typeVal = _type == TransactionType.income ? 1 : 0;
      final cats = await _service.getCategories(typeVal);
      if (mounted) {
        setState(() {
          _categories = cats;
          if (_categories.isNotEmpty) {
            _selectedCategoryId = (_categories.first['id'] ?? _categories.first['Id'])?.toString();
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingDependencies = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (!_isEditing && _nextDueDate.isBefore(_startDate)) {
          _nextDueDate = picked;
        }
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickNextDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _nextDueDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ (> 0).')),
      );
      return;
    }

    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn tài khoản/nguồn tiền.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final payload = {
        'title': title,
        'amount': amount,
        'type': _type == TransactionType.income ? 1 : 0,
        'frequency': _frequency.index,
        'startDate': _startDate.toIso8601String(),
        'endDate': _hasEndDate && _endDate != null ? _endDate!.toIso8601String() : null,
        'nextDueDate': _nextDueDate.toIso8601String(),
        'accountId': _selectedAccountId,
        'categoryId': _selectedCategoryId,
        'householdId': _isHousehold && _householdId != null ? _householdId : null,
        'autoCreate': _autoCreate,
        'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      };

      if (_isEditing) {
        await _service.updateRecurring(widget.recurring!.id, payload);
      } else {
        await _service.createRecurring(payload);
      }

      await MoneyMateBackend.instance.loadFromApi();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Đã cập nhật khoản định kỳ "$title"'
                  : 'Đã thêm khoản định kỳ "$title"',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được khoản định kỳ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final previewAmount =
        double.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa khoản định kỳ' : 'Thêm khoản định kỳ'),
      ),
      body: _loadingDependencies
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Segmented control: Chi tiêu vs Thu nhập
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Khoản chi định kỳ'),
                        icon: Icon(Icons.arrow_upward, color: Colors.red),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Khoản thu định kỳ'),
                        icon: Icon(Icons.arrow_downward, color: Colors.green),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (set) => _onTypeChanged(set.first),
                  ),

                  const SizedBox(height: 16),

                  // Tiêu đề
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tên khoản định kỳ',
                      hintText: 'VD: Tiền nhà, Internet, Tiền điện, Netflix, Lương...',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                  ),

                  const SizedBox(height: 16),

                  // Số tiền
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Số tiền mỗi kỳ (VNĐ)',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      border: const OutlineInputBorder(),
                      helperText: previewAmount > 0
                          ? 'Bằng số: ${CurrencyFormat.format(previewAmount)}'
                          : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số tiền';
                      final parsed = double.tryParse(v.replaceAll(',', '').trim());
                      if (parsed == null || parsed <= 0) return 'Số tiền không hợp lệ';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Chu kỳ lặp lại
                  DropdownButtonFormField<RecurrenceFrequency>(
                    value: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Chu kỳ lặp lại',
                      prefixIcon: Icon(Icons.repeat),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RecurrenceFrequency.daily,
                        child: Text('Hàng ngày'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceFrequency.weekly,
                        child: Text('Hàng tuần'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceFrequency.monthly,
                        child: Text('Hàng tháng'),
                      ),
                      DropdownMenuItem(
                        value: RecurrenceFrequency.yearly,
                        child: Text('Hàng năm'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _frequency = v);
                    },
                  ),

                  const SizedBox(height: 16),

                  // Danh mục
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((c) {
                      final id = (c['id'] ?? c['Id']).toString();
                      final name = (c['name'] ?? c['Name'] ?? 'Khác').toString();
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
                  ),

                  const SizedBox(height: 16),

                  // Tài khoản / Nguồn tiền
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(
                      labelText: 'Nguồn tiền / Tài khoản',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _accounts.map((a) {
                      final id = (a['id'] ?? a['Id']).toString();
                      final name = (a['name'] ?? a['Name'] ?? 'Tài khoản').toString();
                      return DropdownMenuItem(value: id, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    validator: (v) => v == null ? 'Vui lòng chọn tài khoản' : null,
                  ),

                  const SizedBox(height: 16),

                  // Ngày bắt đầu & Ngày tới hạn
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: const Text('Ngày bắt đầu'),
                            subtitle: Text(_formatDate(_startDate)),
                            trailing: TextButton(
                              onPressed: _pickStartDate,
                              child: const Text('Chọn'),
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_outlined),
                            title: const Text('Ngày tới hạn tiếp theo'),
                            subtitle: Text(_formatDate(_nextDueDate)),
                            trailing: TextButton(
                              onPressed: _pickNextDueDate,
                              child: const Text('Chọn'),
                            ),
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Đặt ngày kết thúc'),
                            subtitle: _hasEndDate && _endDate != null
                                ? Text('Kết thúc: ${_formatDate(_endDate!)}')
                                : const Text('Lặp vô hạn cho tới khi tạm dừng'),
                            value: _hasEndDate,
                            onChanged: (v) {
                              setState(() {
                                _hasEndDate = v;
                                if (_hasEndDate && _endDate == null) {
                                  _endDate = _startDate.add(const Duration(days: 365));
                                }
                              });
                              if (_hasEndDate) _pickEndDate();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tự động sinh giao dịch
                  Card(
                    child: SwitchListTile(
                      secondary: Icon(
                        _autoCreate ? Icons.autorenew : Icons.touch_app_outlined,
                        color: _autoCreate ? Colors.blue : Colors.grey,
                      ),
                      title: const Text('Tự động ghi nhận khi đến hạn'),
                      subtitle: Text(
                        _autoCreate
                            ? 'Hệ thống tự động tạo giao dịch khi tới ngày đến hạn.'
                            : 'Nhắc nhở bạn xác nhận thủ công trước khi ghi nhận.',
                      ),
                      value: _autoCreate,
                      onChanged: (v) => setState(() => _autoCreate = v),
                    ),
                  ),

                  // Chia sẻ hộ gia đình nếu có
                  if (_householdId != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: SwitchListTile(
                        secondary: const Icon(Icons.group_outlined, color: Color(0xFF2457C5)),
                        title: Text('Khoản chi chung cho $_householdName'),
                        subtitle: const Text('Các thành viên trong gia đình có thể theo dõi.'),
                        value: _isHousehold,
                        onChanged: (v) => setState(() => _isHousehold = v),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Ghi chú
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú (tùy chọn)',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nút Lưu
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isEditing ? 'Cập nhật khoản định kỳ' : 'Tạo khoản định kỳ'),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}

