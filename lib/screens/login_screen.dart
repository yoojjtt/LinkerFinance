import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/loading_overlay.dart';
import 'find_id_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';

// Design Ref: §6.2 — LoginScreen API 연동
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _autoLogin = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Column(
            children: [
              // 상단 헤더
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2E5C),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'L',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LINKER.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B2E5C),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.account_balance_outlined,
                            size: 20, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '재무 관리 로그인',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 메인 콘텐츠
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // 로그인 카드
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B2E5C),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_outlined,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'LINKER FINANCE',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B2E5C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '재무 관리 시스템 로그인',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B6B6B),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // 아이디 입력
                            _buildLabel('아이디'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _idController,
                              decoration: _inputDecoration(
                                hint: '아이디를 입력하세요',
                                icon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 비밀번호 입력
                            _buildLabel('비밀번호'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _pwController,
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                hint: '비밀번호를 입력하세요',
                                icon: Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 자동 로그인
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _autoLogin,
                                    onChanged: (v) =>
                                        setState(() => _autoLogin = v ?? false),
                                    activeColor: const Color(0xFF1B2E5C),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '자동 로그인',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF3A3A3A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 로그인 버튼
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _onLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD700),
                                  foregroundColor: const Color(0xFF1B2E5C),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '로그인',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.login, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 아이디 찾기 / 비밀번호 재설정
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const FindIdScreen()),
                                  ),
                                  child: const Text(
                                    '아이디 찾기',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  ),
                                ),
                                Text('|',
                                    style: TextStyle(
                                        color: Colors.grey.shade300,
                                        fontSize: 13)),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ResetPasswordScreen()),
                                  ),
                                  child: const Text(
                                    '비밀번호 재설정',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 보안 주의사항
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFECB3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield,
                                color: Color(0xFFE8A800), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '보안 주의사항',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3A3A3A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '인가되지 않은 사용자의 접근은 법적 처벌의 대상이 될 수 있습니다. '
                                    '공용 PC 사용 시 로그아웃 상태를 반드시 확인하십시오.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 하단 저작권
                      Text(
                        '\u00a9 2024 모든 권리 보유. 재무 관리 시스템.',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _footerLink('보안 정책'),
                          _footerDot(),
                          _footerLink('시스템 상태'),
                          _footerDot(),
                          _footerLink('지원 센터'),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3A3A3A),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFFAF8F0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

  Widget _footerLink(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
    );
  }

  Widget _footerDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text('\u00b7',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
    );
  }

  // Plan SC: SC-01, SC-02 — 로그인 API 연동
  Future<void> _onLogin() async {
    final username = _idController.text.trim();
    final password = _pwController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('아이디와 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthService().login(username, password);
      if (!mounted) return;

      if (result.success) {
        if (_autoLogin) {
          await AuthService().saveAutoLogin(username, password);
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showSnackBar(result.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('네트워크 연결을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
