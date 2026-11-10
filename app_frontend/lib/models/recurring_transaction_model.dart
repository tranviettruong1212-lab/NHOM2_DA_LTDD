import 'transaction_model.dart';

enum RecurrenceFrequency { daily, weekly, monthly, yearly }

class RecurringTransaction {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final RecurrenceFrequency frequency;
  final String frequencyName;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDueDate;
  final DateTime? lastGeneratedDate;
  final bool autoCreate;
  final bool isActive;
  final String note;
  final String accountId;
  final String accountName;
  final String? categoryId;
  final String categoryName;
  final String? householdId;
  final bool isDue;
  final int daysUntilDue;

  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.frequency,
    required this.frequencyName,
    required this.startDate,
    this.endDate,
    required this.nextDueDate,
    this.lastGeneratedDate,
    required this.autoCreate,
    required this.isActive,
    this.note = '',
    required this.accountId,
    this.accountName = 'Tài khoản',
    this.categoryId,
    this.categoryName = 'Khác',
    this.householdId,
    this.isDue = false,
    this.daysUntilDue = 0,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    final typeValue = _asInt(json['type'] ?? json['Type']);
    final freqValue = _asInt(json['frequency'] ?? json['Frequency']);
    final freq = freqValue >= 0 && freqValue < RecurrenceFrequency.values.length
        ? RecurrenceFrequency.values[freqValue]
        : RecurrenceFrequency.monthly;

    return RecurringTransaction(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      amount: _asDouble(json['amount'] ?? json['Amount']),
      type: typeValue == 1 ? TransactionType.income : TransactionType.expense,
      frequency: freq,
      frequencyName: (json['frequencyName'] ?? json['FrequencyName'] ?? _defaultFreqName(freq)).toString(),
      startDate: _parseDate(json['startDate'] ?? json['StartDate']),
      endDate: json['endDate'] != null || json['EndDate'] != null
          ? _tryParseDate(json['endDate'] ?? json['EndDate'])
          : null,
      nextDueDate: _parseDate(json['nextDueDate'] ?? json['NextDueDate']),
      lastGeneratedDate: json['lastGeneratedDate'] != null || json['LastGeneratedDate'] != null
          ? _tryParseDate(json['lastGeneratedDate'] ?? json['LastGeneratedDate'])
          : null,
      autoCreate: json['autoCreate'] == true || json['AutoCreate'] == true,
      isActive: json['isActive'] != false && json['IsActive'] != false,
      note: (json['note'] ?? json['Note'] ?? '').toString(),
      accountId: (json['accountId'] ?? json['AccountId'] ?? '').toString(),
      accountName: (json['accountName'] ?? json['AccountName'] ?? 'Tài khoản').toString(),
      categoryId: (json['categoryId'] ?? json['CategoryId'])?.toString(),
      categoryName: (json['categoryName'] ?? json['CategoryName'] ?? 'Khác').toString(),
      householdId: (json['householdId'] ?? json['HouseholdId'])?.toString(),
      isDue: json['isDue'] == true || json['IsDue'] == true,
      daysUntilDue: _asInt(json['daysUntilDue'] ?? json['DaysUntilDue']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }

  static DateTime? _tryParseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static String _defaultFreqName(RecurrenceFrequency freq) {
    switch (freq) {
      case RecurrenceFrequency.daily:
        return 'Hàng ngày';
      case RecurrenceFrequency.weekly:
        return 'Hàng tuần';
      case RecurrenceFrequency.monthly:
        return 'Hàng tháng';
      case RecurrenceFrequency.yearly:
        return 'Hàng năm';
    }
  }
}

