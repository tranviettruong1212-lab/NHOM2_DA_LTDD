import '../models/bank_wallet.dart';
import '../models/transaction_model.dart';
import 'api_client.dart';

class DemoTransactionEntry {
  const DemoTransactionEntry({
    required this.idempotencyKey,
    required this.title,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    required this.note,
  });

  final String idempotencyKey;
  final String title;
  final TransactionType type;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String note;
}

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
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> createManualTransaction(MoneyTransaction transaction) async {
    final accountId = await _ensureManualAccount();
    await _api.post(
      '/api/transactions',
      await _requestBody(transaction, accountId),
    );
  }

  Future<void> updateManualTransaction(MoneyTransaction transaction) async {
    final accountId = await _ensureManualAccount();
    await _api.put(
      '/api/transactions/${transaction.id}',
      await _requestBody(transaction, accountId),
    );
  }

  Future<Map<String, dynamic>> _requestBody(
    MoneyTransaction transaction,
    String accountId,
  ) async {
    final type = transaction.type == TransactionType.income ? 1 : 0;
    final categories = await _getCategories(type);
    Map<String, dynamic>? category;
    for (final candidate in categories) {
      if ((candidate['name'] ?? candidate['Name'] ?? '')
              .toString()
              .toLowerCase() ==
          transaction.category.toLowerCase()) {
        category = candidate;
        break;
      }
    }
    category ??= categories.firstWhere(
      (candidate) =>
          (candidate['name'] ?? candidate['Name'] ?? '')
              .toString()
              .toLowerCase() ==
          'khác',
      orElse: () => categories.isNotEmpty
          ? categories.first
          : throw ApiException(
              500,
              'Không tìm thấy danh mục phù hợp để lưu giao dịch.',
            ),
    );

    final note = transaction.note.trim().isEmpty
        ? transaction.title.trim()
        : '${transaction.title.trim()}\n${transaction.note.trim()}';
    final visibility = transaction.isHousehold ? 1 : 0;
    return {
      'accountId': accountId,
      'categoryId': category['id'] ?? category['Id'],
      'type': type,
      'amount': transaction.amount,
      'transactionDate': transaction.date.toIso8601String(),
      'note': note,
      'visibility': visibility,
      'householdId': transaction.isHousehold ? transaction.householdId : null,
      'sharedWithUserIds': <String>[],
    };
  }

  Future<List<MoneyTransaction>> getTransactions() async {
    final rows = await _getTransactionsRaw();
    return rows.map(_fromJson).toList();
  }

  MoneyTransaction _fromJson(Map<String, dynamic> json) {
    final rawNote = (json['note'] ?? json['Note'] ?? '').toString();
    final firstLine = rawNote.split(RegExp(r'\r?\n')).first;
    final bundleMarker = RegExp(
      r'^\[MM_DEMO_BUNDLE item=[^\]]+\] (.*)$',
    ).firstMatch(firstLine);
    final marker = RegExp(
      r'^\[MM_DEMO_SYNC wallet=([^ ]+) kind=(income|expense)(?: run=([^ ]+))?\] (.*)$',
    ).firstMatch(firstLine);
    final title = bundleMarker?.group(1)?.trim().isNotEmpty == true
        ? bundleMarker!.group(1)!.trim()
        : marker?.group(4)?.trim().isNotEmpty == true
        ? marker!.group(4)!.trim()
        : (firstLine.trim().isNotEmpty
              ? firstLine.trim()
              : (json['accountName'] ?? json['AccountName'] ?? 'Giao dịch')
                    .toString());
    final note = rawNote.split(RegExp(r'\r?\n')).skip(1).join('\n').trim();
    final typeValue = _int(json['type'] ?? json['Type']);
    final amount = _double(json['amount'] ?? json['Amount']);
    final visibility = _int(json['visibility'] ?? json['Visibility']);
    final status = _int(json['status'] ?? json['Status']);
    final householdId = (json['householdId'] ?? json['HouseholdId'])?.toString();
    final date =
        DateTime.tryParse(
          (json['transactionDate'] ?? json['TransactionDate'] ?? '').toString(),
        ) ??
        DateTime.now();
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
      source:
          (json['accountName'] ?? json['AccountName'] ?? 'Tài khoản')
                  .toString() ==
              'Tiền mặt'
          ? 'Thủ công'
          : (json['accountName'] ?? json['AccountName'] ?? 'Tài khoản')
                .toString(),
      isPersisted: true,
      demoWalletId: marker?.group(1),
      demoKind: marker?.group(2),
      isHousehold: visibility == 1,
      householdId: householdId,
      status: status,
    );
  }

  Future<bool> simulateWallet(BankWallet wallet) async {
    final existing = await _getTransactionsRaw();
    final accountId = await _ensureDemoAccount(wallet);
    final expenseCategories = await _getCategories(0);
    final now = DateTime.now();
    final samples = wallet.type == WalletType.bank
        ? <_DemoSample>[
            const _DemoSample(
              kind: 'income',
              title: 'Thu nhập mô phỏng',
              amount: 1000000,
              category: null,
              detail: 'Giao dịch minh họa, không phải giao dịch thật.',
            ),
            const _DemoSample(
              kind: 'expense',
              title: 'Thanh toán mô phỏng',
              amount: 120000,
              category: 'Ăn uống',
              detail: 'Giao dịch minh họa, không phải giao dịch thật.',
            ),
          ]
        : <_DemoSample>[
            const _DemoSample(
              kind: 'expense',
              title: 'Chi tiêu ví điện tử mô phỏng',
              amount: 50000,
              category: 'Mua sắm',
              detail: 'Giao dịch minh họa, không phải giao dịch thật.',
            ),
          ];

    var created = false;
    for (final sample in samples) {
      final markerPrefix =
          '[MM_DEMO_SYNC wallet=${wallet.id} kind=${sample.kind}';
      final alreadyCreated = existing.any(
        (row) => (row['note'] ?? row['Note'] ?? '').toString().startsWith(
          markerPrefix,
        ),
      );
      if (alreadyCreated) continue;

      String? categoryId;
      if (sample.category != null) {
        Map<String, dynamic>? category;
        for (final candidate in expenseCategories) {
          if ((candidate['name'] ?? candidate['Name'] ?? '')
                  .toString()
                  .toLowerCase() ==
              sample.category!.toLowerCase()) {
            category = candidate;
            break;
          }
        }
        category ??= expenseCategories.isEmpty ? null : expenseCategories.first;
        if (category == null) {
          throw ApiException(
            500,
            'Không tìm thấy danh mục chi tiêu để lưu giao dịch mô phỏng.',
          );
        }
        categoryId = (category['id'] ?? category['Id']).toString();
      }

      await _api.post('/api/transactions', {
        'accountId': accountId,
        'categoryId': categoryId,
        'type': sample.kind == 'income' ? 1 : 0,
        'amount': sample.amount,
        'transactionDate': now.toIso8601String(),
        'note': '$markerPrefix] ${sample.title}\n${sample.detail}',
        'visibility': 0,
        'sharedWithUserIds': <String>[],
      });
      created = true;
    }
    return created;
  }

  Future<String> _ensureDemoAccount(BankWallet wallet) async {
    final data = await _api.get('/api/accounts');
    if (data is! List) {
      throw ApiException(500, 'API tài khoản trả về dữ liệu không hợp lệ.');
    }
    final accounts = data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    Map<String, dynamic>? existing;
    for (final account in accounts) {
      if ((account['name'] ?? account['Name'] ?? '').toString() ==
          wallet.name) {
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
    if (created is! Map) {
      throw ApiException(500, 'Không tạo được tài khoản mô phỏng.');
    }
    return (created['id'] ?? created['Id']).toString();
  }

  Future<String> _ensureManualAccount() async {
    final data = await _api.get('/api/accounts');
    if (data is! List) {
      throw ApiException(500, 'API tài khoản trả về dữ liệu không hợp lệ.');
    }
    final accounts = data.whereType<Map>().map(
      (item) => Map<String, dynamic>.from(item),
    );
    for (final account in accounts) {
      if ((account['name'] ?? account['Name'] ?? '').toString() == 'Tiền mặt') {
        return (account['id'] ?? account['Id']).toString();
      }
    }

    final created = await _api.post('/api/accounts', {
      'name': 'Tiền mặt',
      'type': 0,
      'openingBalance': 0,
      'isDemo': false,
    });
    if (created is! Map) {
      throw ApiException(500, 'Không tạo được tài khoản tiền mặt.');
    }
    return (created['id'] ?? created['Id']).toString();
  }

  Future<List<Map<String, dynamic>>> _getCategories(int type) async {
    final data = await _api.get('/api/categories?type=$type');
    if (data is! List) {
      throw ApiException(500, 'API danh mục trả về dữ liệu không hợp lệ.');
    }
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getCategoriesForType(
    TransactionType type,
  ) => _getCategories(type == TransactionType.income ? 1 : 0);

  Future<int> createDemoBundle({
    required String accountName,
    required WalletType walletType,
    required List<DemoTransactionEntry> entries,
  }) async {
    final accountId = await _ensureDemoAccountByName(accountName, walletType);
    final existing = await _getTransactionsRaw();
    var createdCount = 0;

    for (final entry in entries) {
      final marker = '[MM_DEMO_BUNDLE item=${entry.idempotencyKey}]';
      final exists = existing.any(
        (row) =>
            (row['note'] ?? row['Note'] ?? '').toString().startsWith(marker),
      );
      if (exists) continue;

      final note = entry.note.trim().isEmpty
          ? '$marker ${entry.title.trim()}'
          : '$marker ${entry.title.trim()}\n${entry.note.trim()}';
      await _api.post('/api/transactions', {
        'accountId': accountId,
        'categoryId': entry.categoryId,
        'type': entry.type == TransactionType.income ? 1 : 0,
        'amount': entry.amount,
        'transactionDate': entry.date.toIso8601String(),
        'note': note,
        'visibility': 0,
        'sharedWithUserIds': <String>[],
      });
      createdCount++;
    }

    return createdCount;
  }

  Future<String> _ensureDemoAccountByName(
    String name,
    WalletType walletType,
  ) async {
    final data = await _api.get('/api/accounts');
    if (data is! List) {
      throw ApiException(500, 'API tài khoản trả về dữ liệu không hợp lệ.');
    }

    final expectedType = walletType == WalletType.bank ? 1 : 2;
    for (final item in data.whereType<Map>()) {
      final account = Map<String, dynamic>.from(item);
      if ((account['name'] ?? account['Name'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase() ==
              name.trim().toLowerCase() &&
          _int(account['type'] ?? account['Type']) == expectedType &&
          (account['isDemo'] ?? account['IsDemo']) == true) {
        return (account['id'] ?? account['Id']).toString();
      }
    }

    final result = await _api.post('/api/accounts', {
      'name': name.trim(),
      'type': expectedType,
      'openingBalance': 0,
      'isDemo': true,
    });
    if (result is! Map) {
      throw ApiException(500, 'Không tạo được tài khoản mẫu.');
    }
    return (result['id'] ?? result['Id']).toString();
  }

  Future<void> deleteTransaction(String id) =>
      _api.delete('/api/transactions/$id');

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
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
  const _DemoSample({
    required this.kind,
    required this.title,
    required this.amount,
    required this.category,
    required this.detail,
  });
}
