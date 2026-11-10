import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'household_screen.dart';
import 'recurring_transactions_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _api = ApiClient.instance;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.get('/api/me');
      if (result is! Map) throw Exception('Dữ liệu hồ sơ không hợp lệ.');
      if (!mounted) return;
      setState(() => _profile = Map<String, dynamic>.from(result));
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(
      text: (_profile?['displayName'] ?? _profile?['DisplayName'] ?? '').toString(),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: TextField(
          controller: controller,
          maxLength: 150,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên hiển thị'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    if (name.isEmpty) {
      _message('Tên hiển thị không được để trống.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _api.put('/api/me', {'displayName': name});
      if (result is Map && mounted) {
        setState(() => _profile = Map<String, dynamic>.from(result));
      }
      _message('Đã cập nhật hồ sơ.');
    } catch (e) {
      _message(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ quay lại màn hình đăng nhập.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Ở lại')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (confirm == true) await FirebaseAuth.instance.signOut();
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final email = (_profile?['email'] ?? _profile?['Email'] ?? firebaseUser?.email ?? '—').toString();
    final displayName = (_profile?['displayName'] ?? _profile?['DisplayName'] ?? firebaseUser?.displayName ?? 'Người dùng').toString();
    final createdAt = _profile?['createdAt'] ?? _profile?['CreatedAt'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        actions: [IconButton(tooltip: 'Tải lại hồ sơ', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 38)),
                          const SizedBox(height: 12),
                          Text(displayName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(email, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _editDisplayName,
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(_saving ? 'Đang lưu...' : 'Đổi tên hiển thị'),
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(height: 8),
                            Text('Ngày tạo hồ sơ: ${_dateLabel(createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(child: ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: const Text('Không tải được hồ sơ'), subtitle: Text(_error!), trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)))),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                      title: const Text('Gia đình & thành viên'),
                      subtitle: const Text('Tạo nhóm, xem thành viên và thêm người đã đăng ký'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HouseholdScreen())),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.event_repeat_outlined)),
                      title: const Text('Giao dịch định kỳ'),
                      subtitle: const Text('Quản lý hóa đơn, tiền nhà, lương, dịch vụ tự động'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringTransactionsScreen())),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Đăng nhập bảo mật'),
                      subtitle: const Text('Xác thực bằng Firebase Authentication'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
    );
  }
}
