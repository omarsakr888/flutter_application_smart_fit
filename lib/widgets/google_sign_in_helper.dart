import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/oauth_config.dart';
import '../services/auth_service.dart';
import '../services/social_auth_service.dart';
import '../theme/app_colors.dart';

/// Attempts real Google OAuth if GOOGLE_WEB_CLIENT_ID is configured.
/// Falls back to an email-input dialog for local / demo usage.
///
/// Returns true if the user is now signed in (JWT stored), false if cancelled.
Future<bool> googleSignInWithFallback(
  BuildContext context, {
  bool isAr = false,
}) async {
  if (OAuthConfig.googleServerClientId.isEmpty) {
    // Demo mode: no OAuth client configured — ask for email directly.
    return _showDemoDialog(context, isAr: isAr);
  }

  // Real OAuth flow.
  try {
    final account = await SocialAuthService().signInWithGoogle();
    if (account == null) return false;
    await AuthService.instance.socialLogin(
      account.email,
      account.displayName ?? '',
      'google',
    );
    return true;
  } on GoogleSignInException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.description ?? e.code.name)),
    );
    return false;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
    return false;
  }
}

Future<bool> _showDemoDialog(BuildContext context, {required bool isAr}) async {
  final emailCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  // Captured inside callbacks so we never read the controllers after pop,
  // which would race with the dialog's exit animation still referencing them.
  String capturedEmail = '';
  String capturedName = '';

  void capture() {
    capturedEmail = emailCtrl.text.trim();
    capturedName = nameCtrl.text.trim();
  }

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, color: Color(0xFF4285F4)),
          const SizedBox(width: 10),
          Text(
            isAr ? 'تسجيل الدخول بـ Google' : 'Sign in with Google',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr
                ? 'أدخل بريدك الإلكتروني (Gmail) للمتابعة.'
                : 'Enter your Gmail address to continue.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: isAr ? 'الاسم (اختياري)' : 'Name (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            decoration: InputDecoration(
              labelText: isAr ? 'بريد Gmail' : 'Gmail address',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            onSubmitted: (_) {
              capture();
              Navigator.of(ctx).pop(true);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            isAr ? 'إلغاء' : 'Cancel',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            capture();
            Navigator.of(ctx).pop(true);
          },
          child: Text(isAr ? 'متابعة' : 'Continue'),
        ),
      ],
    ),
  );

  // Delay disposal past the Material dialog exit animation (~300ms) so
  // Flutter's widget tree no longer references these controllers.
  Future.delayed(const Duration(milliseconds: 400), () {
    emailCtrl.dispose();
    nameCtrl.dispose();
  });

  if (confirmed != true) return false;

  if (capturedEmail.isEmpty || !capturedEmail.contains('@')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'أدخل بريدًا إلكترونيًا صالحًا' : 'Enter a valid email address'),
        ),
      );
    }
    return false;
  }

  try {
    await AuthService.instance.socialLogin(
      capturedEmail,
      capturedName,
      'google',
    );
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    return false;
  }
}
