import 'dart:ui';

class ProfileSetupStrings {
  const ProfileSetupStrings._();

  static String title(Locale l) =>
      _isAr(l) ? 'إعداد الملف' : 'Profile Setup';

  static String step1of2(Locale l) =>
      _isAr(l) ? 'الخطوة 1 من 2' : 'STEP 1 OF 2';

  static String headline(Locale l) => _isAr(l)
      ? 'أخبرنا عن نفسك'
      : 'Tell us about yourself';

  static String subtitle(Locale l) => _isAr(l)
      ? 'سنستخدم ذلك لتخصيص خطتك بالذكاء الاصطناعي وتحسين رحلة لياقتك.'
      : "We'll use this to personalize your AI plan and optimize your fitness journey.";

  static String gender(Locale l) => _isAr(l) ? 'الجنس' : 'Gender';

  static String male(Locale l) => _isAr(l) ? 'ذكر' : 'Male';

  static String female(Locale l) => _isAr(l) ? 'أنثى' : 'Female';

  static String other(Locale l) => _isAr(l) ? 'آخر' : 'Other';

  static String age(Locale l) => _isAr(l) ? 'العمر' : 'Age';

  static String heightCm(Locale l) => _isAr(l) ? 'الطول (سم)' : 'Height (cm)';

  static String weightKg(Locale l) => _isAr(l) ? 'الوزن (كلغ)' : 'Weight (kg)';

  static String targetWeightKg(Locale l) =>
      _isAr(l) ? 'الوزن المستهدف (كلغ)' : 'Target Weight (kg)';

  static String primaryGoal(Locale l) =>
      _isAr(l) ? 'الهدف الأساسي' : 'Primary Goal';

  static String goalLoseTitle(Locale l) =>
      _isAr(l) ? '🔥 فقدان الدهون' : '🔥 Lose fat';

  static String goalLoseSubtitle(Locale l) => _isAr(l)
      ? 'حرق الدهون وتمارين الكارديو'
      : 'Fat-burning focus & cardio';

  static String goalMuscleTitle(Locale l) =>
      _isAr(l) ? '💪 بناء العضلات' : '💪 Build muscle';

  static String goalMuscleSubtitle(Locale l) => _isAr(l)
      ? 'زيادة القوة والحجم العضلي'
      : 'Increase strength & volume';

  static String goalMaintainTitle(Locale l) =>
      _isAr(l) ? '⚖️ المحافظة' : '⚖️ Maintain';

  static String goalMaintainSubtitle(Locale l) => _isAr(l)
      ? 'الحفاظ على الشكل والصحة الحالية'
      : 'Keep current form & health';

  static String continue_(Locale l) => _isAr(l) ? 'متابعة' : 'Continue';

  static String badAge(Locale l) => _isAr(l)
      ? 'أدخل عمرًا بين 13 و 120'
      : 'Enter age between 13 and 120';

  static String badHeight(Locale l) => _isAr(l)
      ? 'الرجاء إدخال طول منطقي (سم)'
      : 'Enter a realistic height (cm)';

  static String badWeight(Locale l) => _isAr(l)
      ? 'الرجاء إدخال وزن منطقي (كغ)'
      : 'Enter a realistic weight (kg)';

  static String badgeKgFromCurrent(Locale l, int delta) {
    final abs = delta.abs();
    final sign = delta > 0 ? '+' : '-';
    return _isAr(l)
        ? '$sign$abs كلغ عن الحالي'
        : '$sign$abs kg from current';
  }

  static bool _isAr(Locale l) => l.languageCode.toLowerCase() == 'ar';
}
