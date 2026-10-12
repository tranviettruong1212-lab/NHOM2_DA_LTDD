import 'package:flutter/material.dart';

import '../models/budget_model.dart';
import '../services/app_backends.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  static const categories = [
    'Ăn uống',
    'Di chuyển',
    'Học tập',
    'Mua sắm',
    'Giải trí',
    'Khác',
  ];

  String money(double amount) => '${amount.toStringAsFixed(0)} đ';

  Future<void> _showBudgetForm(BuildContext context, {Budget? existing}) async {
    final backend = MoneyMateBackend.instance;
    final controller = TextEditingController(
      text: existing?.limit.toStringAsFixed(0) ?? '',
    );

    String category = existing?.category ?? categories.first;
    BudgetMode mode = existing?.mode ?? BudgetMode.planned;
    int priority = existing?.priority ?? 3;
    final now = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Tạo ngân sách' : 'Sửa ngân sách'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Danh mục'),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                    ),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Hạn mức (VNĐ)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BudgetMode>(
                      value: mode,
                      decoration: const InputDecoration(
                        labelText: 'Chế độ ngân sách',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: BudgetMode.planned,
                          child: Text('Dự định'),
                        ),
                        DropdownMenuItem(
                          value: BudgetMode.active,
                          child: Text('Đang thực hiện'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => mode = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Cấp ưu tiên',
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 - Rất cao')),
                        DropdownMenuItem(value: 2, child: Text('2 - Cao')),
                        DropdownMenuItem(
                          value: 3,
                          child: Text('3 - Trung bình'),
                        ),
                        DropdownMenuItem(value: 4, child: Text('4 - Thấp')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Kỳ ngân sách: ${now.month}/${now.year}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final limit = double.tryParse(controller.text.trim());

                    if (limit == null || !limit.isFinite || limit <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hạn mức phải là số lớn hơn 0'),
                        ),
                      );
                      return;
                    }

                    backend.saveBudget(
                      Budget(
                        id:
                            existing?.id ??
                            '${now.year}_${now.month}_$category',
                        category: category,
                        limit: limit,
                        month: existing?.month ?? now.month,
                        year: existing?.year ?? now.year,
                        mode: mode,
                        priority: priority,
                      ),
                    );

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Lưu ngân sách'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = MoneyMateBackend.instance;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Tạo ngân sách'),
      ),
      body: AnimatedBuilder(
        animation: backend,
        builder: (context, _) {
          final budgets =
              backend.budgets
                  .where((b) => b.month == now.month && b.year == now.year)
                  .toList()
                ..sort((a, b) => a.priority.compareTo(b.priority));

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng tiền MoneyMate đang quản lý'),
                      const SizedBox(height: 8),
                      Text(
                        money(backend.balance),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thu ${money(backend.totalIncome)}'
                        ' • Chi ${money(backend.totalExpense)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (budgets.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Chưa có ngân sách trong tháng này.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ...budgets.map((budget) {
                final isPlanned = budget.mode == BudgetMode.planned;
                final spent = backend.spentInBudget(budget);
                final progress = backend.budgetProgress(budget);
                final remaining = backend.budgetRemaining(budget);
                final status = backend.budgetStatus(budget);

                final special = isPlanned
                    ? !backend.plannedBudgetAffordable(budget)
                    : spent >= budget.limit * 0.8;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                budget.category,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Sửa ngân sách',
                              onPressed: () =>
                                  _showBudgetForm(context, existing: budget),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Xóa ngân sách',
                              onPressed: () => backend.deleteBudget(budget.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                isPlanned ? 'Dự định' : 'Đang thực hiện',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(Icons.flag_outlined, size: 18),
                              label: Text('Ưu tiên ${budget.priority}'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Hạn mức: ${money(budget.limit)}'),
                        if (isPlanned) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Số dư sau khi dành khoản tiền này: '
                            '${money(remaining)}',
                          ),
                        ] else ...[
                          Text('Đã chi: ${money(spent)}'),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 9,
                            color: spent > budget.limit
                                ? Colors.red
                                : special
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(height: 6),
                          Text('Còn lại: ${money(remaining)}'),
                        ],
                        if (special) ...[
                          const SizedBox(height: 8),
                          Text(
                            status ?? '',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else if (isPlanned) ...[
                          const SizedBox(height: 8),
                          Text(
                            status ?? '',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
