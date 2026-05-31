import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/loading_overlay.dart';

// Design Ref: §6.3 — 아이디 찾기 화면
// Plan SC: SC-04 — 이름+핸드폰 입력 시 마스킹 ID 표시
class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  final _nameController = TextEditingController();
  final _cellController = TextEditingController();
  bool _isLoading = false;
  String? _foundId;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _cellController.dispose();
    super.dispose();
  }

  Future<void> _onFindId() async {
    final name = _nameController.text.trim();
    final cell = _cellController.text.trim();

    if (name.isEmpty || cell.isEmpty) {
      setState(() => _errorMessage = '이름과 핸드폰번호를 모두 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _foundId = null;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.post(ApiConfig.findId, {
        'user_name': name,
        'user_cell': cell,
      });

      if (!mounted) return;

      if (data['resultCode'] == '200') {
        final res = data['res'] as Map<String, dynamic>;
        setState(() => _foundId = res['user_id'] as String);
      } else {
        setState(() => _errorMessage = '일치하는 계정을 찾을 수 없습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '네트워크 연결을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          '아이디 찾기',
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
              const Text(
                '이름과 핸드폰번호를 입력하세요',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF3A3A3A),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel('이름'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(
                  hint: '이름을 입력하세요',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('핸드폰번호'),
              const SizedBox(height: 8),
              TextField(
                controller: _cellController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  hint: '핸드폰번호를 입력하세요 (하이픈 없이)',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onFindId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2E5C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '아이디 찾기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_foundId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Color(0xFF4CAF50), size: 32),
                      const SizedBox(height: 12),
                      const Text(
                        '조회된 아이디',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _foundId!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B2E5C),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '로그인 화면으로',
                          style: TextStyle(
                            color: Color(0xFF1B2E5C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF9A9A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFE53935), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ],
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
}
