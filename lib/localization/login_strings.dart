import 'dart:ui';

class LoginStrings {
  const LoginStrings._();

  static String welcomeBack(Locale l) =>
      _isAr(l) ? 'مرحبًا بعودتك' : 'Welcome back';

  static String subtitle(Locale l) => _isAr(l)
      ? 'سجّل الدخول إلى حساب سمارت فيت'
      : 'Log in to your Smart Fit account';

  static String emailLabel(Locale l) =>
      _isAr(l) ? 'البريد الإلكتروني' : 'Email Address';

  static String emailHint(Locale l) =>
      _isAr(l) ? 'your@example.com' : 'you@example.com';

  static String passwordLabel(Locale l) => _isAr(l) ? 'كلمة المرور' : 'Password';

  static String forgotPassword(Locale l) =>
      _isAr(l) ? 'هل نسيت كلمة المرور؟' : 'Forgot password?';

  static String logIn(Locale l) => _isAr(l) ? 'تسجيل الدخول' : 'Log In';

  static String continueWith(Locale l) =>
      _isAr(l) ? 'أو تابع بواسطة' : 'or continue with';

  static String google(Locale l) => 'Google';

  static String apple(Locale l) => 'Apple';

  static String footerPrompt(Locale l) =>
      _isAr(l) ? 'ليس لديك حساب؟ ' : "Don't have an account? ";

  static String signUp(Locale l) => _isAr(l) ? 'إنشاء حساب' : 'Sign Up';

  static bool _isAr(Locale l) => l.languageCode.toLowerCase() == 'ar';
}
