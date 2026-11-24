import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import 'chat_home_screen.dart';

class UsernameLoginScreen extends StatefulWidget {
  const UsernameLoginScreen({super.key});

  @override
  State<UsernameLoginScreen> createState() => _UsernameLoginScreenState();
}

class _UsernameLoginScreenState extends State<UsernameLoginScreen> {
  final _nameController = TextEditingController(text: 'Surya');
  final _usernameController = TextEditingController(text: 'surya_vibe');
  String? _errorText;
  bool _isSaving = false;

  String get _sanitizedHandle {
    final raw = _usernameController.text.trim().toLowerCase().replaceAll('@', '');
    return raw.replaceAll(RegExp(r'[^a-z0-9_.]'), '');
  }

  Future<void> _continueToChat() async {
    final handle = _sanitizedHandle;
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter your display name.');
      return;
    }
    if (handle.length < 3) {
      setState(() => _errorText = 'Username must be at least 3 characters.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    await FirebaseChatService.registerUsername(
      username: handle,
      displayName: name,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatHomeScreen(
          currentUsername: handle,
          currentDisplayName: name,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF111827),
              Color(0xFF0B0F19),
              Color(0xFF090D16),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.alternate_email_rounded,
                    color: Color(0xFF818CF8),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Claim your
@username',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'No phone number needed to connect. Share your unique handle and start chatting instantly.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    label: 'Display Name',
                    hint: 'e.g. Surya',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_@.]')),
                  ],
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                    setState(() {});
                  },
                  onSubmitted: (_) => _continueToChat(),
                  decoration: _inputDecoration(
                    label: 'Username',
                    hint: 'your_handle',
                    prefixText: '@',
                    prefixIcon: Icons.tag_rounded,
                    errorText: _errorText,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 16, color: Color(0xFF34D399)),
                    const SizedBox(width: 6),
                    Text(
                      'Your handle: @${_sanitizedHandle.isEmpty ? 'username' : _sanitizedHandle}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _continueToChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Enter Chat Space',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    String? prefixText,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixText: prefixText,
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF818CF8), size: 20),
      filled: true,
      fillColor: const Color(0xFF151C2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }
}
