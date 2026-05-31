import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_overlay.dart';
import '../login_screen.dart';

// Design Ref: §6.7 — 비밀번호 변경 화면
// Plan SC: SC-07 — 비밀번호 변경 성공 후 재로그인
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  final _confirmPwController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> _onChangePassword() async {
    final currentPw = _currentPwController.text;
    final newPw = _newPwController.text;
    final confirmPw = _confirmPwController.text;

    if (currentPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
      _showSnackBar('모든 항목을 입력해주세요.');
      return;
    }
    if (newPw.length < 6) {
      _showSnackBar('새 비밀번호는 6자 이상이어야 합니다.');
      return;
    }
    if (newPw != confirmPw) {
      _showSnackBar('새 비밀번호가 일치하지 않습니다.');
      return;
    }

    final userId = AuthService().currentUser?.userId;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await ApiService.post(ApiConfig.changePassword, {
        'user_id': userId,
        'current_password': currentPw,
        'new_password': newPw,
      });

      if (!mounted) return;

      if (data['resultCode'] == '200') {
        await _showSuccessAndLogout();
      } else {
        final code = data['resultCode'].toString();
        final message = switch (code) {
          '300' => '현재 비밀번호가 일치하지 않습니다.',
          '401' => '현재 비밀번호와 동일한 비밀번호입니다.',
          _ => '새 비밀번호는 6자 이상이어야 합니다.',
        };
        _showSnackBar(message);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('네트워크 연결을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessAndLogout() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 변경 완료'),
        content: const Text('비밀번호가 변경되었습니다.\n다시 로그인해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await AuthService().logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2E5C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '비밀번호 변경',
          style: TextStyle(
            color: Color(0xFF1B2E5C),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              _buildLabel('현재 비밀번호'),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _currentPwController,
                hint: '현재 비밀번호를 입력하세요',
                obscure: _obscureCurrent,
                onToggle: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 20),

              _buildLabel('새 비밀번호 (6자 이상)'),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _newPwController,
                hint: '새 비밀번호를 입력하세요',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
              ),
              const SizedBox(height: 20),

              _buildLabel('새 비밀번호 확인'),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _confirmPwController,
                hint: '새 비밀번호를 다시 입력하세요',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2E5C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '비밀번호 변경',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3A3A3A),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
        prefixIcon:
            Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade400),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade400,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFFAF8F0),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1B2E5C), width: 1.5),
        ),
      ),
    );
  }
}
