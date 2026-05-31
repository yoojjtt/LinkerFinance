import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../widgets/loading_overlay.dart';
import '../login_screen.dart';
import 'change_password_screen.dart';

// Design Ref: §6.6 — 내 정보 조회/수정 화면
// Plan SC: SC-06 (정보 표시), SC-08 (연락처/이메일 변경), SC-09 (로그아웃)
class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  bool _isLoading = false;
  UserModel? _user;
  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadMyInfo();
    _loadPushSetting();
  }

  Future<void> _loadPushSetting() async {
    final enabled = await FcmService().getPushEnabled();
    if (mounted) setState(() => _pushEnabled = enabled);
  }

  Future<void> _onPushToggle(bool value) async {
    final previous = _pushEnabled;
    setState(() {
      _pushEnabled = value;
      _isLoading = true;
    });
    try {
      await FcmService().setPushEnabled(value);
    } catch (_) {
      if (mounted) {
        setState(() => _pushEnabled = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알림 설정 변경에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyInfo() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService().refreshMyInfo();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('정보를 불러오는데 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editField(String field, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final label = field == 'user_email' ? '이메일' : '핸드폰번호';
    final keyboardType = field == 'user_email'
        ? TextInputType.emailAddress
        : TextInputType.phone;

    final newValue = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label 변경'),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: '새 $label을 입력하세요',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('변경'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newValue == null || newValue.isEmpty || newValue == currentValue) return;

    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{'user_id': _user!.userId};
      body[field] = newValue;

      final data = await ApiService.post(ApiConfig.updateProfile, body);
      if (!mounted) return;

      if (data['resultCode'] == '200') {
        AuthService().currentUser =
            UserModel.fromJson(data['res'] as Map<String, dynamic>);
        setState(() => _user = AuthService().currentUser);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label이(가) 변경되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('변경에 실패했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네트워크 연결을 확인해주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    await AuthService().logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? AuthService().currentUser;

    return LoadingOverlay(
      isLoading: _isLoading,
      child: user == null
          ? const Center(child: Text('사용자 정보를 불러올 수 없습니다.'))
          : RefreshIndicator(
              onRefresh: _loadMyInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 프로필 카드
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2E5C),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              user.userName.isNotEmpty
                                  ? user.userName[0]
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.userName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.userUUID,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${user.userLevelName} \u00b7 ${user.userTypeName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 연락처 정보
                    _buildSection('연락처 정보', [
                      _buildInfoRow(
                        '이메일',
                        user.userEmail ?? '-',
                        onEdit: () => _editField(
                            'user_email', user.userEmail ?? ''),
                      ),
                      _buildInfoRow(
                        '핸드폰',
                        user.userCell ?? '-',
                        onEdit: () =>
                            _editField('user_cell', user.userCell ?? ''),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // 주소
                    _buildSection('주소', [
                      _buildInfoRow(
                        '주소',
                        [user.userAddress, user.userAddressDetail]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' '),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // 은행 정보
                    _buildSection('은행 정보', [
                      _buildInfoRow(
                          '은행', user.userBankName ?? '-'),
                      _buildInfoRow(
                          '계좌번호', user.userBankAccount ?? '-'),
                      _buildInfoRow(
                          '예금주', user.userBankHolder ?? '-'),
                    ]),
                    const SizedBox(height: 12),

                    // 알림 설정
                    _buildSection('알림 설정', [
                      Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              '푸시 알림',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Switch.adaptive(
                            value: _pushEnabled,
                            activeTrackColor: const Color(0xFF1B2E5C),
                            onChanged: _isLoading ? null : _onPushToggle,
                          ),
                        ],
                      ),
                      Text(
                        _pushEnabled
                            ? '재무 알림을 수신합니다.'
                            : '알림이 꺼져 있습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // 비밀번호 변경
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen()),
                        ),
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: const Text('비밀번호 변경'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B2E5C),
                          side: const BorderSide(color: Color(0xFF1B2E5C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 로그아웃
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _onLogout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('로그아웃'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2E5C),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF3A3A3A),
              ),
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Icon(Icons.edit_outlined,
                  size: 16, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }
}
