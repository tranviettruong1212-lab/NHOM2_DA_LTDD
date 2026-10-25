import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart';
import '../models/api_budget_model.dart';
import '../models/bank_wallet.dart';
import 'budget_api_service.dart';
import 'transaction_api_service.dart';

class MoneyMateBackend extends ChangeNotifier {
  MoneyMateBackend._();

  static final MoneyMateBackend instance = MoneyMateBackend._();

  final List<MoneyTransaction> _transactions = [];
  final List<ApiBudget> _budgets = [];

  // Tài khoản mẫu, không kết nối dịch vụ thật.
  final List<BankWallet> _wallets = const [
    BankWallet(
      id: 'bank_demo',
      name: 'Vietcombank (mô phỏng)',
      type: WalletType.bank,
      demoBalance: 2500000,
    ),
    BankWallet(
      id: 'momo_demo',
      name: 'MoMo (mô phỏng)',
      type: WalletType.eWallet,
      demoBalance: 500000,
    ),
    BankWallet(
      id: 'bank2_demo',
      name: 'Techcombank (mô phỏng)',
      type: WalletType.bank,
      demoBalance: 1200000,
    ),
    BankWallet(
      id: 'zalopay_demo',
      name: 'ZaloPay (mô phỏng)',
      type: WalletType.eWallet,
      demoBalance: 300000,
    ),
  ];

  final Set<String> _syncingDemoIds = {};
  final TransactionApiService _transactionApi = TransactionApiService.instance;
  final BudgetApiService _budgetApi = BudgetApiService.instance;

  bool isWalletSyncing(String walletId) => _syncingDemoIds.contains(walletId);

  bool isWalletSynced(String walletId) {
    final kinds = _transactions
        .where((t) => t.demoWalletId == walletId)
        .map((t) => t.demoKind)
        .whereType<String>()
        .toSet();
    BankWallet? wallet;
    for (final candidate in _wallets) {
      if (candidate.id == walletId) {
        wallet = candidate;
        break;
      }
    }
    if (wallet == null) return false;
    return wallet.type == WalletType.bank
        ? kinds.contains('income') && kinds.contains('expense')
        : kinds.contains('expense');
  }

  /// Tải lịch sử giao dịch đã lưu trong SQL Server.
  Future<void> loadFromApi() async {
    final remote = await _transactionApi.getTransactions();
    final budgets = await _budgetApi.getBudgets();
    _transactions
      ..clear()
      ..addAll(remote);
    _budgets
      ..clear()
      ..addAll(budgets);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  void setBudgets(List<ApiBudget> budgets) {
    _budgets
      ..clear()
      ..addAll(budgets);
    notifyListeners();
  }

  Future<void> deletePersistedTransaction(String id) async {
    await _transactionApi.deleteTransaction(id);
    await loadFromApi();
  }

  List<MoneyTransaction> get transactions => List.unmodifiable(_transactions);

  List<ApiBudget> get budgets => List.unmodifiable(_budgets);

  List<BankWallet> get wallets => List.unmodifiable(_wallets);

  // Tổng tiền đang quản lý từ các giao dịch đã ghi nhận.
  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  Future<void> addTransaction(MoneyTransaction transaction) async {
    await _transactionApi.createManualTransaction(transaction);
    await loadFromApi();
  }

  Future<void> updateTransaction(MoneyTransaction updated) async {
    await _transactionApi.updateManualTransaction(updated);
    await loadFromApi();
  }

  double incomeInMonth(int month, int year) {
    return _transactions
        .where(
          (t) =>
              t.type == TransactionType.income &&
              t.date.month == month &&
              t.date.year == year,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double expenseInMonth(int month, int year) {
    return _transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.date.month == month &&
              t.date.year == year,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> expenseByCategory(int month, int year) {
    final result = <String, double>{};

    for (final t in _transactions) {
      if (t.type == TransactionType.expense &&
          t.date.month == month &&
          t.date.year == year) {
        result[t.category] = (result[t.category] ?? 0) + t.amount;
      }
    }

    return result;
  }

  // Ghi giao dịch mô phỏng vào API/SQL Server; không kết nối dịch vụ thật.
  Future<bool> simulateSync(String walletId) async {
    final index = _wallets.indexWhere((w) => w.id == walletId);
    if (index == -1 || _syncingDemoIds.contains(walletId)) return false;
    _syncingDemoIds.add(walletId);
    notifyListeners();
    try {
      final created = await _transactionApi.simulateWallet(_wallets[index]);
      await loadFromApi();
      return created;
    } finally {
      _syncingDemoIds.remove(walletId);
      notifyListeners();
    }
  }

  Future<int> createDemoTransactionBundle({
    required String accountName,
    required WalletType walletType,
    required List<DemoTransactionEntry> entries,
  }) async {
    final operationKey = 'bundle:${accountName.trim().toLowerCase()}';
    if (!_syncingDemoIds.add(operationKey)) return 0;
    notifyListeners();
    try {
      final created = await _transactionApi.createDemoBundle(
        accountName: accountName,
        walletType: walletType,
        entries: entries,
      );
      await loadFromApi();
      return created;
    } finally {
      _syncingDemoIds.remove(operationKey);
      notifyListeners();
    }
  }

  // Các giao dịch có nguồn từ ngân hàng/ví mô phỏng.
  List<MoneyTransaction> get linkedTransactions =>
      _transactions.where((t) => t.source != 'Thủ công').toList();

  // Tổng thu từ ngân hàng/ví mô phỏng trong tháng.
  double linkedIncomeInMonth(int month, int year) => linkedTransactions
      .where(
        (t) =>
            t.type == TransactionType.income &&
            t.date.month == month &&
            t.date.year == year,
      )
      .fold(0.0, (sum, t) => sum + t.amount);

  // Tổng chi từ ngân hàng/ví mô phỏng trong tháng.
  double linkedExpenseInMonth(int month, int year) => linkedTransactions
      .where(
        (t) =>
            t.type == TransactionType.expense &&
            t.date.month == month &&
            t.date.year == year,
      )
      .fold(0.0, (sum, t) => sum + t.amount);

  // Dòng tiền ròng = thu - chi.
  double linkedNetFlowInMonth(int month, int year) =>
      linkedIncomeInMonth(month, year) - linkedExpenseInMonth(month, year);

  // Tổng thu/chi theo từng nguồn.
  Map<String, Map<String, double>> linkedFlowBySource(int month, int year) {
    final result = <String, Map<String, double>>{};

    for (final t in linkedTransactions) {
      if (t.date.month != month || t.date.year != year) {
        continue;
      }

      final sourceData = result.putIfAbsent(
        t.source,
        () => {'income': 0.0, 'expense': 0.0},
      );

      if (t.type == TransactionType.income) {
        sourceData['income'] = sourceData['income']! + t.amount;
      } else {
        sourceData['expense'] = sourceData['expense']! + t.amount;
      }
    }

    return result;
  }

  // Dòng tiền theo ngày trong tháng đang chọn.
  Map<int, Map<String, double>> linkedDailyFlow(int month, int year) {
    final result = <int, Map<String, double>>{};

    for (final t in linkedTransactions) {
      if (t.date.month != month || t.date.year != year) {
        continue;
      }

      final dayData = result.putIfAbsent(
        t.date.day,
        () => {'income': 0.0, 'expense': 0.0},
      );

      final key = t.type == TransactionType.income ? 'income' : 'expense';

      dayData[key] = dayData[key]! + t.amount;
    }

    return result;
  }
}
