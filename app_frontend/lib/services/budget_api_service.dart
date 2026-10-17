import '../models/api_budget_model.dart';
import 'api_client.dart';

class BudgetApiService {
  BudgetApiService._();
  static final BudgetApiService instance = BudgetApiService._();
  final ApiClient _api = ApiClient.instance;

  Future<List<ApiBudget>> getBudgets() async {
    final data = await _api.get('/api/budgets');
    if (data is! List)
      throw ApiException(500, 'API ngân sách trả về dữ liệu không hợp lệ.');
    return data
        .whereType<Map>()
        .map((item) => ApiBudget.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<BudgetCategory>> getExpenseCategories() async {
    final data = await _api.get('/api/categories');
    if (data is! List)
      throw ApiException(500, 'API danh mục trả về dữ liệu không hợp lệ.');
    return data
        .whereType<Map>()
        .map((item) => BudgetCategory.fromJson(Map<String, dynamic>.from(item)))
        .where((c) => c.type == 0)
        .toList();
  }

  Future<void> createBudget(ApiBudget budget) async {
    await _api.post('/api/budgets', budget.toRequestJson());
  }

  Future<void> updateBudget(ApiBudget budget) async {
    await _api.put('/api/budgets/${budget.id}', budget.toRequestJson());
  }

  Future<void> deleteBudget(String id) => _api.delete('/api/budgets/$id');
}
