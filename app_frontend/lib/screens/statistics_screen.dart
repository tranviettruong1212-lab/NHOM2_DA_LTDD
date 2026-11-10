import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../services/app_backends.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int month = DateTime.now().month;
  int year = DateTime.now().year;

  String money(num value) => CurrencyFormat.format(value);

  @override
  Widget build(BuildContext context) {
    final backend = MoneyMateBackend.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: AnimatedBuilder(
        animation: backend,
        builder: (context, _) {
          final income = backend.incomeInMonth(month, year);
          final expense = backend.expenseInMonth(month, year);
          final categories = backend.expenseByCategory(month, year);

          final maxValue = [
            income,
            expense,
            1.0,
          ].reduce((a, b) => a > b ? a : b);

          final sorted = categories.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final totalCategoryExpense = categories.values.fold(
            0.0,
            (sum, value) => sum + value,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Text('Tháng: '),
                  DropdownButton<int>(
                    value: month,
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => month = value);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text('Năm: '),
                  Expanded(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: year,
                      items:
                          List.generate(
                                9,
                                (index) => DateTime.now().year - 4 + index,
                              )
                              .map(
                                (y) => DropdownMenuItem(
                                  value: y,
                                  child: Text('$y'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => year = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng kết $month/$year',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text('Thu nhập: ${money(income)}'),
                      const SizedBox(height: 6),
                      Text('Chi tiêu: ${money(expense)}'),
                      const SizedBox(height: 6),
                      Text(
                        'Chênh lệch: ${money(income - expense)}',
                        style: TextStyle(
                          color: income >= expense ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Biểu đồ thu nhập và chi tiêu',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _bar('Thu nhập', income, maxValue, Colors.green),
                    const SizedBox(width: 36),
                    _bar('Chi tiêu', expense, maxValue, Colors.red),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Chi tiêu theo danh mục',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              if (sorted.isEmpty)
                const Text('Chưa có chi tiêu trong tháng được chọn.')
              else
                ...sorted.map((entry) {
                  final ratio = totalCategoryExpense == 0
                      ? 0.0
                      : entry.value / totalCategoryExpense;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(entry.key)),
                            Text(money(entry.value)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: ratio, minHeight: 8),
                        const SizedBox(height: 4),
                        Text(
                          '${(ratio * 100).round()}% tổng chi tiêu',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(String label, double value, double maxValue, Color color) {
    final height = (value / maxValue * 140).clamp(0.0, 140.0).toDouble();

    return SizedBox(
      width: 110,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            CurrencyFormat.compact(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}
