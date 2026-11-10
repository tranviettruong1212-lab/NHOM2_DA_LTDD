import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../models/api_budget_model.dart';
import '../services/api_client.dart';
import '../services/app_backends.dart';
import '../services/budget_api_service.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  static const _blue = Color(0xFF2457C5);
  final _service = BudgetApiService.instance;
  List<ApiBudget> _budgets = [];
  List<BudgetCategory> _categories = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getBudgets(),
        _service.getExpenseCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _budgets = results[0] as List<ApiBudget>;
        _categories = results[1] as List<BudgetCategory>;
        _loading = false;
      });
      MoneyMateBackend.instance.setBudgets(_budgets);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _loading = false;
      });
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 0)
        return 'Không kết nối được API. Hãy kiểm tra backend và địa chỉ trong api_config.dart.';
      if (e.statusCode == 404)
        return 'Không tìm thấy endpoint API. Hãy kiểm tra phiên bản backend đang chạy.';
      return e.message;
    }
    return 'Không tải được dữ liệu: $e';
  }

  String _money(num value) => CurrencyFormat.format(value);

  String _periodLabel(int value) => switch (value) {
    1 => 'Hàng tuần',
    2 => 'Hàng năm',
    _ => 'Hàng tháng',
  };
  String _modeLabel(int value) => value == 0 ? 'Dự định' : 'Đang thực hiện';
  String _priorityLabel(int value) => switch (value) {
    2 => 'Ưu tiên cao',
    0 => 'Ưu tiên thấp',
    _ => 'Ưu tiên vừa',
  };

  Future<void> _showForm({ApiBudget? existing}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final limitController = TextEditingController(
      text: existing == null ? '' : existing.limitAmount.toStringAsFixed(0),
    );
    var period = existing?.period ?? 0;
    var mode = existing?.mode ?? 1;
    var priority = existing?.priority ?? 1;
    var categoryKey = existing?.categoryId ?? 'all';
    var startDate =
        existing?.startDate ??
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime? endDate = existing?.endDate;
    String? formError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DFEC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    existing == null ? 'Tạo ngân sách' : 'Chỉnh sửa ngân sách',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF172B4D),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameController,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Tên ngân sách',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      counterText: '',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nhập tên ngân sách.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: limitController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Hạn mức (VNĐ)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      return n == null || !n.isFinite || n <= 0
                          ? 'Hạn mức phải lớn hơn 0.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoryKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Áp dụng cho',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('Tất cả khoản chi'),
                      ),
                      ..._categories.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => categoryKey = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: period,
                    decoration: const InputDecoration(
                      labelText: 'Chu kỳ',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Hàng tháng')),
                      DropdownMenuItem(value: 1, child: Text('Hàng tuần')),
                      DropdownMenuItem(value: 2, child: Text('Hàng năm')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => period = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: mode,
                    decoration: const InputDecoration(
                      labelText: 'Chế độ ngân sách',
                      prefixIcon: Icon(Icons.track_changes_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Dự định — kiểm tra khả năng tài chính'),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text('Đang thực hiện — theo dõi chi tiêu'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => mode = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    decoration: const InputDecoration(
                      labelText: 'Mức ưu tiên',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('Cao')),
                      DropdownMenuItem(value: 1, child: Text('Trung bình')),
                      DropdownMenuItem(value: 0, child: Text('Thấp')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => priority = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        helpText: 'Ngày bắt đầu ngân sách',
                      );
                      if (selected != null)
                        setSheetState(() {
                          startDate = selected;
                          if (endDate != null && endDate!.isBefore(startDate))
                            endDate = null;
                        });
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Bắt đầu: ${_dateLabel(startDate)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate:
                            endDate ?? startDate.add(const Duration(days: 30)),
                        firstDate: startDate,
                        lastDate: DateTime(2100),
                        helpText: 'Ngày kết thúc (không bắt buộc)',
                      );
                      if (selected != null)
                        setSheetState(() => endDate = selected);
                    },
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      endDate == null
                          ? 'Ngày kết thúc: Không giới hạn'
                          : 'Kết thúc: ${_dateLabel(endDate!)}',
                    ),
                  ),
                  if (formError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        formError!,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => formError = null);
                            final budget = ApiBudget(
                              id: existing?.id ?? '',
                              name: nameController.text.trim(),
                              limitAmount: double.parse(
                                limitController.text.trim(),
                              ),
                              period: period,
                              mode: mode,
                              priority: priority,
                              startDate: startDate,
                              endDate: endDate,
                              categoryId: categoryKey == 'all'
                                  ? null
                                  : categoryKey,
                              householdId: existing?.householdId,
                            );
                            setState(() => _saving = true);
                            try {
                              if (existing == null) {
                                await _service.createBudget(budget);
                              } else {
                                await _service.updateBudget(budget);
                              }
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              await _load();
                              if (mounted)
                                _message(
                                  existing == null
                                      ? 'Đã tạo ngân sách.'
                                      : 'Đã cập nhật ngân sách.',
                                );
                            } catch (e) {
                              if (sheetContext.mounted) {
                                setSheetState(
                                  () => formError = _friendlyError(e),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Đang lưu...' : 'Lưu ngân sách'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameController.dispose();
    limitController.dispose();
  }

  String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _delete(ApiBudget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ngân sách?'),
        content: Text('Bạn có chắc muốn xóa “${budget.name}” không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteBudget(budget.id);
      await _load();
      if (mounted) _message('Đã xóa ngân sách.');
    } catch (e) {
      if (mounted) _message(_friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalLimit = _budgets.fold<double>(0, (s, b) => s + b.limitAmount);
    final totalSpent = _budgets.fold<double>(0, (s, b) => s + b.spentAmount);
    final ratio = totalLimit <= 0
        ? 0.0
        : (totalSpent / totalLimit).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ngân sách',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budgets-add-fab',
        onPressed: _categories.isEmpty && !_loading
            ? () => _message(
                'Không tải được danh mục. Hãy kiểm tra CategoriesController.',
              )
            : () => _showForm(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo ngân sách'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 260),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 54,
                    color: Color(0xFF7B8BA5),
                  ),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  _summaryCard(totalLimit, totalSpent, ratio),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Kế hoạch của bạn',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF172B4D),
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EFFF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_budgets.length} ngân sách',
                          style: const TextStyle(
                            color: _blue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_budgets.isEmpty)
                    _emptyState()
                  else
                    ...(_budgets
                          ..sort((a, b) => b.priority.compareTo(a.priority)))
                        .map(_budgetCard),
                  const SizedBox(height: 12),
                  const Text(
                    'Dữ liệu được tải từ API Finance_manager. Chi tiêu trong thanh tiến độ chỉ tính các giao dịch đã lưu và được duyệt trong SQL Server.',
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard(double limit, double spent, double ratio) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2457C5), Color(0xFF4C83E6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _blue.withValues(alpha: .18),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tổng quan ngân sách',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.more_horiz, color: Colors.white70),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Tổng hạn mức',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 5),
        Text(
          _money(limit),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _summaryMetric('Đã sử dụng', _money(spent))),
            const SizedBox(width: 16),
            Expanded(
              child: _summaryMetric('Còn theo hạn mức', _money(limit - spent)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: .22),
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${(ratio * 100).round()}% tổng hạn mức đã sử dụng',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _summaryMetric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ],
  );

  Widget _budgetCard(ApiBudget b) {
    final isPlanned = b.mode == 0;
    final overspent = b.spentAmount > b.limitAmount;
    final nearLimit = b.limitAmount > 0 && b.spentAmount / b.limitAmount >= .8;
    final rawRatio = b.limitAmount > 0 ? b.spentAmount / b.limitAmount : 0.0;
    final color = overspent
        ? const Color(0xFFCF3D4F)
        : nearLimit
        ? const Color(0xFFE19A22)
        : _blue;
    final categoryName = _categoryName(b.categoryId);
    final status = isPlanned
        ? 'Kế hoạch'
        : overspent
        ? 'Vượt hạn mức'
        : nearLimit
        ? 'Sắp chạm hạn mức'
        : 'Trong kiểm soát';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_iconFor(b.name), color: _blue, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF172B4D),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$categoryName • ${_periodLabel(b.period)}',
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _showForm(existing: b);
                  if (v == 'delete') _delete(b);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Chỉnh sửa'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Xóa'),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: Color(0xFF718096)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _pill(_modeLabel(b.mode), const Color(0xFFEAF0FF), _blue),
              _pill(
                _priorityLabel(b.priority),
                const Color(0xFFF0F3F8),
                const Color(0xFF53627A),
              ),
              _pill(
                status,
                overspent
                    ? const Color(0xFFFFE8EB)
                    : nearLimit
                    ? const Color(0xFFFFF3D9)
                    : const Color(0xFFE8F6EF),
                overspent
                    ? const Color(0xFFB42318)
                    : nearLimit
                    ? const Color(0xFF9A6700)
                    : const Color(0xFF18794E),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đã chi',
                      style: TextStyle(color: Color(0xFF718096), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _money(b.spentAmount),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172B4D),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Hạn mức',
                    style: TextStyle(color: Color(0xFF718096), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _money(b.limitAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF344054),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!isPlanned) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: rawRatio.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFFEAF0F7),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    overspent
                        ? 'Vượt ${_money(b.spentAmount - b.limitAmount)}'
                        : 'Còn ${_money(b.remainingAmount)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${(rawRatio * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          if (isPlanned)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Bắt đầu ${_dateLabel(b.startDate)}${b.endDate == null ? '' : ' • Kết thúc ${_dateLabel(b.endDate!)}'}',
                style: const TextStyle(color: Color(0xFF718096), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );

  String _categoryName(String? id) {
    if (id == null) return 'Tất cả khoản chi';
    for (final category in _categories) {
      if (category.id == id) return category.name;
    }
    return 'Danh mục';
  }

  IconData _iconFor(String name) {
    final s = name.toLowerCase();
    if (s.contains('ăn') || s.contains('uống')) return Icons.restaurant_rounded;
    if (s.contains('học')) return Icons.school_rounded;
    if (s.contains('di chuyển')) return Icons.directions_bus_rounded;
    if (s.contains('mua')) return Icons.shopping_bag_rounded;
    if (s.contains('giải trí')) return Icons.sports_esports_rounded;
    if (s.contains('sức khỏe')) return Icons.health_and_safety_rounded;
    return Icons.savings_rounded;
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5EAF3)),
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF0FF),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.savings_outlined, size: 30, color: _blue),
        ),
        const SizedBox(height: 14),
        const Text(
          'Chưa có ngân sách nào',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF172B4D),
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Tạo ngân sách đầu tiên để theo dõi hạn mức và kiểm soát chi tiêu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF718096), height: 1.4),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _showForm,
          icon: const Icon(Icons.add),
          label: const Text('Tạo ngân sách'),
        ),
      ],
    ),
  );
}
