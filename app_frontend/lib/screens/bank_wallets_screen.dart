import 'package:flutter/material.dart';

import '../models/bank_wallet.dart';
import '../services/app_backends.dart';
import '../screens/linked_flow_screen.dart';

class BankWalletsScreen extends StatelessWidget {
  const BankWalletsScreen({super.key});

  String money(double amount) => '${amount.toStringAsFixed(0)} đ';

  @override
  Widget build(BuildContext context) {
    final backend = MoneyMateBackend.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân hàng & ví điện tử'),
        actions: [
          IconButton(
            tooltip: 'Thống kê dòng tiền',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LinkedFlowScreen()),
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: backend,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'CHẾ ĐỘ MÔ PHỎNG\n'
                          'Các tài khoản và giao dịch bên dưới '
                          'chỉ phục vụ học tập. MoneyMate không '
                          'kết nối ngân hàng hoặc ví điện tử thật.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tài khoản mẫu',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...backend.wallets.map((wallet) {
                final synced = _isSynced(backend, wallet.id);
                final syncing = backend.isWalletSyncing(wallet.id);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Icon(
                              wallet.type == WalletType.bank
                                  ? Icons.account_balance
                                  : Icons.account_balance_wallet,
                            ),
                          ),
                          title: Text(wallet.name),
                          subtitle: Text(
                            wallet.type == WalletType.bank
                                ? 'Ngân hàng • Tài khoản mẫu'
                                : 'Ví điện tử • Tài khoản mẫu',
                          ),
                          trailing: Icon(
                            synced
                                ? Icons.check_circle
                                : Icons.cloud_sync_outlined,
                            color: synced ? Colors.green : Colors.blueGrey,
                          ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            const Expanded(child: Text('Số dư minh họa')),
                            Text(
                              money(wallet.demoBalance),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: synced || syncing
                                ? null
                                : () async {
                                    try {
                                      final ok = await backend.simulateSync(wallet.id);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok
                                              ? 'Đã lưu giao dịch mô phỏng của ${wallet.name} vào SQL Server.'
                                              : 'Các giao dịch mô phỏng của tài khoản này đã tồn tại.'),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Không thể lưu giao dịch mô phỏng: $e')),
                                      );
                                    }
                                  },
                            icon: syncing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(synced ? Icons.check : Icons.sync),
                            label: Text(
                              syncing
                                  ? 'Đang ghi giao dịch...'
                                  : synced
                                      ? 'Đã mô phỏng đồng bộ'
                                      : 'Mô phỏng đồng bộ giao dịch',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Text(
                'Giao dịch từ tài khoản mô phỏng',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...backend.transactions.where((t) => t.source != 'Thủ công').map((
                t,
              ) {
                final isIncome = t.type.name == 'income';

                return ListTile(
                  leading: Icon(
                    isIncome ? Icons.south_west : Icons.north_east,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                  title: Text(t.title),
                  subtitle: Text(t.source),
                  trailing: Text('${isIncome ? '+' : '-'}${money(t.amount)}'),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  bool _isSynced(MoneyMateBackend backend, String walletId) =>
      backend.isWalletSynced(walletId);
}
