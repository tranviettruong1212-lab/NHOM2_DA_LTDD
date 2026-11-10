import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../services/api_client.dart';
import '../services/app_backends.dart';

class ApprovalRequestsScreen extends StatefulWidget {
  const ApprovalRequestsScreen({super.key});

  @override
  State<ApprovalRequestsScreen> createState() => _ApprovalRequestsScreenState();
}

class _ApprovalRequestsScreenState extends State<ApprovalRequestsScreen> {
  final ApiClient _api = ApiClient.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/api/approval-requests');
      if (res is List) {
        if (!mounted) return;
        setState(() {
          _requests = res
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) return 'Hết phiên đăng nhập. Vui lòng đăng nhập lại.';
      if (error.statusCode == 403) return 'Bạn không có quyền duyệt chi trong gia đình.';
      return error.message;
    }
    return 'Lỗi kết nối: $error';
  }

  Future<void> _review(Map<String, dynamic> req, bool approve) async {
    final id = (req['id'] ?? req['Id'])?.toString();
    if (id == null) return;

    final noteController = TextEditingController();
    final actionLabel = approve ? 'Duyệt chi' : 'Từ chối';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$actionLabel giao dịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Bạn có chắc chắn muốn duyệt khoản chi này không?'
                  : 'Vui lòng nhập lý do từ chối (tùy chọn):',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Ghi chú / Lý do',
                hintText: approve ? 'Đồng ý duyệt' : 'Chi tiêu không cần thiết...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: approve ? const Color(0xFF107C41) : Theme.of(context).colorScheme.error,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(id));

    try {
      final endpoint = approve ? '/api/approval-requests/$id/approve' : '/api/approval-requests/$id/reject';
      await _api.post(endpoint, {
        'reviewNote': noteController.text.trim().isEmpty ? null : noteController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Đã duyệt giao dịch thành công.' : 'Đã từ chối giao dịch.'),
          backgroundColor: approve ? const Color(0xFF107C41) : Colors.black87,
        ),
      );

      // Đồng bộ lại dữ liệu
      await MoneyMateBackend.instance.loadFromApi();
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xử lý thất bại: ${_friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt chi tiêu gia đình'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadRequests,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, size: 56, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Không có yêu cầu chờ duyệt',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tất cả các khoản chi tiêu lớn của thành viên đều đã được xử lý.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final item = _requests[index];
        final id = (item['id'] ?? item['Id'])?.toString() ?? '';
        final isBusy = _processingIds.contains(id);
        final requester = (item['requesterName'] ?? item['RequesterName'] ?? 'Thành viên').toString();
        final amount = (item['amount'] ?? item['Amount'] as num?)?.toDouble() ?? 0.0;
        final category = (item['categoryName'] ?? item['CategoryName'] ?? 'Chi tiêu').toString();
        final note = (item['note'] ?? item['Note'] ?? '').toString();
        final rawDate = (item['transactionDate'] ?? item['TransactionDate'] ?? '').toString();
        final date = DateTime.tryParse(rawDate) ?? DateTime.now();
        final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE0E7FF),
                      child: Text(
                        requester.isNotEmpty ? requester[0].toUpperCase() : 'M',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2457C5)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requester,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Ngày giao dịch: $dateStr',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD8A8)),
                      ),
                      child: const Text(
                        'Chờ duyệt',
                        style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Số tiền đề xuất:',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    Text(
                      CurrencyFormat.format(amount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Chip(
                      label: Text(category),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ghi chú: $note',
                    style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isBusy ? null : () => _review(item, false),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isBusy ? null : () => _review(item, true),
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Duyệt chi'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF107C41),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

