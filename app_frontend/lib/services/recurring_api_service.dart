import '../models/recurring_transaction_model.dart';
import 'api_client.dart';

class RecurringApiService {
  RecurringApiService._();
  static final RecurringApiService instance = RecurringApiService._();

  final ApiClient _api = ApiClient.instance;

  Future<List<RecurringTransaction>> getRecurringTransactions({bool? activeOnly}) async {
    final query = activeOnly != null ? '?activeOnly=$activeOnly' : '';
    final res = await _api.get('/api/recurring-transactions$query');
    if (res is! List) return [];
    return res
        .whereType<Map>()
        .map((e) => RecurringTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RecurringTransaction> getRecurringById(String id) async {
    final res = await _api.get('/api/recurring-transactions/$id');
    if (res is! Map) throw ApiException(500, 'Không tìm thấy thông tin giao dịch định kỳ.');
    return RecurringTransaction.fromJson(Map<String, dynamic>.from(res));
  }

  Future<RecurringTransaction> createRecurring(Map<String, dynamic> data) async {
    final res = await _api.post('/api/recurring-transactions', data);
    if (res is! Map) throw ApiException(500, 'Tạo giao dịch định kỳ không thành công.');
    return RecurringTransaction.fromJson(Map<String, dynamic>.from(res));
  }

  Future<RecurringTransaction> updateRecurring(String id, Map<String, dynamic> data) async {
    final res = await _api.put('/api/recurring-transactions/$id', data);
    if (res is! Map) throw ApiException(500, 'Cập nhật giao dịch định kỳ không thành công.');
    return RecurringTransaction.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> deleteRecurring(String id) async {
    await _api.delete('/api/recurring-transactions/$id');
  }

  Future<RecurringTransaction> toggleActive(String id) async {
    final res = await _api.post('/api/recurring-transactions/$id/toggle', {});
    if (res is! Map) throw ApiException(500, 'Không thể đổi trạng thái giao dịch định kỳ.');
    return RecurringTransaction.fromJson(Map<String, dynamic>.from(res));
  }

  Future<Map<String, dynamic>> executeRecurring(String id) async {
    final res = await _api.post('/api/recurring-transactions/$id/execute', {});
    if (res is! Map) return {};
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> processDue() async {
    final res = await _api.post('/api/recurring-transactions/process-due', {});
    if (res is! Map) return {'processedCount': 0};
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final res = await _api.get('/api/accounts');
    if (res is! List) return [];
    return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getCategories(int type) async {
    final res = await _api.get('/api/categories?type=$type');
    if (res is! List) return [];
    return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}

