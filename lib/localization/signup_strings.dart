import 'dart:ui';

class SignupStrings {
  const SignupStrings._();

  static String title(Locale l) =>
      _isAr(l) ? 'إنشاء حساب' : 'Create account';

  static String subtitle(Locale l) => _isAr(l)
      ? 'ابدأ رحلة التحويل إلى الأفضل'
      : 'Start your transformation journey';

  static String email(Locale l) => _isAr(l) ? 'البريد الإلكتروني' : 'Email';

  static String emailHint(Locale l) => 'name@example.com';

  static String password(Locale l) =>
      _isAr(l) ? 'كلمة المرور' : 'Password';

  static String confirmPassword(Locale l) =>
      _isAr(l) ? 'تأكيد كلمة المرور' : 'Confirm Password';

  static String privacyAgreement(Locale l) => _isAr(l)
      ? '🔒 أوافق على معالجة بيانات بطريقة خصوصية أولاً ومشفّرة من طرف إلى طرف. لا نبيع بياناتك الصحية أبدًا.'
      : '🔒 I agree to privacy-first, end-to-end encrypted data handling. Your health data is never sold.';

  static String createAccount(Locale l) =>
      _isAr(l) ? 'إنشاء حساب' : 'Create Account';

  static String continueWith(Locale l) =>
      _isAr(l) ? 'أو تابع بواسطة' : 'OR CONTINUE WITH';

  static String google(Locale l) => 'Google';

  static String apple(Locale l) => 'Apple';

  static String privacyPolicy(Locale l) =>
      _isAr(l) ? 'سياسة الخصوصية' : 'Privacy Policy';

  static String terms(Locale l) =>
      _isAr(l) ? 'شروط الاستخدام' : 'Terms of Service';

  static String helpCenter(Locale l) =>
      _isAr(l) ? 'مركز المساعدة' : 'Help Center';

  static String copyright(Locale l, int year) => _isAr(l)
      ? '© $year سمارت فيت. جميع الحقوق محفوظة.'
      : '© $year Smart Fit. All rights reserved.';

  static String acceptPrivacy(Locale l) => _isAr(l)
      ? 'ارجع الموافقة على الخصوصية أولًا'
      : 'Please accept privacy terms';

  static String passwordsMismatch(Locale l) => _isAr(l)
      ? 'كلمتا المرور غير متطابقتين'
      : 'Passwords do not match';

  static String linkComingSoon(Locale l) =>
      _isAr(l) ? 'سيُفعّل قريبًا' : 'Link coming soon';

  static bool _isAr(Locale l) => l.languageCode.toLowerCase() == 'ar';
}
