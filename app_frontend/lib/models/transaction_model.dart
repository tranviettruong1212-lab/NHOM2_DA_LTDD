enum TransactionType { income, expense }

class MoneyTransaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String note;
  final String source;

  // Đánh dấu giao dịch đã được lưu trên backend/SQL Server.
  final bool isPersisted;

  // ID tài khoản ngân hàng/ví mô phỏng.
  final String? demoWalletId;

  // Loại giao dịch mô phỏng: income hoặc expense.
  final String? demoKind;

  // Giao dịch thuộc nhóm gia đình
  final bool isHousehold;
  final String? householdId;
  final int? status;

  MoneyTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note = '',
    this.source = 'Thủ công',
    this.isPersisted = false,
    this.demoWalletId,
    this.demoKind,
    this.isHousehold = false,
    this.householdId,
    this.status,
  });
}
