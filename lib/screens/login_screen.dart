import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../config/oauth_config.dart';
import '../localization/login_strings.dart';
import '../router/app_routes.dart';
import '../services/social_auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/smart_fit_theme.dart';

/// Login (page 2). Theme mirrors [LandingScreen]; routes from landing "Log In".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _heroImageUrl =
      'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=1200&q=80';

  final _email = TextEditingController();
  final _password = TextEditingController();
  final SocialAuthService _auth = SocialAuthService();

  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _runGuarded(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(Object message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('$message')),
    );
  }

  Future<void> _onEmailLogin(Locale l) async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (email.isEmpty || pass.isEmpty) {
      _snack(_isAr(l) ? 'أدخل البريد وكلمة المرور' : 'Enter email and password');
      return;
    }
    _snack(
      _isAr(l)
          ? 'تم قبول الطلب محليًا فقط — اربط دخلك بخلفية لاحقًا.'
          : 'Submitted locally — connect this to your backend next.',
    );
  }

  bool _isAr(Locale l) => l.languageCode.toLowerCase() == 'ar';

  Future<void> _onGoogle(Locale l) async {
    await _runGuarded(() async {
      try {
        final account = await _auth.signInWithGoogle();
        if (account == null) {
          _snack(_isAr(l) ? 'تم الإلغاء' : 'Canceled');
          return;
        }
        final email = account.email.trim();
        final label = email.isNotEmpty ? email : account.id;
        _snack(_isAr(l) ? 'Google: $label' : 'Signed in as $label');
      } on GoogleSignInException catch (e) {
        final hint = OAuthConfig.googleServerClientId.isEmpty
            ? ' Add GOOGLE_WEB_CLIENT_ID dart-define + Google OAuth (and iOS GIDClientID in Info.plist).'
            : '';
        _snack(
          '${e.description ?? e.code.name}$hint',
        );
      } catch (e) {
        _snack('$e');
      }
    });
  }

  Future<void> _onApple(Locale l) async {
    await _runGuarded(() async {
      try {
        final cred = await _auth.signInWithAppleNative();
        final mail = cred.email?.trim() ?? '';
        final fallback =
            cred.userIdentifier ?? (_isAr(l) ? 'مستخدم Apple' : 'Apple user');
        final label = mail.isNotEmpty ? mail : fallback;
        _snack(_isAr(l) ? 'Apple: $label' : 'Apple: $label');
      } on StateError catch (e) {
        _snack(e.message);
      } on UnsupportedError catch (e) {
        _snack('$e');
      } catch (e) {
        _snack('$e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final l = scope.locale;
    final ext = context.smartFitExt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = Theme.of(context).dividerColor;

    final fieldFill = ext.cardBackground;
    final borderColor = isDark ? const Color(0xFF394248) : const Color(0xFFE5E7EB);

    return Scaffold(
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.landing);
                            }
                          },
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 22,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        _ThemeOutlineOrb(
                          selected: !isDark,
                          onTap: () => scope.setThemeBrightness(Brightness.light),
                          icon: Icons.wb_sunny_rounded,
                        ),
                        const SizedBox(width: 10),
                        _ThemeOutlineOrb(
                          selected: isDark,
                          onTap: () => scope.setThemeBrightness(Brightness.dark),
                          icon: Icons.dark_mode_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      LoginStrings.welcomeBack(l),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LoginStrings.subtitle(l),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ext.mutedText,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          _heroImageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return ColoredBox(
                              color: ext.inactiveTint,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.teal.withValues(alpha: 0.6),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: ext.inactiveTint,
                            child: Icon(
                              Icons.fitness_center_rounded,
                              size: 48,
                              color: AppColors.teal.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      LoginStrings.emailLabel(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        hintText: LoginStrings.emailHint(l),
                        hintStyle: TextStyle(color: ext.mutedText.withValues(alpha: 0.75)),
                        filled: true,
                        fillColor: fieldFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LoginStrings.passwordLabel(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: TextStyle(color: ext.mutedText.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: fieldFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: ext.mutedText,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => _snack(
                          _isAr(l)
                              ? 'إعادة التعيين قريبًا'
                              : 'Password recovery — connect your reset flow.',
                        ),
                        child: Text(
                          LoginStrings.forgotPassword(l),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: _busy ? null : () => _onEmailLogin(l),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(LoginStrings.logIn(l)),
                            const SizedBox(width: 12),
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(child: Divider(height: 1, color: divider)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            LoginStrings.continueWith(l),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ext.mutedText),
                          ),
                        ),
                        Expanded(child: Divider(height: 1, color: divider)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            onPressed: () => _onGoogle(l),
                            borderColor: borderColor,
                            background: isDark ? ext.cardBackground : Colors.white,
                            label: LoginStrings.google(l),
                            leading: FaIcon(FontAwesomeIcons.google, color: Color(0xFF4285F4), size: 20),
                            labelColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SocialButton(
                            onPressed: () => _onApple(l),
                            borderColor: borderColor,
                            background: isDark ? ext.cardBackground : Colors.white,
                            label: LoginStrings.apple(l),
                            leading: FaIcon(
                              FontAwesomeIcons.apple,
                              color: isDark ? Colors.white : Colors.black,
                              size: 22,
                            ),
                            labelColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: ext.mutedText,
                              ),
                          children: [
                            TextSpan(text: LoginStrings.footerPrompt(l)),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => context.push(AppRoutes.getStarted),
                                child: Text(
                                  LoginStrings.signUp(l),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOutlineOrb extends StatelessWidget {
  const _ThemeOutlineOrb({
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ext = context.smartFitExt;
    final idleIcon = Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : Colors.black54;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? AppColors.teal : Colors.transparent,
            ),
            color: selected ? Colors.transparent : ext.inactiveTint.withValues(alpha: 0.8),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? AppColors.teal : idleIcon,
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onPressed,
    required this.borderColor,
    required this.background,
    required this.label,
    required this.leading,
    required this.labelColor,
  });

  final VoidCallback onPressed;
  final Color borderColor;
  final Color background;
  final String label;
  final Widget leading;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        foregroundColor: labelColor,
        backgroundColor: background,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
