import '../models/bank_wallet.dart';
import '../models/transaction_model.dart';
import 'api_client.dart';

/// Giao tiếp với API SQL Server cho lịch sử giao dịch và giao dịch mô phỏng.
/// Không kết nối ngân hàng/ví thật.
class TransactionApiService {
  TransactionApiService._();
  static final TransactionApiService instance = TransactionApiService._();
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> _getTransactionsRaw() async {
    final data = await _api.get('/api/transactions');
    if (data is! List) {
      throw ApiException(500, 'API giao dịch trả về dữ liệu không hợp lệ.');
    }
    return data.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<MoneyTransaction>> getTransactions() async {
    final rows = await _getTransactionsRaw();
    return rows.map(_fromJson).toList();
  }

  MoneyTransaction _fromJson(Map<String, dynamic> json) {
    final rawNote = (json['note'] ?? json['Note'] ?? '').toString();
    final firstLine = rawNote.split(RegExp(r'\r?\n')).first;
    final marker = RegExp(r'^\[MM_DEMO_SYNC wallet=([^ ]+) kind=(income|expense)\] (.*)$').firstMatch(firstLine);
    final title = marker?.group(3)?.trim().isNotEmpty == true
        ? marker!.group(3)!.trim()
        : (firstLine.trim().isNotEmpty
            ? firstLine.trim()
            : (json['accountName'] ?? json['AccountName'] ?? 'Giao dịch').toString());
    final note = marker != null
        ? rawNote.split(RegExp(r'\r?\n')).skip(1).join('\n').trim()
        : rawNote;
    final typeValue = _int(json['type'] ?? json['Type']);
    final amount = _double(json['amount'] ?? json['Amount']);
    final date = DateTime.tryParse(
          (json['transactionDate'] ?? json['TransactionDate'] ?? '').toString(),
        ) ?? DateTime.now();
    return MoneyTransaction(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      title: title,
      amount: amount,
      type: typeValue == 1 ? TransactionType.income : TransactionType.expense,
      category: marker?.group(2) == 'income'
          ? 'Lương'
          : (json['categoryName'] ?? json['CategoryName'] ?? 'Khác').toString(),
      date: date,
      note: note,
      source: (json['accountName'] ?? json['AccountName'] ?? 'Tài khoản').toString(),
      isPersisted: true,
      demoWalletId: marker?.group(1),
      demoKind: marker?.group(2),
    );
  }

  Future<bool> simulateWallet(BankWallet wallet) async {
    // Đọc SQL trước để thao tác đồng bộ có tính idempotent qua các lần mở app.
    final existing = await _getTransactionsRaw();
    final accountId = await _ensureDemoAccount(wallet);
    final expenseCategories = await _getExpenseCategories();
    final now = DateTime.now();
    final samples = wallet.type == WalletType.bank
        ? <_DemoSample>[
            const _DemoSample(kind: 'income', title: 'Thu nhập mô phỏng', amount: 1000000, category: null,
                detail: 'Giao dịch minh họa, không phải giao dịch thật.'),
            const _DemoSample(kind: 'expense', title: 'Thanh toán mô phỏng', amount: 120000, category: 'Ăn uống',
                detail: 'Giao dịch minh họa, không phải giao dịch thật.'),
          ]
        : <_DemoSample>[
            const _DemoSample(kind: 'expense', title: 'Chi tiêu ví điện tử mô phỏng', amount: 50000, category: 'Mua sắm',
                detail: 'Giao dịch minh họa, không phải giao dịch thật.'),
          ];

    var created = false;
    for (final sample in samples) {
      final marker = '[MM_DEMO_SYNC wallet=${wallet.id} kind=${sample.kind}]';
      final alreadyExists = existing.any((row) =>
          (row['note'] ?? row['Note'] ?? '').toString().startsWith(marker));
      if (alreadyExists) continue;

      String? categoryId;
      if (sample.category != null) {
        Map<String, dynamic>? category;
        for (final candidate in expenseCategories) {
          if ((candidate['name'] ?? candidate['Name'] ?? '').toString().toLowerCase() == sample.category!.toLowerCase()) {
            category = candidate;
            break;
          }
        }
        category ??= expenseCategories.isEmpty ? null : expenseCategories.first;
        if (category == null) {
          throw ApiException(500, 'Không tìm thấy danh mục chi tiêu để lưu giao dịch mô phỏng.');
        }
        categoryId = (category['id'] ?? category['Id']).toString();
      }

      await _api.post('/api/transactions', {
        'accountId': accountId,
        'categoryId': categoryId,
        'type': sample.kind == 'income' ? 1 : 0,
        'amount': sample.amount,
        'transactionDate': now.toIso8601String(),
        'note': '$marker ${sample.title}\n${sample.detail}',
        'visibility': 0,
        'sharedWithUserIds': <String>[],
      });
      created = true;
    }
    return created;
  }

  Future<String> _ensureDemoAccount(BankWallet wallet) async {
    final data = await _api.get('/api/accounts');
    if (data is! List) throw ApiException(500, 'API tài khoản trả về dữ liệu không hợp lệ.');
    final accounts = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    Map<String, dynamic>? existing;
    for (final account in accounts) {
      if ((account['name'] ?? account['Name'] ?? '').toString() == wallet.name) {
        existing = account;
        break;
      }
    }
    if (existing != null) return (existing['id'] ?? existing['Id']).toString();

    final created = await _api.post('/api/accounts', {
      'name': wallet.name,
      'type': wallet.type == WalletType.bank ? 1 : 2,
      'openingBalance': wallet.demoBalance,
      'isDemo': true,
    });
    if (created is! Map) throw ApiException(500, 'Không tạo được tài khoản mô phỏng.');
    return (created['id'] ?? created['Id']).toString();
  }

  Future<List<Map<String, dynamic>>> _getExpenseCategories() async {
    final data = await _api.get('/api/categories');
    if (data is! List) throw ApiException(500, 'API danh mục trả về dữ liệu không hợp lệ.');
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> deleteTransaction(String id) => _api.delete('/api/transactions/$id');

  static int _int(dynamic value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  static double _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
}

class _DemoSample {
  final String kind;
  final String title;
  final double amount;
  final String? category;
  final String detail;
  const _DemoSample({required this.kind, required this.title, required this.amount, required this.category, required this.detail});
}
