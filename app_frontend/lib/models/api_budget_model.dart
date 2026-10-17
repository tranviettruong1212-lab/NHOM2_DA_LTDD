class BudgetCategory {
  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  final String id;
  final String name;
  final int type;

  const BudgetCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) => BudgetCategory(
    id: (json['id'] ?? json['Id']).toString(),
    name: (json['name'] ?? json['Name'] ?? '').toString(),
    type: _int(json['type'] ?? json['Type']),
  );
}

class ApiBudget {
  final String id;
  final String name;
  final double limitAmount;
  final int period; // 0 monthly, 1 weekly, 2 yearly (backend enum)
  final int mode; // 0 planned, 1 active
  final int priority; // 0 low, 1 normal, 2 high
  final DateTime startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? householdId;
  final double spentAmount;
  final double remainingAmount;
  final double progress;

  const ApiBudget({
    required this.id,
    required this.name,
    required this.limitAmount,
    required this.period,
    required this.mode,
    required this.priority,
    required this.startDate,
    this.endDate,
    this.categoryId,
    this.householdId,
    this.spentAmount = 0,
    this.remainingAmount = 0,
    this.progress = 0,
  });

  factory ApiBudget.fromJson(Map<String, dynamic> json) {
    final limit = _double(json['limitAmount'] ?? json['LimitAmount']);
    final spent = _double(json['spentAmount'] ?? json['SpentAmount']);
    final remainingRaw = json['remainingAmount'] ?? json['RemainingAmount'];
    final progressRaw = json['progress'] ?? json['Progress'];
    return ApiBudget(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      limitAmount: limit,
      period: _int(json['period'] ?? json['Period']),
      mode: _int(json['mode'] ?? json['Mode']),
      priority: _int(json['priority'] ?? json['Priority']),
      startDate:
          DateTime.tryParse(
            (json['startDate'] ?? json['StartDate'] ?? '').toString(),
          ) ??
          DateTime.now(),
      endDate: _nullableDate(json['endDate'] ?? json['EndDate']),
      categoryId: _nullableString(json['categoryId'] ?? json['CategoryId']),
      householdId: _nullableString(json['householdId'] ?? json['HouseholdId']),
      spentAmount: spent,
      remainingAmount: remainingRaw == null
          ? limit - spent
          : _double(remainingRaw),
      progress: progressRaw == null
          ? (limit > 0 ? (spent / limit).clamp(0, 1).toDouble() : 0)
          : _double(progressRaw),
    );
  }

  Map<String, dynamic> toRequestJson() => {
    'name': name,
    'limitAmount': limitAmount,
    'period': period,
    'mode': mode,
    'priority': priority,
    'startDate': _dateOnly(startDate),
    'endDate': endDate == null ? null : _dateOnly(endDate!),
    'categoryId': categoryId,
    'householdId': householdId,
  };

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';
  static DateTime? _nullableDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _nullableString(dynamic value) =>
      value == null || value.toString().isEmpty ? null : value.toString();
  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
}
