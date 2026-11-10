import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../models/transaction_model.dart';
import '../services/app_backends.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

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
      try {
        await MoneyMateBackend.instance.deletePersistedTransaction(
          transaction.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa giao dịch khỏi SQL Server.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không xóa được giao dịch: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = MoneyMateBackend.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Giao dịch')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'transactions-add-fab',
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm giao dịch'),
      ),
      body: AnimatedBuilder(
        animation: backend,
        builder: (context, _) {
          final transactions = backend.transactions;

          if (transactions.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => backend.loadFromApi(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Chưa có giao dịch.\nHãy nhấn Thêm giao dịch!',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => backend.loadFromApi(),
            child: ListView.builder(
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
                final isPending = t.status == 1;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPending
                          ? const Color(0xFFFEF3C7)
                          : isIncome
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      child: Icon(
                        isPending
                            ? Icons.hourglass_top
                            : isIncome
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: isPending
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
                            t.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isPending) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFCD34D)),
                            ),
                            child: const Text(
                              'Chờ duyệt',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                        if (t.isHousehold) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.group_outlined, size: 16, color: Color(0xFF2457C5)),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${t.category} • ${t.date.day}/${t.date.month}/${t.date.year}'
                      '${t.source == 'Thủ công' ? '' : ' • ${t.source}'}'
                      '${t.note.isEmpty ? '' : '\n${t.note}'}',
                    ),
                    isThreeLine: t.note.isNotEmpty,
                    trailing: SizedBox(
                      width: 130,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${isIncome ? '+' : '-'}${CurrencyFormat.format(t.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isPending
                                  ? const Color(0xFFD97706)
                                  : isIncome
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: (t.isPersisted && t.source != 'Thủ công') || isPending
                                    ? null
                                    : () => _openForm(context, t),
                                tooltip: isPending
                                    ? 'Giao dịch đang chờ duyệt không thể sửa'
                                    : (t.isPersisted && t.source != 'Thủ công'
                                        ? 'Không thể sửa giao dịch mô phỏng đã đồng bộ'
                                        : 'Sửa'),
                                icon: const Icon(Icons.edit, size: 18),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Xóa',
                                onPressed: isPending ? null : () => _confirmDelete(context, t),
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
            ),
          );
        },
      ),
    );
  }
}
