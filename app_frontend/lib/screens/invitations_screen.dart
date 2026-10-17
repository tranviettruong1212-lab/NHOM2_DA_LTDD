import 'package:flutter/material.dart';

/// Giao diện prototype cho lời mời. API backend hiện chưa có bảng Invitation,
/// vì vậy danh sách này chỉ tồn tại trong phiên mở màn hình.
class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  final _emailController = TextEditingController();
  final List<_DemoInvitation> _invitations = [];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendDemoInvitation() {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email hợp lệ.')),
      );
      return;
    }
    if (_invitations.any((i) => i.email.toLowerCase() == email.toLowerCase() && i.status == 'Đang chờ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email này đã có lời mời đang chờ trong bản mô phỏng.')),
      );
      return;
    }
    setState(() {
      _invitations.insert(0, _DemoInvitation(email: email, createdAt: DateTime.now()));
      _emailController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tạo lời mời mẫu trên giao diện. Chưa gửi email thật.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Lời mời thành viên')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'GIAO DIỆN MÔ PHỎNG\n'
                    'Backend hiện chưa có API/bảng lưu lời mời. Các lời mời ở màn hình này chỉ lưu tạm trong phiên và không gửi email thật. '
                    'Để thêm thành viên thật, quay lại màn hình Gia đình và dùng chức năng Thêm thành viên với email đã đăng ký.',
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text('Tạo lời mời mẫu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email người được mời',
                hintText: 'ten@example.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              onSubmitted: (_) => _sendDemoInvitation(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _sendDemoInvitation,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Tạo lời mời mô phỏng'),
            ),
            const SizedBox(height: 24),
            Text('Danh sách lời mời (${_invitations.length})', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_invitations.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Chưa có lời mời mẫu. Nhập email ở trên để xem giao diện trạng thái.'))),
            ..._invitations.map((invite) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(invite.status == 'Đang chờ' ? Icons.mark_email_unread_outlined : invite.status == 'Đã chấp nhận' ? Icons.check : Icons.mail_outline)),
                    title: Text(invite.email),
                    subtitle: Text('Tạo lúc ${invite.createdAt.day.toString().padLeft(2, '0')}/${invite.createdAt.month.toString().padLeft(2, '0')} • ${invite.status}'),
                    trailing: invite.status == 'Đang chờ'
                        ? PopupMenuButton<String>(
                            onSelected: (value) => setState(() {
                              if (value == 'accepted') invite.status = 'Đã chấp nhận';
                              if (value == 'declined') invite.status = 'Đã từ chối';
                              if (value == 'cancel') _invitations.remove(invite);
                            }),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'accepted', child: Text('Mô phỏng chấp nhận')),
                              PopupMenuItem(value: 'declined', child: Text('Mô phỏng từ chối')),
                              PopupMenuItem(value: 'cancel', child: Text('Hủy lời mời mẫu')),
                            ],
                          )
                        : null,
                  ),
                )),
          ],
        ),
      );
}

class _DemoInvitation {
  final String email;
  final DateTime createdAt;
  String status;
  _DemoInvitation({required this.email, required this.createdAt, this.status = 'Đang chờ'});
}
