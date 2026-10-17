import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'home_screen.dart';
import 'transactions_screen.dart';
import 'budget_screen.dart';
import 'statistics_screen.dart';
import 'bank_wallets_screen.dart';
import 'profile_screen.dart';
import '../services/app_backends.dart';
import '../services/api_client.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) return const LoginScreen();
        final user = snapshot.data!;
        return SignedInBootstrap(key: ValueKey(user.uid));
      },
    );
  }
}

class SignedInBootstrap extends StatefulWidget {
  const SignedInBootstrap({super.key});

  @override
  State<SignedInBootstrap> createState() => _SignedInBootstrapState();
}

class _SignedInBootstrapState extends State<SignedInBootstrap> {
  bool _ready = false;
  String? _warning;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Endpoint này cũng đảm bảo Firebase UID được đồng bộ vào bảng Users.
      await ApiClient.instance.get('/api/me');
      await MoneyMateBackend.instance.loadFromApi();
    } catch (e) {
      _warning = 'Chưa đồng bộ được dữ liệu máy chủ: $e';
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Đang đồng bộ tài khoản và giao dịch...'),
        ])),
      );
    }
    return FinanceNavigation(bootstrapWarning: _warning);
  }
}

class FinanceNavigation extends StatefulWidget {
  final String? bootstrapWarning;
  const FinanceNavigation({super.key, this.bootstrapWarning});
  @override
  State<FinanceNavigation> createState() => _FinanceNavigationState();
}

class _FinanceNavigationState extends State<FinanceNavigation> {
  int _index = 2;
  bool _showWarning = true;
  final _screens = const [HomeScreen(), TransactionsScreen(), BudgetsScreen(), StatisticsScreen(), BankWalletsScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      if (widget.bootstrapWarning != null && _showWarning)
        MaterialBanner(
          content: Text(widget.bootstrapWarning!),
          leading: const Icon(Icons.cloud_off_outlined),
          actions: [TextButton(onPressed: () => setState(() => _showWarning = false), child: const Text('Đóng'))],
        ),
      Expanded(child: IndexedStack(index: _index, children: _screens)),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Tổng quan'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Giao dịch'),
        NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Ngân sách'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Thống kê'),
        NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Ví mô phỏng'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
      ],
    ),
  );
}
