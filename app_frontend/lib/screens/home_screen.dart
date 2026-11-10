import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../models/transaction_model.dart';
import '../services/app_backends.dart';
import 'recurring_transactions_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String money(num amount) => CurrencyFormat.format(amount);

  @override
  Widget build(BuildContext context) {
    final backend = MoneyMateBackend.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyMate'),
        actions: [
          IconButton(
            tooltip: 'Thông báo ngân sách',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thông báo ngân sách được cập nhật tự động.'),
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: backend,
        builder: (context, _) {
          final recent = backend.transactions.take(5).toList();
          final now = DateTime.now();

          final currentBudgets =
              backend.budgets
                  .where(
                    (budget) =>
                        !budget.startDate.isAfter(now) &&
                        (budget.endDate == null ||
                            !budget.endDate!.isBefore(
                              DateTime(now.year, now.month, now.day),
                            )),
                  )
                  .toList()
                ..sort((a, b) => a.priority.compareTo(b.priority));

          final specialBudgets = currentBudgets
              .where((budget) {
                if (budget.mode == 0) {
                  return backend.balance < budget.limitAmount;
                }

                return budget.progress >= 0.8;
              })
              .take(5)
              .toList();

          return RefreshIndicator(
            onRefresh: () => backend.loadFromApi(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Số dư MoneyMate đang quản lý'),
                      const SizedBox(height: 8),
                      Text(
                        money(backend.balance),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Thu: ${money(backend.totalIncome)}',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Chi: ${money(backend.totalExpense)}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (backend.dueRecurringCount > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: const Color(0xFFFEF3C7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.event_repeat, color: Color(0xFFD97706)),
                    title: Text(
                      'Có ${backend.dueRecurringCount} khoản định kỳ đến hạn',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    subtitle: const Text('Nhấn để kiểm tra và xác nhận ghi nhận vào sổ giao dịch.'),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFFD97706)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecurringTransactionsScreen()),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(Icons.notifications_active_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thông báo ngân sách',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text('${specialBudgets.length}'),
                ],
              ),
              const SizedBox(height: 8),

              if (specialBudgets.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    title: Text('Chưa có cảnh báo đặc biệt'),
                    subtitle: Text(
                      'Các ngân sách ưu tiên đang trong giới hạn '
                      'hoặc chưa có ngân sách cần chú ý.',
                    ),
                  ),
                )
              else
                ...specialBudgets.map((budget) {
                  final isPlanned = budget.mode == 0;

                  final spent = budget.spentAmount;

                  // Dự định: tiến trình thể hiện mức tiền hiện có
                  // so với khoản tiền cần để thực hiện.
                  // Đang thực hiện: thể hiện tỷ lệ đã chi.
                  final progress = isPlanned
                      ? (backend.balance / budget.limitAmount)
                            .clamp(0.0, 1.0)
                            .toDouble()
                      : budget.progress;

                  final status = isPlanned
                      ? backend.balance >= budget.limitAmount
                            ? 'Đủ tiền để thực hiện dự định'
                            : 'Chưa đủ ${money(budget.limitAmount - backend.balance)}'
                      : spent > budget.limitAmount
                      ? 'Đã vượt ngân sách ${money(spent - budget.limitAmount)}'
                      : budget.progress >= 0.8
                      ? 'Sắp hết ngân sách: ${(budget.progress * 100).round()}%'
                      : 'Đang sử dụng bình thường';

                  final isOverBudget = !isPlanned && spent > budget.limitAmount;

                  final isInsufficient =
                      isPlanned && backend.balance < budget.limitAmount;

                  final color = isInsufficient || isOverBudget
                      ? Colors.red
                      : Colors.orange;

                  final amountDescription = isPlanned
                      ? 'Số dư hiện có: ${money(backend.balance)} / '
                            '${money(budget.limitAmount)} cần thiết'
                      : 'Đã chi ${money(spent)} / '
                            '${money(budget.limitAmount)}';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isOverBudget || isInsufficient
                                    ? Icons.warning_amber_rounded
                                    : Icons.notifications_active_outlined,
                                color: color,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  budget.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Chip(label: Text('Ưu tiên ${budget.priority}')),
                            ],
                          ),
                          Text(
                            isPlanned
                                ? 'Chế độ: Dự định'
                                : 'Chế độ: Đang thực hiện',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(amountDescription),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            color: color,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isPlanned
                                ? 'Khả năng đáp ứng: '
                                      '${(progress * 100).round()}%'
                                : 'Đã sử dụng: '
                                      '${(budget.progress * 100).round()}%',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(status, style: TextStyle(color: color)),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),
              Text(
                'Giao dịch gần đây',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),

              if (recent.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chưa có giao dịch. Hãy thêm giao dịch '
                      'hoặc thử mô phỏng đồng bộ tài khoản.',
                    ),
                  ),
                )
              else
                ...recent.map((t) {
                  final isIncome = t.type == TransactionType.income;

                  return Card(
                    child: ListTile(
                      leading: Icon(
                        isIncome ? Icons.south_west : Icons.north_east,
                        color: isIncome ? Colors.green : Colors.red,
                      ),
                      title: Text(t.title),
                      subtitle: Text('${t.category} • ${t.source}'),
                      trailing: Text(
                        '${isIncome ? '+' : '-'}'
                        '${money(t.amount)}',
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
        },
      ),
    );
  }
}
