import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_service.dart';
import '../services/database_models.dart' as models;
import '../widgets/space_background.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const AuthScreen({super.key, this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final DatabaseService _db = DatabaseService();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Защита от двойного нажатия
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      models.User? user;

      if (_isLogin) {
        user = await _db.loginUser(email: email, password: password);
        if (user == null) {
          _errorMessage = 'Неверный email или пароль';
        }
      } else {
        final name = _nameController.text.trim();
        final confirmPassword = _confirmPasswordController.text.trim();

        if (password != confirmPassword) {
          _errorMessage = 'Пароли не совпадают';
          setState(() {
            _isLoading = false;
          });
          return;
        }

        user = await _db.registerUser(
          name: name,
          email: email,
          password: password,
        );
        if (user == null) {
          _errorMessage =
              'Не удалось зарегистрироваться. Возможно, email уже занят.';
        }
      }

      if (user != null && mounted) {
        // Save user session
        final prefs = await SharedPreferences.getInstance();
        if (user.id != null) {
          await prefs.setInt('userId', user.id!);
        }

        widget.onAuthSuccess?.call();
        Navigator.of(context).pop(user);
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo / Title
                              Center(
                                child: Text(
                                  'Sportsense',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1A2E),
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  _isLogin
                                      ? 'Добро пожаловать обратно'
                                      : 'Создайте аккаунт',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Name field (only for registration)
                              if (!_isLogin)
                                _AnimatedField(
                                  isVisible: !_isLogin,
                                  child: TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Имя',
                                      prefixIcon: const Icon(
                                        Icons.person_outline,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Введите имя';
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                              if (!_isLogin) const SizedBox(height: 16),

                              // Email field
                              _AnimatedField(
                                isVisible: true,
                                child: TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Введите email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Неверный email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password field
                              _AnimatedField(
                                isVisible: true,
                                child: TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: 'Пароль',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Введите пароль';
                                    }
                                    if (value.trim().length < 6) {
                                      return 'Минимум 6 символов';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password (only for register)
                              if (!_isLogin)
                                _AnimatedField(
                                  isVisible: !_isLogin,
                                  child: TextFormField(
                                    controller: _confirmPasswordController,
                                    decoration: InputDecoration(
                                      labelText: 'Подтвердите пароль',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    obscureText: _obscureConfirmPassword,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Подтвердите пароль';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Пароли не совпадают';
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                              // Error message
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                _ErrorBox(message: _errorMessage!),
                              ],

                              const SizedBox(height: 28),

                              // Submit button
                              _GradientButton(
                                onPressed: _isLoading ? null : _submit,
                                isLoading: _isLoading,
                                text: _isLogin ? 'Войти' : 'Создать аккаунт',
                              ),

                              const SizedBox(height: 16),

                              // Toggle mode
                              TextButton(
                                onPressed: _isLoading ? null : _toggleMode,
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _isLogin
                                            ? 'Нет аккаунта? '
                                            : 'Уже есть аккаунт? ',
                                      ),
                                      TextSpan(
                                        text: _isLogin
                                            ? 'Зарегистрироваться'
                                            : 'Войти',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4A90E2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedField extends StatelessWidget {
  final Widget child;
  final bool isVisible;

  const _AnimatedField({required this.child, required this.isVisible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: isVisible ? child : const SizedBox.shrink(),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFB37B7B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFB37B7B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFB37B7B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFB37B7B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const _GradientButton({
    required this.onPressed,
    required this.isLoading,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF3BA99C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3BA99C).withOpacity(isDark ? 0.25 : 0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
