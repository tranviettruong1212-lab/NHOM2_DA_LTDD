import 'package:flutter/foundation.dart';

import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/bank_wallet.dart';
import 'transaction_api_service.dart';

class MoneyMateBackend extends ChangeNotifier {
  MoneyMateBackend._();

  static final MoneyMateBackend instance = MoneyMateBackend._();

  final List<MoneyTransaction> _transactions = [];
  final List<Budget> _budgets = [];

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

  bool isWalletSyncing(String walletId) => _syncingDemoIds.contains(walletId);

  bool isWalletSynced(String walletId) {
    final kinds = _transactions
        .where((t) => t.demoWalletId == walletId)
        .map((t) => t.demoKind)
        .whereType<String>()
        .toSet();
    BankWallet? wallet;
    for (final candidate in _wallets) {
      if (candidate.id == walletId) { wallet = candidate; break; }
    }
    if (wallet == null) return false;
    return wallet.type == WalletType.bank
        ? kinds.contains('income') && kinds.contains('expense')
        : kinds.contains('expense');
  }

  /// Tải lịch sử giao dịch đã lưu trong SQL Server. Các giao dịch thủ công
  /// hiện chỉ nằm trong bộ nhớ được giữ lại trong phiên đang chạy.
  Future<void> loadFromApi() async {
    final remote = await _transactionApi.getTransactions();
    final localManual = _transactions.where((t) => !t.isPersisted).toList();
    _transactions
      ..clear()
      ..addAll(remote)
      ..addAll(localManual);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> deletePersistedTransaction(String id) async {
    await _transactionApi.deleteTransaction(id);
    await loadFromApi();
  }

  List<MoneyTransaction> get transactions => List.unmodifiable(_transactions);

  List<Budget> get budgets => List.unmodifiable(_budgets);

  List<BankWallet> get wallets => List.unmodifiable(_wallets);

  // Tổng tiền đang quản lý từ các giao dịch đã ghi nhận.
  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  void addTransaction(MoneyTransaction transaction) {
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  void updateTransaction(MoneyTransaction updated) {
    final index = _transactions.indexWhere((t) => t.id == updated.id);

    if (index == -1) return;

    _transactions[index] = updated;
    notifyListeners();
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void saveBudget(Budget budget) {
    // Ưu tiên cập nhật đúng ngân sách đang sửa.
    final idIndex = _budgets.indexWhere((b) => b.id == budget.id);

    if (idIndex != -1) {
      _budgets[idIndex] = budget;
    } else {
      // Không tạo trùng danh mục trong cùng một tháng.
      final categoryIndex = _budgets.indexWhere(
        (b) =>
            b.category == budget.category &&
            b.month == budget.month &&
            b.year == budget.year,
      );

      if (categoryIndex != -1) {
        _budgets[categoryIndex] = Budget(
          id: _budgets[categoryIndex].id,
          category: budget.category,
          limit: budget.limit,
          month: budget.month,
          year: budget.year,
          mode: budget.mode,
          priority: budget.priority,
        );
      } else {
        _budgets.add(budget);
      }
    }

    notifyListeners();
  }

  void deleteBudget(String id) {
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  double spentInBudget(Budget budget) {
    return _transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.category == budget.category &&
              t.date.month == budget.month &&
              t.date.year == budget.year,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // Ngân sách dự định dùng số dư hiện tại để đánh giá.
  // Ngân sách đang thực hiện dùng hạn mức trừ chi tiêu thực tế.
  double budgetRemaining(Budget budget) {
    if (budget.mode == BudgetMode.planned) {
      return balance - budget.limit;
    }

    return budget.limit - spentInBudget(budget);
  }

  bool plannedBudgetAffordable(Budget budget) {
    return balance >= budget.limit;
  }

  double budgetProgress(Budget budget) {
    if (budget.mode == BudgetMode.planned || budget.limit <= 0) {
      return 0;
    }

    return (spentInBudget(budget) / budget.limit).clamp(0.0, 1.0).toDouble();
  }

  String? budgetStatus(Budget budget) {
    if (budget.mode == BudgetMode.planned) {
      if (plannedBudgetAffordable(budget)) {
        return 'Đủ tiền để thực hiện dự định';
      }

      return 'Chưa đủ ${(budget.limit - balance).clamp(0.0, double.infinity).toStringAsFixed(0)} đ';
    }

    final spent = spentInBudget(budget);
    final ratio = spent / budget.limit;

    if (spent > budget.limit) {
      return 'Đã vượt ngân sách '
          '${(spent - budget.limit).toStringAsFixed(0)} đ';
    }

    if (ratio >= 0.8) {
      return 'Sắp hết ngân sách: '
          '${(ratio * 100).round()}%';
    }

    return 'Đang sử dụng bình thường';
  }

  // Chỉ đưa các ngân sách đặc biệt lên khu thông báo.
  List<String> get budgetNotifications {
    final now = DateTime.now();

    final currentBudgets = _budgets
        .where((b) => b.month == now.month && b.year == now.year)
        .toList();

    currentBudgets.sort((a, b) => a.priority.compareTo(b.priority));

    final messages = <String>[];

    for (final budget in currentBudgets) {
      final status = budgetStatus(budget);

      if (status == null) continue;

      final isSpecial = budget.mode == BudgetMode.planned
          ? !plannedBudgetAffordable(budget)
          : spentInBudget(budget) / budget.limit >= 0.8;

      if (isSpecial) {
        messages.add(
          'Ưu tiên ${budget.priority} • '
          '${budget.category}: $status',
        );
      }
    }

    return messages;
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
