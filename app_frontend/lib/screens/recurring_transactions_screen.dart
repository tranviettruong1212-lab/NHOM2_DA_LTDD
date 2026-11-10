import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../models/recurring_transaction_model.dart';
import '../models/transaction_model.dart';
import '../services/app_backends.dart';
import '../services/recurring_api_service.dart';
import 'recurring_transaction_form_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> with SingleTickerProviderStateMixin {
  final _service = RecurringApiService.instance;
  List<RecurringTransaction> _items = [];
  bool _loading = true;
  String? _error;
  bool _processing = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _service.getRecurringTransactions();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _openForm([RecurringTransaction? item]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringTransactionFormScreen(recurring: item),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _toggleActive(RecurringTransaction item) async {
    try {
      await _service.toggleActive(item.id);
      await _loadData();
      await MoneyMateBackend.instance.loadFromApi();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.isActive
                  ? 'Đã tạm dừng "${item.title}"'
                  : 'Đã kích hoạt lại "${item.title}"',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _executeItem(RecurringTransaction item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ghi nhận giao dịch ngay?'),
        content: Text(
          'Hệ thống sẽ tạo 1 giao dịch "${item.title}" (${CurrencyFormat.format(item.amount)}) vào sổ chi tiêu và cập nhật ngày tới hạn sang kỳ tiếp theo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ghi nhận ngay')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      await _service.executeRecurring(item.id);
      await MoneyMateBackend.instance.loadFromApi();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã ghi nhận giao dịch "${item.title}" thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không ghi nhận được: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processAllDue() async {
    setState(() => _processing = true);
    try {
      final res = await _service.processDue();
      final count = res['processedCount'] ?? 0;
      await MoneyMateBackend.instance.loadFromApi();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tự động ghi nhận $count giao dịch đến hạn!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xử lý được: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _deleteItem(RecurringTransaction item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khoản định kỳ?'),
        content: Text('Bạn có chắc muốn xóa lịch định kỳ "${item.title}" không? Các giao dịch đã tạo trước đó sẽ không bị mất.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteRecurring(item.id);
      await _loadData();
      await MoneyMateBackend.instance.loadFromApi();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa khoản định kỳ "${item.title}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final dueCount = _items.where((i) => i.isDue && i.isActive).length;
    final activeExpenseSum = _items
        .where((i) => i.isActive && i.type == TransactionType.expense)
        .fold(0.0, (acc, i) => acc + i.amount);
    final activeIncomeSum = _items
        .where((i) => i.isActive && i.type == TransactionType.income)
        .fold(0.0, (acc, i) => acc + i.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch định kỳ'),
        actions: [
          if (dueCount > 0)
            IconButton(
              tooltip: 'Ghi nhận tất cả khoản đến hạn',
              onPressed: _processing ? null : _processAllDue,
              icon: const Badge(
                child: Icon(Icons.flash_on_outlined),
              ),
            ),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Tất cả (${_items.length})'),
            Tab(text: 'Đang chạy (${_items.where((i) => i.isActive).length})'),
            Tab(text: 'Tạm dừng (${_items.where((i) => !i.isActive).length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-recurring-fab',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm định kỳ'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Không tải được danh sách định kỳ: $_error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _loadData, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Summary card
                    Card(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tổng chi định kỳ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormat.format(activeExpenseSum),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 32, color: Colors.grey.shade400),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tổng thu định kỳ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormat.format(activeIncomeSum),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Due alert banner if any
                    if (dueCount > 0)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: Color(0xFFD97706)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Có $dueCount khoản định kỳ đã đến hạn!',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _processing ? null : _processAllDue,
                              child: const Text('Xử lý ngay'),
                            ),
                          ],
                        ),
                      ),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(_items),
                          _buildList(_items.where((i) => i.isActive).toList()),
                          _buildList(_items.where((i) => !i.isActive).toList()),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildList(List<RecurringTransaction> list) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_repeat_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có khoản định kỳ nào.\nNhấn "Thêm định kỳ" để tạo khoản chi/thu lặp lại!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 90),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final item = list[index];
          final isIncome = item.type == TransactionType.income;
          final isDue = item.isDue && item.isActive;

          return Card(
            elevation: isDue ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isDue
                  ? const BorderSide(color: Color(0xFFF59E0B), width: 1.5)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: !item.isActive
                          ? Colors.grey.shade200
                          : isDue
                              ? const Color(0xFFFEF3C7)
                              : isIncome
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                      child: Icon(
                        !item.isActive
                            ? Icons.pause
                            : isDue
                                ? Icons.alarm_on
                                : isIncome
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                        color: !item.isActive
                            ? Colors.grey
                            : isDue
                                ? const Color(0xFFD97706)
                                : isIncome
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: item.isActive ? null : TextDecoration.lineThrough,
                              color: item.isActive ? null : Colors.grey,
                            ),
                          ),
                        ),
                        Text(
                          '${isIncome ? '+' : '-'}${CurrencyFormat.format(item.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: !item.isActive
                                ? Colors.grey
                                : isIncome
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.frequencyName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.categoryName} • ${item.accountName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (item.householdId != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.group_outlined, size: 14, color: Color(0xFF2457C5)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isDue ? Icons.error_outline : Icons.event_outlined,
                              size: 14,
                              color: isDue ? Colors.amber.shade900 : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDue
                                  ? 'ĐÃ ĐẾN HẠN (${_formatDate(item.nextDueDate)})'
                                  : 'Tới hạn: ${_formatDate(item.nextDueDate)} (${item.daysUntilDue >= 0 ? "còn ${item.daysUntilDue} ngày" : "quá hạn"})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isDue ? FontWeight.bold : FontWeight.normal,
                                color: isDue ? Colors.amber.shade900 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        if (item.note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.note,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'execute') _executeItem(item);
                        if (v == 'toggle') _toggleActive(item);
                        if (v == 'edit') _openForm(item);
                        if (v == 'delete') _deleteItem(item);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'execute',
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow_outlined, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Ghi nhận ngay'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(item.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                              const SizedBox(width: 8),
                              Text(item.isActive ? 'Tạm dừng' : 'Kích hoạt lại'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 8),
                              Text('Chỉnh sửa'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom action buttons for card
                  const Divider(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.autoCreate ? Icons.autorenew : Icons.touch_app_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.autoCreate ? 'Tự động ghi nhận' : 'Xác nhận thủ công',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: _processing ? null : () => _executeItem(item),
                            icon: const Icon(Icons.flash_on, size: 16),
                            label: const Text('Ghi nhận'),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: item.isActive ? 'Tạm dừng định kỳ' : 'Tiếp tục',
                            icon: Icon(
                              item.isActive ? Icons.pause : Icons.play_arrow,
                              size: 18,
                              color: item.isActive ? Colors.orange : Colors.green,
                            ),
                            onPressed: () => _toggleActive(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

