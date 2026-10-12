import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/app_backends.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  String money(double amount) => '${amount.toStringAsFixed(0)} đ';

  Future<void> _openForm(
    BuildContext context,
    MoneyTransaction? transaction,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(transaction: transaction),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MoneyTransaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: Text('Bạn có chắc muốn xóa "${transaction.title}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      MoneyMateBackend.instance.deleteTransaction(transaction.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = MoneyMateBackend.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm giao dịch'),
      ),
      body: AnimatedBuilder(
        animation: backend,
        builder: (context, _) {
          final transactions = backend.transactions;

          if (transactions.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có giao dịch.\nHãy nhấn Thêm giao dịch!',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: 90,
            ),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final t = transactions[index];
              final isIncome = t.type == TransactionType.income;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(t.title),
                  subtitle: Text(
                    '${t.category} • '
                    '${t.date.day}/${t.date.month}/${t.date.year}'
                    '${t.note.isEmpty ? '' : '\n${t.note}'}',
                  ),
                  isThreeLine: t.note.isNotEmpty,
                  trailing: SizedBox(
                    width: 115,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncome ? '+' : '-'}'
                          '${money(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Sửa',
                              onPressed: () => _openForm(context, t),
                              icon: const Icon(Icons.edit, size: 18),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Xóa',
                              onPressed: () => _confirmDelete(context, t),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
