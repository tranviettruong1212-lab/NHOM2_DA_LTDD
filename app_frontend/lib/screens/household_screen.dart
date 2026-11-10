import 'package:flutter/material.dart';

import '../core/currency_format.dart';
import '../services/api_client.dart';
import 'approval_requests_screen.dart';
import 'invitations_screen.dart';
import 'household_dialogs.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final ApiClient _api = ApiClient.instance;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _household;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _notifications = [];
  int _pendingApprovalCount = 0;

  dynamic _value(Map<String, dynamic> data, String camel, String pascal) =>
      data[camel] ?? data[pascal];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    Map<String, dynamic>? household;
    List<Map<String, dynamic>> members = [];
    List<Map<String, dynamic>> notifications = [];
    int pendingCount = 0;
    String? error;

    try {
      final result = await _api.get('/api/households/mine');

      if (result is Map) {
        household = Map<String, dynamic>.from(result);

        final id = _value(household, 'householdId', 'HouseholdId')?.toString();

        if (id != null && id.isNotEmpty) {
          final memberResult = await _api.get('/api/households/$id/members');

          if (memberResult is List) {
            members = memberResult
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
          }

          final role = _value(household, 'role', 'Role');
          final roleNum = role is num ? role.toInt() : int.tryParse(role?.toString() ?? '') ?? 2;
          final canApprove = roleNum == 0 || _value(household, 'canApproveExpenses', 'CanApproveExpenses') == true;
          if (canApprove) {
            try {
              final approvals = await _api.get('/api/approval-requests');
              if (approvals is List) {
                pendingCount = approvals.length;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      error = _friendlyError(e);
    }

    try {
      final notificationResult = await _api.get(
        '/api/households/notifications',
      );
      if (notificationResult is List) {
        notifications = notificationResult
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      error ??= _friendlyError(e);
    }

    if (!mounted) return;

    setState(() {
      _household = household;
      _members = members;
      _notifications = notifications;
      _pendingApprovalCount = pendingCount;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _createHousehold() async {
    final values = await showCreateHouseholdDialog(context);

    if (!mounted || values == null) return;

    await _runBusy(() async {
      await _api.post('/api/households', values);
      await _load();

      if (mounted) {
        _message('Đã tạo nhóm gia đình.');
      }
    });
  }

  Future<void> _addMember() async {
    final household = _household;
    if (household == null) return;

    final householdId = _value(
      household,
      'householdId',
      'HouseholdId',
    )?.toString();

    if (householdId == null || householdId.isEmpty) {
      _message('Không tìm thấy mã nhóm gia đình.');
      return;
    }

    final values = await showAddHouseholdMemberDialog(context);

    if (!mounted || values == null) return;

    await _runBusy(() async {
      await _api.post('/api/households/$householdId/members', values);

      await _load();

      if (mounted) {
        _message('Đã thêm thành viên vào nhóm.');
      }
    });
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    final householdId = _value(
      _household!,
      'householdId',
      'HouseholdId',
    ).toString();
    final userId = _value(member, 'userId', 'UserId').toString();
    final name =
        _value(member, 'displayName', 'DisplayName')?.toString() ??
        'thành viên này';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thành viên?'),
        content: Text('Bạn muốn xóa $name khỏi nhóm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _runBusy(() async {
      await _api.delete('/api/households/$householdId/members/$userId');
      await _load();
      _message('Đã xóa thành viên khỏi nhóm.');
    });
  }

  Future<void> _cancelHousehold() async {
    final household = _household;
    if (household == null) return;
    final householdId = _value(
      household,
      'householdId',
      'HouseholdId',
    ).toString();
    final name =
        (_value(household, 'householdName', 'HouseholdName') ?? 'nhóm gia đình')
            .toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy nhóm gia đình?'),
        content: Text(
          'Nhóm "$name" sẽ ngừng hoạt động và tất cả thành viên sẽ được rời nhóm. '
          'Lịch sử giao dịch và ngân sách sẽ được giữ lại; các thành viên sẽ nhận thông báo trong ứng dụng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy nhóm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      await _api.post('/api/households/$householdId/cancel', {});
      await _load();
      _message(
        'Đã hủy nhóm. Lịch sử được giữ lại và thành viên đã được thông báo.',
      );
    });
  }

  Future<void> _markNotificationRead(String notificationId) async {
    await _runBusy(() async {
      await _api.post('/api/households/notifications/$notificationId/read', {});
      await _load();
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _message(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      switch (error.message) {
        case 'user_not_registered':
          return 'Email này chưa đăng ký hoặc chưa đăng nhập vào MoneyMate lần nào.';
        case 'user_already_in_household':
          return 'Người dùng đã thuộc một nhóm gia đình khác.';
        case 'already_in_household':
          return 'Bạn đã thuộc một nhóm gia đình.';
        case 'cannot_remove_owner':
          return 'Không thể xóa chủ nhóm.';
        case 'household_notifications_schema_missing':
          return 'Database chưa có bảng thông báo nhóm. Hãy chạy script app_doc/SQLQuery2_HouseholdNotifications.sql trên database MoneyMate rồi tải lại.';
        default:
          return 'API ${error.statusCode}: ${error.message}';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  String _roleName(dynamic role) => switch (role is num
      ? role.toInt()
      : int.tryParse(role?.toString() ?? '') ?? 2) {
    0 => 'Chủ nhóm',
    1 => 'Quản trị viên',
    _ => 'Thành viên',
  };

  @override
  Widget build(BuildContext context) {
    final household = _household;
    final householdName = household == null
        ? ''
        : (_value(household, 'householdName', 'HouseholdName') ?? 'Gia đình')
              .toString();
    final role = household == null
        ? 2
        : (_value(household, 'role', 'Role') is num
              ? (_value(household, 'role', 'Role') as num).toInt()
              : int.tryParse(
                      _value(household, 'role', 'Role')?.toString() ?? '',
                    ) ??
                    2);
    final canManage = role == 0 || role == 1;
    final threshold = household == null
        ? 0.0
        : double.tryParse(
                _value(
                      household,
                      'approvalThreshold',
                      'ApprovalThreshold',
                    )?.toString() ??
                    '',
              ) ??
              0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gia đình & thành viên'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: household != null && canManage
          ? FloatingActionButton.extended(
              heroTag: 'household-add-member-fab',
              onPressed: _busy ? null : _addMember,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Thêm thành viên'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                        ),
                        title: const Text('Không tải được dữ liệu'),
                        subtitle: Text(_error!),
                        trailing: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  if (_notifications.isNotEmpty) ...[
                    Text(
                      'Thông báo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ..._notifications.map((notification) {
                      final readAt = _value(notification, 'readAt', 'ReadAt');
                      final id = _value(notification, 'id', 'Id').toString();
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            readAt == null
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_none,
                            color: readAt == null
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            (_value(notification, 'title', 'Title') ??
                                    'Thông báo')
                                .toString(),
                          ),
                          subtitle: Text(
                            (_value(notification, 'message', 'Message') ?? '')
                                .toString(),
                          ),
                          trailing: readAt == null
                              ? IconButton(
                                  tooltip: 'Đánh dấu đã đọc',
                                  onPressed: _busy
                                      ? null
                                      : () => _markNotificationRead(id),
                                  icon: const Icon(Icons.done),
                                )
                              : null,
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  if (household == null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.groups_outlined, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'Bạn chưa tham gia nhóm gia đình',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tạo một nhóm để quản lý thành viên và giao dịch chung.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _busy ? null : _createHousehold,
                              icon: const Icon(Icons.add),
                              label: const Text('Tạo nhóm gia đình'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.home_work_outlined),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    householdName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Vai trò của bạn: ${_roleName(role)}'),
                            const SizedBox(height: 4),
                            Text(
                              'Ngưỡng duyệt chi: ${CurrencyFormat.format(threshold)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (role == 0 || (_value(household, 'canApproveExpenses', 'CanApproveExpenses') == true)) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: _pendingApprovalCount > 0 ? const Color(0xFFFFF7ED) : null,
                        child: ListTile(
                          leading: Badge(
                            isLabelVisible: _pendingApprovalCount > 0,
                            label: Text('$_pendingApprovalCount'),
                            child: const Icon(Icons.fact_check_outlined, color: Color(0xFF2457C5)),
                          ),
                          title: const Text('Phê duyệt chi tiêu gia đình', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            _pendingApprovalCount > 0
                                ? '$_pendingApprovalCount yêu cầu chi tiêu đang chờ duyệt'
                                : 'Không có yêu cầu chờ duyệt',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ApprovalRequestsScreen(),
                              ),
                            );
                            _load();
                          },
                        ),
                      ),
                    ],
                    if (role == 0) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _cancelHousehold,
                        icon: const Icon(Icons.group_remove_outlined),
                        label: const Text('Hủy nhóm gia đình'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Thành viên (${_members.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (_members.isEmpty)
                      const Card(
                        child: ListTile(title: Text('Chưa có thành viên')),
                      ),
                    ..._members.map((member) {
                      final name =
                          (_value(member, 'displayName', 'DisplayName') ??
                                  'Người dùng')
                              .toString();
                      final email =
                          (_value(member, 'email', 'Email') ?? 'Không có email')
                              .toString();
                      final memberRole = _value(member, 'role', 'Role');
                      final memberRoleNum = memberRole is num
                          ? memberRole.toInt()
                          : int.tryParse(memberRole?.toString() ?? '') ?? 2;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(
                            '$email\n${_roleName(memberRole)}${_value(member, 'canViewIncomeDetails', 'CanViewIncomeDetails') == true ? ' • Xem thu nhập' : ''}${_value(member, 'canApproveExpenses', 'CanApproveExpenses') == true ? ' • Duyệt chi' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: canManage && memberRoleNum != 0
                              ? IconButton(
                                  tooltip: 'Xóa thành viên',
                                  onPressed: _busy
                                      ? null
                                      : () => _removeMember(member),
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                    color: Colors.red,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.mark_email_unread_outlined),
                        ),
                        title: const Text(
                          'Lời mời thành viên (giao diện mô phỏng)',
                        ),
                        subtitle: const Text(
                          'Xem thử trạng thái chờ, chấp nhận và từ chối.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      const InvitationsScreen(),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Lưu ý: chức năng Thêm thành viên gọi API thật và thêm ngay người đã đăng ký. Màn hình Lời mời là prototype, chưa gửi email và chưa lưu lời mời vào SQL Server.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    );
  }
}
