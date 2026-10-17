import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showCreateHouseholdDialog(BuildContext context) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _CreateHouseholdDialog(),
  );
}

class _CreateHouseholdDialog extends StatefulWidget {
  const _CreateHouseholdDialog();

  @override
  State<_CreateHouseholdDialog> createState() => _CreateHouseholdDialogState();
}

class _CreateHouseholdDialogState extends State<_CreateHouseholdDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _thresholdController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _thresholdController = TextEditingController(text: '1000000');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_thresholdController.text.trim());

    Navigator.of(context).pop(<String, dynamic>{
      'name': _nameController.text.trim(),
      'approvalThreshold': amount,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo nhóm gia đình'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Tên nhóm'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Nhập tên nhóm' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _thresholdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Ngưỡng cần duyệt chi (VNĐ)',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    return n == null || !n.isFinite || n < 0
                        ? 'Nhập số tiền hợp lệ'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Tạo nhóm')),
      ],
    );
  }
}

Future<Map<String, dynamic>?> showAddHouseholdMemberDialog(
  BuildContext context,
) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => const _AddHouseholdMemberDialog(),
  );
}

class _AddHouseholdMemberDialog extends StatefulWidget {
  const _AddHouseholdMemberDialog();

  @override
  State<_AddHouseholdMemberDialog> createState() =>
      _AddHouseholdMemberDialogState();
}

class _AddHouseholdMemberDialogState extends State<_AddHouseholdMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  String _role = '2';
  bool _canViewIncome = false;
  bool _canApprove = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(<String, dynamic>{
      'email': _emailController.text.trim(),
      'role': int.parse(_role),
      'canViewIncomeDetails': _canViewIncome,
      'canApproveExpenses': _canApprove,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mời / thêm thành viên'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Email phải thuộc tài khoản MoneyMate đã đăng ký. '
                  'API hiện tại thêm thành viên ngay, chưa có bước '
                  'chấp nhận lời mời.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email thành viên',
                  ),
                  validator: (v) {
                    final email = v?.trim() ?? '';
                    return !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(email)
                        ? 'Email không hợp lệ'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('Quản trị viên')),
                    DropdownMenuItem(value: '2', child: Text('Thành viên')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _role = value);
                    }
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _canViewIncome,
                  onChanged: (value) =>
                      setState(() => _canViewIncome = value ?? false),
                  title: const Text('Được xem chi tiết thu nhập'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _canApprove,
                  onChanged: (value) =>
                      setState(() => _canApprove = value ?? false),
                  title: const Text('Được duyệt chi tiêu'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Thêm thành viên')),
      ],
    );
  }
}
