import 'dart:ui';

/// Copy for the landing page only; extend with more keys as flows grow.
class LandingStrings {
  const LandingStrings._();

  static String title(Locale l) =>
      _isAr(l) ? 'سمارت فيت' : 'Smart Fit';

  static String tagline(Locale l) => _isAr(l)
      ? 'مدرب تحويل الجسم القائم على الذكاء الاصطناعي، مبني على بيانات InBody ومخصّص لك.'
      : 'Your AI-powered body transformation coach. Built on your InBody data. Personalized for you.';

  static String feature1(Locale l) => _isAr(l)
      ? 'مدرب على بيانات فحوصات InBody الحقيقية'
      : 'Trained on real InBody scan data';

  static String feature2(Locale l) => _isAr(l)
      ? 'خطط وجبات وتمارين يولدها الذكاء الاصطناعي'
      : 'AI-generated meal & workout plans';

  static String feature3(Locale l) => _isAr(l)
      ? 'بيانات صحية مشفّرة من الطرف إلى الطرف'
      : 'End-to-end encrypted health data';

  static String getStarted(Locale l) => _isAr(l) ? 'ابدأ الآن' : 'Get Started';

  static String logIn(Locale l) => _isAr(l) ? 'تسجيل الدخول' : 'Log In';

  static bool _isAr(Locale l) => l.languageCode.toLowerCase() == 'ar';
}
