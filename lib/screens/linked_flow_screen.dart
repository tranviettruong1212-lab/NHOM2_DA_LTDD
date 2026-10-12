import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/app_backends.dart';

class LinkedFlowScreen extends StatefulWidget {
  const LinkedFlowScreen({super.key});

  @override
  State<LinkedFlowScreen> createState() => _LinkedFlowScreenState();
}

class _LinkedFlowScreenState extends State<LinkedFlowScreen> {
  int month = DateTime.now().month;
  int year = DateTime.now().year;

  String money(double value) => '${value.toStringAsFixed(0)} đ';

  @override
  Widget build(BuildContext context) {
    final backend = MoneyMateBackend.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê dòng tiền liên kết')),
      body: AnimatedBuilder(
        animation: backend,
        builder: (context, _) {
          final income = backend.linkedIncomeInMonth(month, year);
          final expense = backend.linkedExpenseInMonth(month, year);
          final net = income - expense;

          final bySource = backend.linkedFlowBySource(month, year);
          final daily = backend.linkedDailyFlow(month, year);

          final maxDaily = daily.values.fold<double>(1, (maxValue, item) {
            final total = item['income']! + item['expense']!;
            return total > maxValue ? total : maxValue;
          });

          final sources = bySource.entries.toList()
            ..sort((a, b) {
              final totalA = a.value['income']! + a.value['expense']!;
              final totalB = b.value['income']! + b.value['expense']!;
              return totalB.compareTo(totalA);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Text('Tháng'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: month,
                        items: List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => month = value);
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      const Text('Năm'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: year,
                          items:
                              List.generate(
                                    9,
                                    (i) => DateTime.now().year - 4 + i,
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
                ),
              ),

              const SizedBox(height: 12),
              _summaryCard(
                'Tổng thu từ tài khoản liên kết',
                income,
                Colors.green,
                Icons.south_west,
              ),
              _summaryCard(
                'Tổng chi từ tài khoản liên kết',
                expense,
                Colors.red,
                Icons.north_east,
              ),
              _summaryCard(
                'Dòng tiền ròng',
                net,
                net >= 0 ? Colors.green : Colors.red,
                Icons.account_balance_wallet_outlined,
              ),

              const SizedBox(height: 20),
              Text(
                'Dòng tiền theo ngày',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Mỗi ngày gồm hai cột: thu nhập và chi tiêu. '
                'Chỉ tính giao dịch có nguồn từ tài khoản mô phỏng.',
              ),
              const SizedBox(height: 12),

              if (daily.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có giao dịch liên kết trong tháng này.'),
                  ),
                )
              else if (daily.isNotEmpty)
                _dailyChart(daily, maxDaily),

              const SizedBox(height: 24),
              Text(
                'Thống kê theo ngân hàng / ví điện tử',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),

              if (sources.isEmpty)
                const Text('Chưa có nguồn giao dịch để thống kê.')
              else
                ...sources.map((entry) {
                  final sourceIncome = entry.value['income']!;
                  final sourceExpense = entry.value['expense']!;
                  final sourceNet = sourceIncome - sourceExpense;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _sourceRow('Thu nhập', sourceIncome, Colors.green),
                          _sourceRow('Chi tiêu', sourceExpense, Colors.red),
                          const Divider(),
                          _sourceRow(
                            'Dòng tiền ròng',
                            sourceNet,
                            sourceNet >= 0 ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              const Text(
                'Lưu ý: số liệu chỉ phản ánh giao dịch mô phỏng '
                'đã được nhập vào MoneyMate, không phải dữ liệu '
                'được lấy trực tiếp từ ngân hàng.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          money(amount),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _sourceRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            money(amount),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _dailyChart(Map<int, Map<String, double>> daily, double maxValue) {
    final days = daily.keys.toList()..sort();

    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final values = daily[day]!;
          final income = values['income']!;
          final expense = values['expense']!;

          return SizedBox(
            width: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$day/${month}'),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _bar(income, maxValue, Colors.green),
                    const SizedBox(width: 4),
                    _bar(expense, maxValue, Colors.red),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Thu ${income.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, color: Colors.green),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Chi ${expense.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 10, color: Colors.red),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bar(double amount, double maxValue, Color color) {
    final height = (amount / maxValue * 115).clamp(0.0, 115.0).toDouble();

    return Container(
      width: 20,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}
