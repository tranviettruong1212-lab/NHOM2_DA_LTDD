enum BudgetMode {
  planned, // Dự định
  active, // Đang thực hiện
}

class Budget {
  final String id;
  final String category;
  final double limit;
  final int month;
  final int year;
  final BudgetMode mode;
  final int priority;

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    required this.month,
    required this.year,
    this.mode = BudgetMode.active,
    this.priority = 3,
  });
}
