import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../models/bank_wallet.dart';
import '../services/app_backends.dart';
import 'demo_transaction_bundle_screen.dart';
import '../screens/linked_flow_screen.dart';

class BankWalletsScreen extends StatelessWidget {
  const BankWalletsScreen({super.key});

  String money(num amount) => CurrencyFormat.format(amount);

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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final created = await Navigator.push<int>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DemoTransactionBundleScreen(),
                      ),
                    );
                    if (!context.mounted || created == null) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã lưu $created giao dịch mẫu.')),
                    );
                  },
                  icon: const Icon(Icons.add_card),
                  label: const Text('Tạo giao dịch mẫu'),
                ),
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
                            onPressed: syncing || synced
                                ? null
                                : () async {
                                    try {
                                      final ok = await backend.simulateSync(
                                        wallet.id,
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ok
                                                ? 'Đã tạo tài khoản và giao dịch mẫu cho ${wallet.name}.'
                                                : 'Tài khoản này đã có các giao dịch mẫu.',
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Không thể lưu giao dịch mô phỏng: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: syncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(synced ? Icons.check : Icons.sync),
                            label: Text(
                              syncing
                                  ? 'Đang ghi giao dịch...'
                                  : synced
                                  ? 'Đã tạo tài khoản & giao dịch mẫu'
                                  : 'Tạo tài khoản & giao dịch mẫu',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              ...backend.transactions
                  .where(
                    (transaction) =>
                        transaction.source != 'Thủ công' &&
                        transaction.demoWalletId == null,
                  )
                  .map((transaction) => transaction.source)
                  .toSet()
                  .map(
                    (accountName) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        title: Text(accountName),
                        subtitle: const Text('Tài khoản mẫu'),
                        trailing: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
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
