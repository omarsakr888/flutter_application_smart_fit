import json
import os

with open('extracted_strings.json', 'r', encoding='utf-8-sig') as f:
    strings = json.load(f)

# Hardcoded arabic translations for the most common ones
translations = {
    'Smart Fit': 'سمارت فيت',
    'Get Started': 'ابدأ الآن',
    'Log In': 'تسجيل الدخول',
    'Settings': 'الإعدادات',
    'Log out': 'تسجيل خروج',
    'Log out?': 'هل تريد تسجيل الخروج؟',
    'Cancel': 'إلغاء',
    'You will be returned to the login screen.': 'سيتم إعادتك إلى شاشة تسجيل الدخول.',
    'Meal Plan': 'خطة الوجبات',
    'Achievements': 'الإنجازات',
    'Start InBody Scan': 'ابدأ فحص InBody',
    'Nutrition': 'التغذية',
    'Progress & Analytics': 'التقدم والتحليلات',
    'AI Coach': 'المدرب الذكي',
    'Upload your InBody\\nscan': 'ارفع فحص\\nInBody الخاص بك',
    'Supports InBody 120, 270, and 570': 'يدعم أجهزة InBody 120, 270 و 570',
    'Analyzing your InBody scan…': 'جاري تحليل الفحص...',
    'This may take 30–60 seconds on CPU': 'قد يستغرق هذا 30-60 ثانية',
    'Or upload from gallery': 'أو ارفع من المعرض',
    'Take a photo': 'التقط صورة',
    'Extract InBody Scan': 'استخراج بيانات الفحص',
    'Scan uploaded successfully\\n': 'تم رفع الفحص بنجاح\\n',
    'Verify & Correct Values': 'تحقق وصحح القيم',
    'Generating your plans': 'جاري إنشاء خططك',
    'Your AI plan is being generated...': 'جاري إنشاء خطتك بالذكاء الاصطناعي...',
    'Analyzing your body data': 'جاري تحليل بيانات جسمك',
    'Go to Dashboard': 'الذهاب إلى لوحة التحكم',
    'Your personalised plans': 'خططك المخصصة',
    'Generated from your InBody scan and AI engines.': 'تم الإنشاء بناءً على فحص InBody ومحركات الذكاء الاصطناعي.',
    'Total Calories': 'إجمالي السعرات',
    'PROTEIN': 'بروتين',
    'CARBS': 'كربوهيدرات',
    'FAT': 'دهون',
    'PER SERVING': 'لكل حصة',
    'Ingredients': 'المكونات',
    'Training Advice': 'نصائح التدريب',
    'Finish Setup': 'إنهاء الإعداد',
    'Your preferences': 'تفضيلاتك',
    'Select Theme': 'اختر المظهر',
    'Light Mode': 'الوضع الفاتح',
    'Dark Mode': 'الوضع الداكن',
    'System Default': 'الوضع الافتراضي',
    'Back': 'رجوع',
    'Confirm Extraction for Generating Plans': 'تأكيد الاستخراج لإنشاء الخطط',
    'Tips for success': 'نصائح للنجاح',
    'Ensure lighting is even and text is sharp for the AI to analyze your metrics accurately.': 'تأكد من أن الإضاءة متساوية والنص واضح ليقوم الذكاء الاصطناعي بتحليل بياناتك بدقة.',
    'Align the scan within the\\ngrid': 'قم بمحاذاة الفحص داخل\\nالشبكة',
    'No scan data yet': 'لا توجد بيانات فحص بعد',
    'No achievements yet': 'لا توجد إنجازات بعد',
    'Track your fitness journey and upcoming\\nmilestones.': 'تتبع رحلة لياقتك والمعالم القادمة.',
    'Complete workouts, log meals, and\\nstay consistent to earn badges.': 'أكمل التمارين وسجل الوجبات وكن ملتزماً لكسب الشارات.',
    'Before / After': 'قبل / بعد',
    'VS PREVIOUS SCAN': 'مقابل الفحص السابق',
}

with open(r'lib/localization/app_strings.dart', 'w', encoding='utf-8') as f:
    f.write('''import 'package:flutter/material.dart';
import '../app/app_scope.dart';

extension StringLocalization on String {
  String tr(BuildContext context) {
    final scope = AppScope.of(context);
    if (scope.locale.languageCode != 'ar') return this;
    return AppStrings.ar[this] ?? this;
  }
}

class AppStrings {
  static const Map<String, String> ar = {
''')
    for s in strings:
        # Get translation if exists, otherwise keep original
        trans = translations.get(s, s)
        # Escape single quotes and newlines
        escaped_key = s.replace('\\\\', '\\\\\\\\').replace("'", "\\'").replace('\\n', '\\\\n').replace('$', '\\\\$')
        escaped_val = trans.replace('\\\\', '\\\\\\\\').replace("'", "\\'").replace('\\n', '\\\\n').replace('$', '\\\\$')
        f.write(f"    '{escaped_key}': '{escaped_val}',\n")
    
    f.write('''  };
}
''')
