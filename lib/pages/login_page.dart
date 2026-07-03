import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/toast.dart';
import 'package:inter_knot/models/author.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final codeController = TextEditingController();

  bool isRegister = false;
  bool isLoading = false;
  bool isSendingCode = false;
  int _codeCooldownSeconds = 0;
  Timer? _codeCooldownTimer;
  String? error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _codeCooldownTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> _onLoginSuccess(String token, AuthorModel user) async {
    await box.write('access_token', token);

    // Update Controller state
    final c = Get.find<Controller>();
    AuthorModel currentUser = user;
    try {
      currentUser = await Get.find<Api>().getSelfUserInfo('');
    } catch (_) {}
    c.user(currentUser);
    await c.ensureAuthorForUser(currentUser);
    c.isLogin(true);

    // Refresh user data after login
    await c.refreshFavorites();
    await c.refreshUnreadNotificationCount();

    if (mounted) {
      Get.back();
      showToast('登录成功：欢迎回来，绳匠！');
    }
  }

  void _startCodeCooldown() {
    _codeCooldownTimer?.cancel();
    setState(() {
      _codeCooldownSeconds = 60;
    });
    _codeCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_codeCooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _codeCooldownSeconds = 0;
        });
        return;
      }
      setState(() {
        _codeCooldownSeconds -= 1;
      });
    });
  }

  Future<void> _sendRegisterCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        error = '请输入邮箱';
      });
      return;
    }

    setState(() {
      isSendingCode = true;
      error = null;
    });

    try {
      final res = await BaseConnect.authApi.sendRegisterCode(email);
      if (res.hasError) {
        throw Exception(res.statusText ?? '发送验证码失败');
      }
      _startCodeCooldown();
      showToast('验证码已发送，请查收邮箱');
    } catch (e, s) {
      logger.e('Send register code failed', error: e, stackTrace: s);
      setState(() {
        error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isSendingCode = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();
      final code = codeController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('请输入邮箱和密码');
      }
      if (isRegister) {
        if (code.isEmpty) {
          throw Exception('请输入邮箱验证码');
        }
        if (password != confirmPassword) {
          throw Exception('两次输入的密码不一致');
        }
      }

      final res = isRegister
          ? await BaseConnect.authApi.registerWithCode(
              email,
              code,
              password,
            )
          : await BaseConnect.authApi.login(
              email,
              password,
            );

      if (res.token != null) {
        await _onLoginSuccess(res.token!, res.user);
      } else if (!isRegister) {
        Get.back();
        showToast('登录失败：未获取到Token', isError: true);
      }
    } catch (e, s) {
      logger.e('Login failed', error: e, stackTrace: s);
      setState(() {
        final errorString = e.toString();
        if (errorString.contains('TypeError') || errorString.contains('Null')) {
          error = '应用状态异常，请尝试重新启动应用';
        } else {
          error = errorString.replaceAll('Exception: ', '');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shared ZZZ style input decoration
    final inputDecoration = InputDecoration(
      labelStyle: const TextStyle(color: Color(0xff808080)),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xff333333)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xffD7FF00)),
      ),
      border: const OutlineInputBorder(),
      prefixIconColor: const Color(0xffE0E0E0),
    );

    // Using Scaffold with backgroundColor transparent to act as a dialog content
    return GestureDetector(
      onTap: () => Get.back(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {},
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(59, 255, 255, 255),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xff1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isRegister ? '注册' : '登录',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 24),
                          if (error != null) ...[
                            Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: emailController,
                            style: const TextStyle(color: Color(0xffE0E0E0)),
                            decoration: inputDecoration.copyWith(
                              labelText: '邮箱',
                              prefixIcon: const Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction:
                                isRegister ? TextInputAction.next : TextInputAction.done,
                            onSubmitted: isRegister ? null : (_) => _submit(),
                          ),
                          if (isRegister) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: codeController,
                                    style: const TextStyle(color: Color(0xffE0E0E0)),
                                    decoration: inputDecoration.copyWith(
                                      labelText: '邮箱验证码',
                                      prefixIcon: const Icon(Icons.verified),
                                    ),
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 56,
                                  child: FilledButton(
                                    onPressed: (isSendingCode || _codeCooldownSeconds > 0)
                                        ? null
                                        : _sendRegisterCode,
                                    child: Text(
                                      isSendingCode
                                          ? '发送中'
                                          : (_codeCooldownSeconds > 0
                                              ? '$_codeCooldownSeconds s'
                                              : '发送验证码'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: passwordController,
                            style: const TextStyle(color: Color(0xffE0E0E0)),
                            decoration: inputDecoration.copyWith(
                              labelText: '密码',
                              prefixIcon: const Icon(Icons.lock),
                            ),
                            obscureText: true,
                            textInputAction:
                                isRegister ? TextInputAction.next : TextInputAction.done,
                            onSubmitted: isRegister ? null : (_) => _submit(),
                          ),
                          if (isRegister) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: confirmPasswordController,
                              style: const TextStyle(color: Color(0xffE0E0E0)),
                              decoration: inputDecoration.copyWith(
                                labelText: '确认密码',
                                prefixIcon: const Icon(Icons.lock_outline),
                              ),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              style: ButtonStyle(
                                backgroundColor:
                                    const WidgetStatePropertyAll(Color(0xffD7FF00)),
                                foregroundColor:
                                    const WidgetStatePropertyAll(Colors.black),
                                overlayColor: WidgetStatePropertyAll(
                                  Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              onPressed: isLoading ? null : _submit,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        key: ValueKey(isRegister),
                                        isRegister ? '注册' : '登录',
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            style: const ButtonStyle(
                              overlayColor:
                                  WidgetStatePropertyAll(Colors.transparent),
                            ),
                            onPressed: () {
                              setState(() {
                                isRegister = !isRegister;
                                error = null;
                              });
                            },
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: Text(
                                key: ValueKey(isRegister),
                                isRegister ? '登录' : '注册账号',
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
    );
  }
}
