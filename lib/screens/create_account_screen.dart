import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';

import '../app/app_scope.dart';
import '../config/oauth_config.dart';
import '../localization/signup_strings.dart';
import '../router/app_routes.dart';
import '../services/auth_service.dart';
import '../services/social_auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/smart_fit_theme.dart';

/// Create account (page 3): links from landing **Get Started** and login **Sign Up**.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final SocialAuthService _auth = SocialAuthService();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agreePrivacy = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
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

  bool _isAr(Locale l) => l.languageCode.toLowerCase() == 'ar';

  Future<void> _onCreate(Locale l) async {
    final email = _email.text.trim();
    final pass = _password.text;
    final pass2 = _confirm.text;

    if (email.isEmpty || pass.isEmpty || pass2.isEmpty) {
      _snack(_isAr(l) ? 'أكمل كل الحقول' : 'Fill in email and both passwords');
      return;
    }
    if (!_agreePrivacy) {
      _snack(SignupStrings.acceptPrivacy(l));
      return;
    }
    if (pass != pass2) {
      _snack(SignupStrings.passwordsMismatch(l));
      return;
    }
    await _runGuarded(() async {
      try {
        await AuthService.instance.register(email, pass);
      } catch (e) {
        _snack('$e');
        return;
      }
      if (!mounted) return;
      context.push(AppRoutes.profileSetup);
    });
  }

  Future<void> _onGoogle(Locale l) async {
    await _runGuarded(() async {
      try {
        final account = await _auth.signInWithGoogle();
        if (account == null) {
          _snack(_isAr(l) ? 'تم الإلغاء' : 'Canceled');
          return;
        }
        if (!mounted) return;
        context.push(AppRoutes.profileSetup);
      } on GoogleSignInException catch (e) {
        final hint = OAuthConfig.googleServerClientId.isEmpty
            ? ' Add GOOGLE_WEB_CLIENT_ID dart-define + Google OAuth (and iOS GIDClientID in Info.plist).'
            : '';
        _snack('${e.description ?? e.code.name}$hint');
      } catch (e) {
        _snack('$e');
      }
    });
  }

  Future<void> _onApple(Locale l) async {
    await _runGuarded(() async {
      try {
        await _auth.signInWithAppleNative();
        if (!mounted) return;
        context.push(AppRoutes.profileSetup);
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
    final year = DateTime.now().year;

    final linkStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isDark ? Colors.white : ext.mutedText,
          decoration: TextDecoration.underline,
          decorationColor: isDark ? Colors.white70 : ext.mutedText,
        );

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
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 22,
                            color: AppColors.teal,
                          ),
                        ),
                        const Spacer(),
                        _LangPill(
                          isEnglish: scope.isEnglish,
                          muted: ext.mutedText,
                          onToggle: scope.toggleLocaleEnAr,
                        ),
                        const SizedBox(width: 10),
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
                    const SizedBox(height: 28),
                    Text(
                      SignupStrings.title(l),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      SignupStrings.subtitle(l),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ext.mutedText,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      SignupStrings.email(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: _fieldDecoration(hintText: SignupStrings.emailHint(l)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      SignupStrings.password(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: _fieldDecoration(
                        hintText: '••••••••',
                        suffixPass: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: ext.mutedText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      SignupStrings.confirmPassword(l),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscureConfirm,
                      decoration: _fieldDecoration(
                        hintText: '••••••••',
                        suffixPass: IconButton(
                          tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: ext.mutedText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: ext.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Checkbox(
                                value: _agreePrivacy,
                                onChanged: _busy
                                    ? null
                                    : (v) =>
                                        setState(() => _agreePrivacy = v ?? false),
                                side: BorderSide(
                                  width: 1.75,
                                  color: AppColors.teal.withValues(alpha: 0.85),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                activeColor: AppColors.teal,
                                checkColor: Colors.white,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  SignupStrings.privacyAgreement(l),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        height: 1.4,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _busy ? null : () => _onCreate(l),
                        child: Text(
                          SignupStrings.createAccount(l),
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
                            SignupStrings.continueWith(l),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: ext.mutedText,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.35,
                                ),
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
                            background: fieldFill,
                            label: SignupStrings.google(l),
                            leading: const FaIcon(
                              FontAwesomeIcons.google,
                              color: Color(0xFF4285F4),
                              size: 20,
                            ),
                            labelColor: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SocialButton(
                            onPressed: () => _onApple(l),
                            borderColor: borderColor,
                            background: fieldFill,
                            label: SignupStrings.apple(l),
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
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => _snack(SignupStrings.linkComingSoon(l)),
                          style: TextButton.styleFrom(
                            foregroundColor: linkStyle?.color,
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            SignupStrings.privacyPolicy(l),
                            style: linkStyle?.copyWith(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text('|', style: TextStyle(color: ext.mutedText)),
                        TextButton(
                          onPressed: () => _snack(SignupStrings.linkComingSoon(l)),
                          style: TextButton.styleFrom(
                            foregroundColor: linkStyle?.color,
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            SignupStrings.terms(l),
                            style: linkStyle?.copyWith(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text('|', style: TextStyle(color: ext.mutedText)),
                        TextButton(
                          onPressed: () => _snack(SignupStrings.linkComingSoon(l)),
                          style: TextButton.styleFrom(
                            foregroundColor: linkStyle?.color,
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            SignupStrings.helpCenter(l),
                            style: linkStyle?.copyWith(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        SignupStrings.copyright(l, year),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ext.mutedText,
                            ),
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

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixPass,
  }) {
    final ctx = context;
    final ext = ctx.smartFitExt;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final fill = ext.cardBackground;
    final borderColor = isDark ? const Color(0xFF394248) : const Color(0xFFE5E7EB);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: ext.mutedText.withValues(alpha: 0.72)),
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixPass,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill({
    required this.isEnglish,
    required this.muted,
    required this.onToggle,
  });

  final bool isEnglish;
  final Color muted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: muted.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                children: [
                  TextSpan(
                    text: 'EN',
                    style: TextStyle(
                      color: isEnglish ? AppColors.teal : muted,
                    ),
                  ),
                  TextSpan(text: ' | ', style: TextStyle(color: muted)),
                  TextSpan(
                    text: 'AR',
                    style: TextStyle(
                      color: !isEnglish ? AppColors.teal : muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? AppColors.teal : Colors.transparent,
            ),
            color: selected ? Colors.transparent : ext.inactiveTint.withValues(alpha: 0.85),
          ),
          child: Icon(icon, size: 20, color: selected ? AppColors.teal : idleIcon),
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
